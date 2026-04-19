import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechService: ObservableObject, SpeechRepository {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
        return status == .authorized
    }

    func startRecording() throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // .playAndRecord is required for .duckOthers to take effect.
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                throw SpeechServiceError.recognitionRequestCreationFailed
            }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }

                var isFinal = false
                if let result {
                    let transcribed = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                    Task { @MainActor [weak self] in
                        self?.transcript = transcribed
                    }
                }

                if error != nil || isFinal {
                    Task { @MainActor [weak self] in
                        self?.stopRecording()
                    }
                }
            }

            let nativeFormat = inputNode.outputFormat(forBus: 0)
            let recordingFormat = nativeFormat.sampleRate > 0
                ? nativeFormat
                : AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
            let req = recognitionRequest
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                req.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            transcript = ""
            isRecording = true
        } catch {
            stopRecording()
            throw error
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        // Reactivate other audio that was ducked.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        transcript = ""
    }
}

enum SpeechServiceError: LocalizedError {
    case recognitionRequestCreationFailed

    var errorDescription: String? {
        switch self {
        case .recognitionRequestCreationFailed:
            return "Unable to create speech recognition request"
        }
    }
}
