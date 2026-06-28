import Foundation

/// Post-processes a transcript with a Groq-hosted LLM (same Groq key as Whisper).
/// - Hinglish mode: ALWAYS romanize Hindi to Roman script + clean up.
/// - Other languages: only runs if the user enabled "AI Cleanup".
enum Cleanup {
    static func process(_ raw: String, hinglish: Bool, completion: @escaping (String) -> Void) {
        let shouldRun = hinglish || Settings.cleanupEnabled
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldRun, !trimmed.isEmpty, let key = Settings.groqKey,
              let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")
        else { completion(raw); return }

        let system: String
        if hinglish {
            system = """
            You convert voice-dictation transcripts of Hindi+English (Hinglish) speech \
            into clean ROMAN-script Hinglish — the way people actually type on a phone.
            - Write Hindi words in Roman/Latin letters, NOT Devanagari. \
              e.g. "क्या कर रहे हो" → "kya kar rahe ho".
            - Keep English words as normal English.
            - Remove fillers (um, uh, matlab), fix obvious recognition errors from context, \
              add light punctuation. Keep the user's natural wording.
            - Return ONLY the cleaned Roman Hinglish text, nothing else.
            """
        } else {
            system = """
            You are a dictation cleanup assistant. Remove filler words, fix grammar, \
            capitalization and punctuation, and tidy formatting — without changing meaning. \
            Do NOT add new information or commentary. Return ONLY the cleaned text.
            """
        }

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "temperature": 0.2,
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": trimmed],
            ],
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, error in
            guard
                error == nil, let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let text = message["content"] as? String,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                completion(raw)
                return
            }
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }
}
