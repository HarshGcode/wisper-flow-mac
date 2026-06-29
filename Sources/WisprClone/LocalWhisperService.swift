import AVFoundation

/// Fully on-device transcription using a bundled whisper.cpp binary + model.
/// No API key, no internet, nothing leaves the Mac. Handles all languages well
/// (multilingual Whisper). For "Hinglish" it runs with language=en so Hindi is
/// transliterated to Roman script (e.g. "kya kar rahe ho") without needing an LLM.
final class LocalWhisperService {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    /// True if the bundled engine is present (so callers can fall back if not).
    static var isAvailable: Bool { binaryPath != nil && modelPath != nil }

    private static var binaryPath: String? { Bundle.main.path(forResource: "whisper-cli", ofType: nil) }
    private static var modelPath: String? { Bundle.main.path(forResource: "ggml-small", ofType: "bin") }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func start() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wispr_\(UUID().uuidString).wav")
        fileURL = url
        // 16 kHz mono PCM WAV — what whisper.cpp expects.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
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
        guard let url = fileURL else { onFinal?(""); return }
        onPartial?("Transcribing…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let text = self?.transcribe(url) ?? ""
            DispatchQueue.main.async { self?.onFinal?(text) }
        }
    }

    private func transcribe(_ url: URL) -> String {
        defer { try? FileManager.default.removeItem(at: url) }
        guard let binary = Self.binaryPath, let model = Self.modelPath else {
            DispatchQueue.main.async { self.onError?("Local Whisper engine not bundled") }
            return ""
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = [
            "-m", model,
            "-f", url.path,
            "-l", whisperLang(Settings.language),
            "-nt",            // no timestamps → plain text
            "-t", "4",        // threads
        ]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()  // discard logs

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            DispatchQueue.main.async { self.onError?("Whisper run failed: \(error.localizedDescription)") }
            return ""
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        // Return the raw transcript (native script). Hinglish romanization happens
        // in handleFinal so it's consistent across local + cloud engines.
        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Map our locale ids to Whisper codes. We always TRANSCRIBE in the spoken
    /// language (never translate). Hinglish uses Hindi, then romanizes above.
    private func whisperLang(_ id: String) -> String {
        switch id {
        case "hinglish": return "hi"
        case "hi-IN":    return "hi"
        case "en-US", "en-IN": return "en"
        case "es-ES":    return "es"
        case "fr-FR":    return "fr"
        case "de-DE":    return "de"
        case "ar-SA":    return "ar"
        case "zh-CN":    return "zh"
        default:         return "auto"
        }
    }
}
