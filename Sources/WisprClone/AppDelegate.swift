import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let speech = SpeechService()
    private let hotkeys = HotkeyManager()
    private var recording = false
    private var partialItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        partialItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
        partialItem.isEnabled = false
        menu.addItem(partialItem)

        menu.addItem(.separator())

        let cleanup = NSMenuItem(title: "AI Cleanup (Claude)", action: #selector(toggleCleanup), keyEquivalent: "")
        cleanup.target = self
        cleanup.state = Settings.cleanupEnabled ? .on : .off
        menu.addItem(cleanup)

        let autoPaste = NSMenuItem(title: "Auto-paste into focused app", action: #selector(toggleAutoPaste), keyEquivalent: "")
        autoPaste.target = self
        autoPaste.state = Settings.autoPaste ? .on : .off
        menu.addItem(autoPaste)

        let setKey = NSMenuItem(title: "Set Anthropic API Key…", action: #selector(setApiKey), keyEquivalent: "")
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
    }

    // MARK: - Recording flow

    private func startRecording() {
        guard !recording else { return }
        recording = true
        partialItem.title = "Listening…"
        updateIcon()
        speech.start()
    }

    private func stopRecording() {
        guard recording else { return }
        recording = false
        updateIcon()
        speech.stop()
    }

    private func handleFinal(_ text: String) {
        guard !text.isEmpty else {
            partialItem.title = "Idle"
            return
        }
        partialItem.title = "Processing…"
        Cleanup.clean(text) { [weak self] cleaned in
            DispatchQueue.main.async {
                TextInserter.insert(cleaned, autoPaste: Settings.autoPaste)
                self?.partialItem.title = "Idle"
            }
        }
    }

    // MARK: - Menu actions

    @objc private func toggleCleanup(_ sender: NSMenuItem) {
        if !Settings.cleanupEnabled && Settings.apiKey == nil {
            showAlert(title: "API key required",
                      text: "Set your Anthropic API key first (menu ▸ Set Anthropic API Key…).")
            return
        }
        Settings.cleanupEnabled.toggle()
        sender.state = Settings.cleanupEnabled ? .on : .off
    }

    @objc private func toggleAutoPaste(_ sender: NSMenuItem) {
        Settings.autoPaste.toggle()
        sender.state = Settings.autoPaste ? .on : .off
    }

    @objc private func setApiKey() {
        let alert = NSAlert()
        alert.messageText = "Anthropic API Key"
        alert.informativeText = "Used only for optional AI cleanup. Stored locally in your user defaults."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = Settings.apiKey ?? ""
        alert.accessoryView = field
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            Settings.apiKey = value.isEmpty ? nil : value
        }
    }

    // MARK: - Helpers

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbol = recording ? "mic.fill" : "mic"
        let desc = recording ? "Recording" : "Wispr Clone"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: desc)
        button.image?.isTemplate = true
        button.contentTintColor = recording ? .systemRed : nil
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
