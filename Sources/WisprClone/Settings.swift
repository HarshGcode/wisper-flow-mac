import Foundation

/// Lightweight persisted settings backed by UserDefaults.
enum Settings {
    private static let d = UserDefaults.standard

    private enum Keys {
        static let cleanupEnabled = "cleanupEnabled"
        static let apiKey = "anthropicApiKey"
        static let autoPaste = "autoPaste"
        static let language = "speechLanguage"
        static let onDeviceOnly = "onDeviceOnly"
    }

    /// When true, force private on-device recognition (less accurate, esp. for
    /// fast speech). Default false → use Apple's more accurate online engine.
    static var onDeviceOnly: Bool {
        get { d.bool(forKey: Keys.onDeviceOnly) }  // default false
        set { d.set(newValue, forKey: Keys.onDeviceOnly) }
    }

    /// Speech-recognition language (BCP-47, e.g. "en-US", "hi-IN").
    static var language: String {
        get { d.string(forKey: Keys.language) ?? "en-US" }
        set { d.set(newValue, forKey: Keys.language) }
    }

    /// Languages offered in the UI: (display name, locale id).
    static let languageOptions: [(String, String)] = [
        ("English (US)", "en-US"),
        ("Hindi — हिन्दी", "hi-IN"),
        ("English (India)", "en-IN"),
        ("Spanish", "es-ES"),
        ("French", "fr-FR"),
        ("German", "de-DE"),
        ("Arabic", "ar-SA"),
        ("Mandarin", "zh-CN"),
    ]

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
