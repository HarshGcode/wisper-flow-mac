import Foundation

/// Lightweight persisted settings backed by UserDefaults.
enum Settings {
    private static let d = UserDefaults.standard

    private enum Keys {
        static let cleanupEnabled = "cleanupEnabled"
        static let autoPaste = "autoPaste"
        static let language = "speechLanguage"
        static let onDeviceOnly = "onDeviceOnly"
        static let groqKey = "groqApiKey"
        static let phrases = "phrasesRaw"
    }

    /// Phrases (text macros), edited as "trigger = expansion" lines. Speaking a
    /// trigger expands to the full text — e.g. "my email = you@example.com".
    static var phrasesRaw: String {
        get { d.string(forKey: Keys.phrases) ?? "" }
        set { d.set(newValue, forKey: Keys.phrases) }
    }

    /// Single API key — Groq powers both Whisper (Hinglish transcription) and the
    /// LLM cleanup. Falls back to the GROQ_API_KEY env var.
    static var groqKey: String? {
        get {
            if let s = d.string(forKey: Keys.groqKey), !s.isEmpty { return s }
            let env = ProcessInfo.processInfo.environment["GROQ_API_KEY"]
            return (env?.isEmpty == false) ? env : nil
        }
        set { d.set(newValue, forKey: Keys.groqKey) }
    }

    /// Speech language. The special value "hinglish" uses Whisper + romanization
    /// to output Roman-script Hinglish (e.g. "kya kar rahe ho").
    static var language: String {
        get { d.string(forKey: Keys.language) ?? "en-US" }
        set { d.set(newValue, forKey: Keys.language) }
    }

    /// Hinglish mode → use Whisper (Groq) and romanize the result.
    static var isHinglish: Bool { language == "hinglish" }

    /// Languages offered in the UI: (display name, code).
    static let languageOptions: [(String, String)] = [
        ("Hinglish (Roman) — Hindi + English", "hinglish"),
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

    /// When true, force private on-device recognition (non-Hinglish languages only).
    static var onDeviceOnly: Bool {
        get { d.bool(forKey: Keys.onDeviceOnly) }
        set { d.set(newValue, forKey: Keys.onDeviceOnly) }
    }
}
