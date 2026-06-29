import Foundation

/// Deterministic script→Latin transliteration (no translation, no network).
/// Used for Hinglish when there's no Groq key to do a nicer LLM romanization.
enum Romanize {
    static func toLatin(_ s: String) -> String {
        let latin = s.applyingTransform(.toLatin, reverse: false) ?? s
        let plain = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        return plain.replacingOccurrences(of: "'", with: "")
    }
}
