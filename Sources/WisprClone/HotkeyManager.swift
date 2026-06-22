import AppKit

/// Push-to-talk hotkey: hold the Right Option (⌥) key to dictate, release to stop.
/// Uses a global flagsChanged monitor so it works while any app is focused.
final class HotkeyManager {
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var active = false

    // Virtual keycode for Right Option.
    private let rightOptionKeyCode: UInt16 = 61

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == rightOptionKeyCode else { return }
        let optionDown = event.modifierFlags.contains(.option)
        if optionDown, !active {
            active = true
            onStart?()
        } else if !optionDown, active {
            active = false
            onStop?()
        }
    }
}
