import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let speech = SpeechService()
    private let whisper = WhisperService()
    private let hotkeys = HotkeyManager()
    let meeting = MeetingTranscriber()
    var recordingPublic: Bool { recording }
    private var recording = false
    private var partialItem: NSMenuItem!
    private var meetingItem: NSMenuItem!

    // Main window UI
    var mainWindow: NSWindow?
    var winStatusLabel: NSTextField?
    var winMeetingButton: NSButton?
    var winCleanupCheck: NSButton?
    var winAutoPasteCheck: NSButton?

    private var integrity: IntegrityGuard.Status = .unknown("not checked")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Self-protection FIRST: if the app was tampered with (malware injected
        // after signing), warn the user and refuse to run.
        integrity = IntegrityGuard.check()
        if !integrity.isSafe {
            showAlert(
                title: "⚠️ Security warning — app may be modified",
                text: "Wispr Clone failed its integrity check — its files appear to have been changed since it was built, which can be a sign of malware. For your safety it will not start.\n\nRe-download a fresh copy from the official source."
            )
            NSApp.terminate(nil)
            return
        }

        setupStatusItem()
        wireServices()

        speech.requestAuthorization { [weak self] granted in
            if !granted {
                self?.showAlert(
                    title: "Permissions needed",
                    text: "Wispr Clone needs Microphone and Speech Recognition access. Enable them in System Settings ▸ Privacy & Security, then relaunch."
                )
            }
        }

        ensureAccessibility()
        hotkeys.start()
        updateIcon()
        setupMainMenu()
        setupMainWindow()
    }

    /// Without a main menu, an AppKit app has no Edit menu, so Cmd+C/V/X/A don't
    /// work in text fields. This wires up the standard editing shortcuts.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Wispr Clone",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar after the window is closed.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let menu = NSMenu()

        let title = NSMenuItem(title: "Wispr Clone", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let hint = NSMenuItem(title: "Hold Right ⌥ (Option) to dictate", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        let integrityItem = NSMenuItem(title: integrity.menuLabel, action: nil, keyEquivalent: "")
        integrityItem.isEnabled = false
        menu.addItem(integrityItem)

        partialItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
        partialItem.isEnabled = false
        menu.addItem(partialItem)

        menu.addItem(.separator())

        let cleanup = NSMenuItem(title: "AI Cleanup (Groq)", action: #selector(toggleCleanup), keyEquivalent: "")
        cleanup.target = self
        cleanup.state = Settings.cleanupEnabled ? .on : .off
        menu.addItem(cleanup)

        let autoPaste = NSMenuItem(title: "Auto-paste into focused app", action: #selector(toggleAutoPaste), keyEquivalent: "")
        autoPaste.target = self
        autoPaste.state = Settings.autoPaste ? .on : .off
        menu.addItem(autoPaste)

        menu.addItem(.separator())

        meetingItem = NSMenuItem(title: "Start Meeting Transcription", action: #selector(toggleMeeting), keyEquivalent: "")
        meetingItem.target = self
        menu.addItem(meetingItem)

        let openTranscripts = NSMenuItem(title: "Open Transcripts Folder", action: #selector(openTranscripts), keyEquivalent: "")
        openTranscripts.target = self
        menu.addItem(openTranscripts)

        let setKey = NSMenuItem(title: "Set Groq API Key…", action: #selector(setGroqKey), keyEquivalent: "")
        setKey.target = self
        menu.addItem(setKey)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func wireServices() {
        hotkeys.onStart = { [weak self] in self?.startRecording() }
        hotkeys.onStop = { [weak self] in self?.stopRecording() }

        speech.onPartial = { [weak self] text in
            self?.partialItem.title = text.isEmpty ? "Listening…" : "“\(text)”"
        }
        speech.onError = { [weak self] msg in
            self?.partialItem.title = "Error: \(msg)"
        }
        speech.onFinal = { [weak self] text in
            self?.handleFinal(text)
        }

        meeting.onLine = { [weak self] line in
            self?.partialItem.title = "📝 \(line)"
        }
        meeting.onError = { [weak self] msg in
            self?.partialItem.title = "Meeting error: \(msg)"
        }

        whisper.onPartial = { [weak self] text in
            self?.partialItem.title = text
        }
        whisper.onError = { [weak self] msg in
            self?.partialItem.title = "Error: \(msg)"
        }
        whisper.onFinal = { [weak self] text in
            self?.handleFinal(text)
        }
    }

    // MARK: - Recording flow

    private func startRecording() {
        guard !recording else { return }
        guard !meeting.isRunning else { return }  // mic is busy with the meeting transcript
        recording = true
        partialItem.title = "Listening…"
        updateIcon()
        if Settings.isHinglish { whisper.start() } else { speech.start() }
    }

    private func stopRecording() {
        guard recording else { return }
        recording = false
        updateIcon()
        if Settings.isHinglish { whisper.stop() } else { speech.stop() }
    }

    private func handleFinal(_ text: String) {
        guard !text.isEmpty else {
            partialItem.title = "Idle"
            return
        }
        partialItem.title = "Processing…"
        Cleanup.process(text, hinglish: Settings.isHinglish) { [weak self] cleaned in
            DispatchQueue.main.async {
                TextInserter.insert(cleaned, autoPaste: Settings.autoPaste)
                self?.partialItem.title = "Idle"
            }
        }
    }

    // MARK: - Menu actions

    @objc private func toggleCleanup(_ sender: NSMenuItem) {
        if !Settings.cleanupEnabled && Settings.groqKey == nil {
            showAlert(title: "Groq key required",
                      text: "Set your free Groq API key first (Set Groq API Key… button).")
            return
        }
        Settings.cleanupEnabled.toggle()
        sender.state = Settings.cleanupEnabled ? .on : .off
    }

    @objc private func toggleAutoPaste(_ sender: NSMenuItem) {
        Settings.autoPaste.toggle()
        sender.state = Settings.autoPaste ? .on : .off
    }

    @objc func toggleMeeting() {
        if meeting.isRunning {
            meeting.stop()
            meetingItem.title = "Start Meeting Transcription"
            partialItem.title = "Saved: \(meeting.currentFile?.lastPathComponent ?? "transcript")"
        } else {
            meeting.start()
            meetingItem.title = "Stop Meeting Transcription"
            partialItem.title = "📝 Meeting: transcribing…"
        }
        updateIcon()
        refreshWindowUI()
    }

    @objc func openTranscripts() {
        NSWorkspace.shared.open(MeetingTranscriber.transcriptsFolder)
    }

    @objc func setGroqKey() {
        let alert = NSAlert()
        alert.messageText = "Groq API Key"
        alert.informativeText = "One free key powers Hinglish (Whisper) and AI cleanup. Get it at console.groq.com/keys — it starts with \"gsk_\". Stored locally."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = Settings.groqKey ?? ""
        alert.accessoryView = field
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field  // so Cmd+V pastes right away

        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            Settings.groqKey = value.isEmpty ? nil : value
        }
    }

    // MARK: - Helpers

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let active = recording || meeting.isRunning
        let symbol = active ? "mic.fill" : "mic"
        let desc = meeting.isRunning ? "Meeting transcribing" : (recording ? "Recording" : "Wispr Clone")
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: desc)
        button.image?.isTemplate = true
        button.contentTintColor = active ? .systemRed : nil
        refreshWindowUI()
    }

    private func ensureAccessibility() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            showAlert(
                title: "Enable Accessibility",
                text: "Wispr Clone needs Accessibility access to detect the dictation hotkey and paste text. Grant it in System Settings ▸ Privacy & Security ▸ Accessibility, then relaunch."
            )
        }
    }

    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
