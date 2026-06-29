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
            You clean up a raw voice-dictation transcript (Devanagari mixed with Roman \
            English) into natural ROMAN-script Hinglish, the way people type on a phone. \
            Follow these rules EXACTLY:
            1. NEVER translate. Keep the SAME meaning/words the speaker used — do not \
               convert Hindi↔English.
            2. Romanize Devanagari to Roman/Latin script.
            3. CRITICAL: English words are often transcribed phonetically in Devanagari \
               (because the speaker said an English word). When a Devanagari word/phrase is \
               clearly the phonetic spelling of an English word, output its CORRECT ENGLISH \
               SPELLING — never a letter-by-letter phonetic transliteration. Examples:
               - "सक्सेस" → success   (NOT "saksses")
               - "फ्यूचर" → future    (NOT "phyuchar")
               - "नेशन" → nation, "कमफर्ट जोन" → comfort zone
            4. For genuine Hindi words, use natural casual Hinglish spelling (main, hum, kya, \
               kar, rahe, hai, nahin/nahi, etc.), not formal/academic transliteration.
            5. The raw transcript may contain speech-recognition mistakes: a garbled word \
               that doesn't make sense in context but phonetically resembles an intended \
               Hindi or English word. Use context to correct it to the most likely intended \
               word — but do not change words that already make sense.
            6. Remove obvious junk: repeated/duplicated phrases, and short fragments in an \
               unrelated language that are clearly mis-recognitions.
            7. Only fix spelling, grammar, spacing and punctuation. Do NOT add new content, \
               reword, or change the meaning beyond correcting clear errors.
            8. Return ONLY the cleaned text, nothing else.
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
