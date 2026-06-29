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
            You clean up a raw Hinglish (Hindi+English) voice-dictation transcript into \
            natural, coherent ROMAN-script Hinglish, the way people type on a phone. Rules:
            1. Keep it Hinglish — do not translate to pure English or pure Hindi.
            2. Romanize any Devanagari to Roman/Latin script. Use natural casual Hinglish \
               spelling (main, hum, kya, kar, rahe, hai, nahin, etc.).
            3. Recognize English words that were transcribed phonetically (in Devanagari or \
               garbled Roman) and use their correct English spelling — never a literal \
               phonetic transliteration. E.g. saksses/सक्सेस → success, \
               phyuchar/फ्यूचर → future, कमफर्ट जोन → comfort zone.
            4. The transcript will contain speech-recognition mistakes: words or clauses \
               that are garbled, nonsensical, or do not fit the grammar/topic of the \
               sentence. REWRITE each such clause into the most natural, coherent phrase \
               that fits the sentence — using the surrounding context and overall topic as \
               your guide. Do not leave any nonsensical clause uncorrected. Leave clauses \
               that already make sense untouched.
            5. Remove filler words (um, uh) and duplicated/repeated phrases.
            6. Return ONLY the corrected text, nothing else — no notes, no explanation.
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
