import AppKit

/// Builds the app's main window — a visible UI listing every feature
/// (voice typing, meeting transcription, settings), so users don't have to
/// hunt through the menu-bar icon.
extension AppDelegate {

    func setupMainWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "Wispr Clone"
        win.isReleasedWhenClosed = false
        win.center()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Header: icon + title
        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 12
        header.alignment = .centerY
        let iconView = NSImageView()
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: path) {
            iconView.image = img
        }
        iconView.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 52).isActive = true
        let title = NSTextField(labelWithString: "Wispr Clone")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        header.addArrangedSubview(iconView)
        header.addArrangedSubview(title)
        stack.addArrangedSubview(header)

        // Live status
        let status = NSTextField(labelWithString: "● Idle")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .secondaryLabelColor
        winStatusLabel = status
        stack.addArrangedSubview(status)

        stack.addArrangedSubview(makeSeparator())

        // Voice typing
        stack.addArrangedSubview(makeSectionTitle("🎙️  Voice Typing"))
        stack.addArrangedSubview(makeHint("Hold the Right ⌥ Option key in any app, speak, then release — your words are typed where the cursor is."))

        stack.addArrangedSubview(makeSeparator())

        // Meeting transcription
        stack.addArrangedSubview(makeSectionTitle("📝  Meeting Transcription"))
        stack.addArrangedSubview(makeHint("Transcribe your voice during any meeting (Zoom, Meet, Teams) and save it to a timestamped file."))

        let meetBtn = NSButton(title: "Start Meeting Transcription", target: self, action: #selector(toggleMeeting))
        meetBtn.bezelStyle = .rounded
        meetBtn.controlSize = .large
        winMeetingButton = meetBtn
        stack.addArrangedSubview(meetBtn)

        let openBtn = NSButton(title: "Open Transcripts Folder", target: self, action: #selector(openTranscripts))
        openBtn.bezelStyle = .rounded
        stack.addArrangedSubview(openBtn)

        stack.addArrangedSubview(makeSeparator())

        // Settings
        stack.addArrangedSubview(makeSectionTitle("⚙️  Settings"))

        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langRow.spacing = 10
        let langLabel = NSTextField(labelWithString: "🌐 Speech language:")
        langLabel.font = .systemFont(ofSize: 12)
        let langPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for (name, _) in Settings.languageOptions { langPopup.addItem(withTitle: name) }
        if let idx = Settings.languageOptions.firstIndex(where: { $0.1 == Settings.language }) {
            langPopup.selectItem(at: idx)
        }
        langPopup.target = self
        langPopup.action = #selector(windowChangeLanguage(_:))
        langRow.addArrangedSubview(langLabel)
        langRow.addArrangedSubview(langPopup)
        stack.addArrangedSubview(langRow)

        let cleanup = NSButton(checkboxWithTitle: "AI Cleanup (Claude) — fix grammar & filler words",
                               target: self, action: #selector(windowToggleCleanup(_:)))
        cleanup.state = Settings.cleanupEnabled ? .on : .off
        winCleanupCheck = cleanup
        stack.addArrangedSubview(cleanup)

        let autoPaste = NSButton(checkboxWithTitle: "Auto-paste into the focused app",
                                 target: self, action: #selector(windowToggleAutoPaste(_:)))
        autoPaste.state = Settings.autoPaste ? .on : .off
        winAutoPasteCheck = autoPaste
        stack.addArrangedSubview(autoPaste)

        let onDevice = NSButton(checkboxWithTitle: "Private on-device only (less accurate for fast speech)",
                                target: self, action: #selector(windowToggleOnDevice(_:)))
        onDevice.state = Settings.onDeviceOnly ? .on : .off
        stack.addArrangedSubview(onDevice)

        let apiBtn = NSButton(title: "Set Anthropic API Key…", target: self, action: #selector(setApiKey))
        apiBtn.bezelStyle = .rounded
        stack.addArrangedSubview(apiBtn)

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])
        win.contentView = container

        mainWindow = win
        showMainWindow()
        refreshWindowUI()
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Keep the window's controls in sync with the current state.
    func refreshWindowUI() {
        if meeting.isRunning {
            winStatusLabel?.stringValue = "🔴 Meeting transcribing…"
            winMeetingButton?.title = "Stop Meeting Transcription"
        } else if recordingPublic {
            winStatusLabel?.stringValue = "🔴 Listening…"
        } else {
            winStatusLabel?.stringValue = "● Idle"
            winMeetingButton?.title = "Start Meeting Transcription"
        }
        winCleanupCheck?.state = Settings.cleanupEnabled ? .on : .off
        winAutoPasteCheck?.state = Settings.autoPaste ? .on : .off
    }

    // MARK: - Window control actions

    @objc func windowToggleCleanup(_ sender: NSButton) {
        if sender.state == .on && Settings.apiKey == nil {
            sender.state = .off
            showInfo(title: "API key required",
                     text: "Set your Anthropic API key first (Set Anthropic API Key… button).")
            return
        }
        Settings.cleanupEnabled = (sender.state == .on)
    }

    @objc func windowToggleAutoPaste(_ sender: NSButton) {
        Settings.autoPaste = (sender.state == .on)
    }

    @objc func windowChangeLanguage(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0 && idx < Settings.languageOptions.count else { return }
        Settings.language = Settings.languageOptions[idx].1
    }

    @objc func windowToggleOnDevice(_ sender: NSButton) {
        Settings.onDeviceOnly = (sender.state == .on)
    }

    // MARK: - Small builders

    private func makeSectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    private func makeHint(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 400
        return label
    }

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 400).isActive = true
        return box
    }

    func showInfo(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
