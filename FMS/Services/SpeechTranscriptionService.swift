import AVFoundation
import Speech

/// On-device speech-to-text using Apple's Speech framework.
@Observable
@MainActor
final class SpeechTranscriptionService {
    var isRecording = false
    var partialTranscript = ""
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    var isAvailable: Bool {
        guard let speechRecognizer else { return false }
        return speechRecognizer.isAvailable
    }

    func requestPermissions() async -> Bool {
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard micGranted else {
            errorMessage = "Microphone access is required for voice messages."
            return false
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            errorMessage = nil
            return true
        case .denied:
            errorMessage = "Speech recognition is disabled. Enable it in Settings → Privacy."
            return false
        case .restricted:
            errorMessage = "Speech recognition is restricted on this device."
            return false
        case .notDetermined:
            errorMessage = "Speech recognition permission was not granted."
            return false
        @unknown default:
            errorMessage = "Speech recognition is unavailable."
            return false
        }
    }

    func startRecording() async throws {
        guard !isRecording else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechTranscriptionError.requestFailed
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let request = recognitionRequest
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        partialTranscript = ""
        errorMessage = nil
        isRecording = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                }
                if let error, self.isRecording {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Stops recording and returns the final transcript.
    func stopRecording() -> String {
        guard isRecording else { return partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines) }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancelRecording() {
        _ = stopRecording()
        partialTranscript = ""
    }
}

enum SpeechTranscriptionError: LocalizedError {
    case recognizerUnavailable
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device right now."
        case .requestFailed:
            return "Could not start voice recognition."
        }
    }
}
