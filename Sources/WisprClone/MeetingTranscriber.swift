import AVFoundation
import Speech
import AppKit

/// Meeting Mode: continuously transcribes your microphone on-device and appends
/// each finalized phrase (with a timestamp) to a text file in
/// ~/Documents/WisprClone-Transcripts/. Works alongside any meeting app
/// (Zoom, Google Meet, Teams) — it just listens to your mic.
final class MeetingTranscriber {
    private let engine = AVAudioEngine()
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: Settings.language))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var current = ""
    private var fileURL: URL?

    private(set) var isRunning = false

    /// Latest finalized line, for the UI.
    var onLine: ((String) -> Void)?
    var onError: ((String) -> Void)?

    static var transcriptsFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("WisprClone-Transcripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var currentFile: URL? { fileURL }

    // MARK: - Start / stop

    func start() {
        guard !isRunning else { return }
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: Settings.language))
        guard let recognizer, recognizer.isAvailable else {
            onError?("Speech recognizer unavailable for \(Settings.language)")
            return
        }

        // Create the transcript file with a header.
        let nameFmt = DateFormatter(); nameFmt.dateFormat = "yyyy-MM-dd-HHmm"
        let url = Self.transcriptsFolder.appendingPathComponent("Meeting-\(nameFmt.string(from: Date())).txt")
        let headerFmt = DateFormatter(); headerFmt.dateFormat = "yyyy-MM-dd HH:mm"
        let header = "Meeting transcript — \(headerFmt.string(from: Date()))\n"
            + String(repeating: "=", count: 50) + "\n\n"
        try? header.data(using: .utf8)?.write(to: url)
        fileURL = url

        // Install a single mic tap that feeds whichever request is current.
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            onError?("Audio engine failed: \(error.localizedDescription)")
            return
        }

        isRunning = true
        startSegment()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        flushSegment()
        task?.cancel(); task = nil; request = nil
    }

    // MARK: - Segments
    // SFSpeechRecognizer caps a single request's duration, and emits `isFinal`
    // after a pause. We write each finalized phrase, then start a fresh request
    // so transcription continues for the whole meeting.

    private func startSegment() {
        guard isRunning, let recognizer else { return }
        current = ""
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        if #available(macOS 13, *) {
            req.addsPunctuation = true
        }
        request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.current = result.bestTranscription.formattedString
                if result.isFinal {
                    self.flushSegment()
                    self.restartSegment()
                }
            }
            if error != nil {
                self.flushSegment()
                self.restartSegment()
            }
        }
    }

    private func restartSegment() {
        task?.cancel(); task = nil; request = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, self.isRunning else { return }
            self.startSegment()
        }
    }

    private func flushSegment() {
        let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
        current = ""
        guard !text.isEmpty, let url = fileURL else { return }
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        let line = "[\(timeFmt.string(from: Date()))] \(text)\n"
        appendToFile(line, url: url)
        DispatchQueue.main.async { self.onLine?(text) }
    }

    private func appendToFile(_ s: String, url: URL) {
        guard let data = s.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }
}
