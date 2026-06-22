import Foundation

/// Lightweight persisted settings backed by UserDefaults.
enum Settings {
    private static let d = UserDefaults.standard

    private enum Keys {
        static let cleanupEnabled = "cleanupEnabled"
        static let apiKey = "anthropicApiKey"
        static let autoPaste = "autoPaste"
    }

    static var cleanupEnabled: Bool {
        get { d.bool(forKey: Keys.cleanupEnabled) }
        set { d.set(newValue, forKey: Keys.cleanupEnabled) }
    }

    /// Auto-paste into the focused app after transcription (vs. copy to clipboard only).
    static var autoPaste: Bool {
        get {
            if d.object(forKey: Keys.autoPaste) == nil { return true } // default on
            return d.bool(forKey: Keys.autoPaste)
        }
        set { d.set(newValue, forKey: Keys.autoPaste) }
    }

    /// Anthropic API key. Falls back to the ANTHROPIC_API_KEY environment variable.
    static var apiKey: String? {
        get {
            if let stored = d.string(forKey: Keys.apiKey), !stored.isEmpty { return stored }
            let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            return (env?.isEmpty == false) ? env : nil
        }
        set { d.set(newValue, forKey: Keys.apiKey) }
    }
}
