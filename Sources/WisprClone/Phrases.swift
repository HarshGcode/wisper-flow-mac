import Foundation

/// Text macros. Users define "trigger = expansion" lines; when a trigger phrase
/// appears in the transcript it's replaced with the full expansion.
/// e.g.  my email = harsh@example.com
enum Phrases {
    static func parsed() -> [(String, String)] {
        Settings.phrasesRaw
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                let trigger = parts[0].trimmingCharacters(in: .whitespaces)
                let expansion = parts[1].trimmingCharacters(in: .whitespaces)
                return trigger.isEmpty ? nil : (trigger, expansion)
            }
    }

    /// Replace any trigger phrase in `text` with its expansion (case-insensitive).
    static func apply(_ text: String) -> String {
        var result = text
        for (trigger, expansion) in parsed() {
            result = result.replacingOccurrences(
                of: trigger, with: expansion, options: [.caseInsensitive]
            )
        }
        return result
    }
}
