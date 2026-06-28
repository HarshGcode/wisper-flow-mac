import AVFoundation

/// Hinglish mode: records the mic to a file, then transcribes it with Whisper
/// (whisper-large-v3) via Groq's free API. Whisper handles mixed Hindi+English
/// (code-switching) in a single pass, much better than the OS speech engine.
final class WhisperService {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func start() {
        guard Settings.groqKey != nil else {
            onError?("Set your Whisper (Groq) API key first")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wispr_\(UUID().uuidString).m4a")
        fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            onPartial?("Listening…")
        } catch {
            onError?("Recorder failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        guard let url = fileURL, let key = Settings.groqKey else {
            onFinal?("")
            return
        }
        onPartial?("Transcribing…")
        transcribe(url: url, key: key)
    }

    private func transcribe(url: URL, key: String) {
        guard let audio = try? Data(contentsOf: url) else {
            DispatchQueue.main.async { self.onError?("No audio recorded"); self.onFinal?("") }
            return
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func part(_ s: String) { body.append(s.data(using: .utf8)!) }
        func field(_ name: String, _ value: String) {
            part("--\(boundary)\r\n")
            part("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            part("\(value)\r\n")
        }
        field("model", "whisper-large-v3")          // multilingual; auto-detects Hindi+English
        field("response_format", "text")
        field("temperature", "0")
        // No "language" field → Whisper auto-detects and keeps the natural Hinglish mix.
        part("--\(boundary)\r\n")
        part("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        part("Content-Type: audio/m4a\r\n\r\n")
        body.append(audio)
        part("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, response, error in
            try? FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                if let error = error {
                    self.onError?("Network: \(error.localizedDescription)")
                    self.onFinal?("")
                    return
                }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let text = String(data: data ?? Data(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if code != 200 {
                    self.onError?("Whisper error \(code) — check your Groq API key")
                    self.onFinal?("")
                } else {
                    self.onFinal?(text)
                }
            }
        }.resume()
    }
}
