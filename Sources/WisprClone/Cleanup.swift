import Foundation

/// Optional AI cleanup of raw dictation using the Claude API.
/// Removes filler words, fixes grammar/punctuation, and tidies formatting —
/// without changing the meaning. Falls back to the raw text on any failure.
enum Cleanup {
    static func clean(_ raw: String, completion: @escaping (String) -> Void) {
        guard Settings.cleanupEnabled, let apiKey = Settings.apiKey else {
            completion(raw)
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { completion(raw); return }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(raw); return
        }

        let system = """
        You are a dictation cleanup assistant. The user dictated text by voice. \
        Clean it up: remove filler words (um, uh, like), fix grammar, capitalization, \
        and punctuation, and apply obvious formatting. Do NOT add new information, do \
        NOT answer questions in the text, do NOT add commentary or quotes. Return ONLY \
        the cleaned text.
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 2000,
            "system": system,
            "messages": [
                ["role": "user", "content": trimmed]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 15
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, error in
            guard
                error == nil,
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let content = json["content"] as? [[String: Any]],
                let text = content.first?["text"] as? String,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                completion(raw)
                return
            }
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }
}
