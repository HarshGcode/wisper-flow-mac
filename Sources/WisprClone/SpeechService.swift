import AVFoundation
import Speech

/// Captures microphone audio and transcribes it on-device with SFSpeechRecognizer.
final class SpeechService {
    private let engine = AVAudioEngine()
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: Settings.language))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var isRunning = false

    /// Partial transcript as the user speaks.
    var onPartial: ((String) -> Void)?
    /// Final transcript when recording stops (may be empty).
    var onFinal: ((String) -> Void)?
    /// Non-fatal error surfaced to the UI.
    var onError: ((String) -> Void)?

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Requests microphone + speech-recognition authorization. Completion runs on the main thread.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            let speechOK = (speechStatus == .authorized)
            AVCaptureDevice.requestAccess(for: .audio) { micOK in
                DispatchQueue.main.async { completion(speechOK && micOK) }
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        // Recreate for the currently selected language (e.g. Hindi hi-IN).
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: Settings.language))
        guard let recognizer, recognizer.isAvailable else {
            onError?("Speech recognizer unavailable for \(Settings.language)")
            return
        }

        latest = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // Online (server) recognition is much more accurate for fast/accented
        // speech. Only force private on-device mode if the user opted in.
        if Settings.onDeviceOnly && recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        if #available(macOS 13, *) {
            request.addsPunctuation = true
        }
        self.request = request

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
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.latest = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.onPartial?(self.latest) }
                if result.isFinal {
                    self.finish()
                }
            }
            if error != nil {
                self.finish()
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // The recognition task emits a final result shortly after endAudio();
        // finish() is called from the task callback. Guard against a hang:
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard isRunning else { return }
        isRunning = false
        task?.cancel()
        task = nil
        request = nil
        let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async { self.onFinal?(text) }
    }
}
