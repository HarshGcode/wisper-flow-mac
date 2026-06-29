import Foundation

/// Post-processes a transcript with a Groq-hosted LLM (same Groq key as Whisper).
/// - Hinglish mode: ALWAYS romanize Hindi to Roman script + clean up.
/// - Other languages: only runs if the user enabled "AI Cleanup".
enum Cleanup {
    /// Logs only FAILURES (so a transient network blip that silently fell back
    /// to raw text is diagnosable afterwards).
    private static func logFailure(_ reason: String, raw: String) {
        let line = "[\(Date())] CLEANUP FAILED: \(reason) — input: \(raw.prefix(80))\n"
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "wispr_cleanup_errors.log")
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            try? line.data(using: .utf8)?.write(to: url)
        }
    }

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
            natural ROMAN-script Hinglish, the way people type on a phone. Follow this \
            PRIORITY ORDER strictly:

            RULE 1 (HIGHEST PRIORITY): Code-switching — mixing Hindi and English within a \
            sentence — is the NORMAL, correct way Hinglish speakers talk. It is NEVER an \
            error to fix. If a word/phrase is already a valid, sensible phrase in English OR \
            Hindi, leave it EXACTLY as spoken, even if the rest of the sentence is in the \
            other language.
               Example: "Hello guys, how are you?" must stay "Hello guys, how are you?" — \
               NOT "Hello guys, kaise ho?". Do not translate or restyle valid phrases.

            RULE 2: Romanize any Devanagari script to Roman/Latin letters, using natural \
            casual Hinglish spelling for Hindi words (main, hum, kya, kar, rahe, hai, \
            nahin, etc.).

            RULE 3: If a word was clearly an English word said aloud but got transcribed \
            phonetically (Devanagari or garbled Roman spelling), restore its correct English \
            spelling — this is a spelling fix, not translation. E.g. "सक्सेस"/"saksses" → \
            success, "फ्यूचर"/"phyuchar" → future.

            RULE 4: Distinguish real mis-hearings from valid code-switched phrases. A clause \
            is a MIS-HEARING (not valid Hinglish) only if, even though individual words \
            might be real, the clause as a whole does not logically/grammatically make sense \
            in context — e.g. "ek vaccine nahi subscribe dekhkar jaati" does not logically \
            follow from "failure teaches us something". For genuine mis-hearings like this, \
            rewrite the clause into the most plausible coherent phrase using context. A \
            short, complete, sensible phrase (like "how are you?") is NEVER a mis-hearing, \
            even if it switches language — never touch those.

            RULE 5: Remove filler words (um, uh) and duplicated/repeated phrases.

            Return ONLY the corrected text, nothing else.
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

        attempt(req, raw: raw, attemptsLeft: 2, completion: completion)
    }

    /// Retries once on transient failure (network blip, timeout) before giving
    /// up and returning the raw text — so a single hiccup doesn't silently
    /// skip cleanup.
    private static func attempt(
        _ req: URLRequest, raw: String, attemptsLeft: Int,
        completion: @escaping (String) -> Void
    ) {
        URLSession.shared.dataTask(with: req) { data, response, error in
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if let error {
                if attemptsLeft > 1 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
                        attempt(req, raw: raw, attemptsLeft: attemptsLeft - 1, completion: completion)
                    }
                } else {
                    logFailure("network error: \(error.localizedDescription)", raw: raw)
                    completion(raw)
                }
                return
            }

            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let text = message["content"] as? String,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                let bodyPreview = String(data: data ?? Data(), encoding: .utf8)?.prefix(200) ?? ""
                if attemptsLeft > 1 && (httpCode == 429 || httpCode >= 500) {
                    // Rate-limited or server hiccup — worth a retry.
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                        attempt(req, raw: raw, attemptsLeft: attemptsLeft - 1, completion: completion)
                    }
                } else {
                    logFailure("http \(httpCode), body: \(bodyPreview)", raw: raw)
                    completion(raw)
                }
                return
            }
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }
}
