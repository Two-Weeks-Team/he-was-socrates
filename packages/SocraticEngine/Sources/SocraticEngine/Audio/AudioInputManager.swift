import Foundation

#if canImport(Speech)
import Speech
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

/// SFSpeechRecognizer wrapper. Push-to-talk via Spacebar (per
/// `scaffold-plan-proposal.md` Phase 3) plus VAD silence-end fallback.
/// `requiresOnDeviceRecognition = true` enforces the no-cloud invariant
/// (RP D1, M07, SC7-005).
@MainActor
public final class AudioInputManager: NSObject {

    public enum State: Equatable, Sendable {
        case idle
        case requestingPermissions
        case ready
        case listening(startedAt: Date)
        case finalizing
        case failed(String)  // String description (NSError isn't Equatable cleanly)
    }

    public enum PermissionStatus: Sendable, Equatable {
        case granted
        case denied(reason: String)
        case notDetermined
        case restricted
    }

    public private(set) var state: State = .idle
    public var locale: Language = .auto

    public var onFinalTranscript: ((String, Language) -> Void)?
    public var onPartialTranscript: ((String) -> Void)?
    public var onError: ((NSError) -> Void)?

    #if canImport(Speech) && canImport(AVFAudio)
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    #endif

    public override init() {
        super.init()
    }

    // MARK: - Permissions

    public func requestPermissions() async -> PermissionStatus {
        state = .requestingPermissions
        #if canImport(Speech) && canImport(AVFAudio)
        // 1. Microphone permission via AVAudioApplication (macOS 14+).
        if #available(macOS 14.0, *) {
            let micGranted = await AVAudioApplication.requestRecordPermission()
            guard micGranted else {
                let err = EngineError.make(
                    domain: SocraticErrorDomain.stt,
                    code: .sttMicrophonePermissionDenied,
                    descriptionKO: "마이크 사용 권한이 거부되었습니다.",
                    descriptionEN: "Microphone permission denied.",
                    recoverySuggestionKO: "시스템 설정 > 개인 정보 보호 및 보안 > 마이크에서 권한을 허용해주세요.",
                    recoverySuggestionEN:
                        "Allow microphone access in System Settings > Privacy & Security > Microphone."
                )
                state = .failed("mic-denied")
                onError?(err)
                return .denied(reason: "microphone")
            }
        }

        // 2. Speech recognition authorization. The TCC callback fires on a
        // background queue (com.apple.root.default-qos); under Swift 6 strict
        // concurrency, calling `withCheckedContinuation` from a MainActor
        // method makes the resulting continuation MainActor-isolated, so
        // resuming it from the TCC background queue trips
        // `_swift_task_checkIsolatedSwift` → dispatch_assert_queue_fail →
        // SIGTRAP at first launch. We move the call into `Task.detached` so
        // the continuation runs in a nonisolated context; we re-enter
        // MainActor naturally on the surrounding `await`.
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await Task.detached {
            await withCheckedContinuation {
                (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status)
                }
            }
        }.value
        switch speechStatus {
        case .authorized:
            state = .ready
            return .granted
        case .denied:
            let err = EngineError.make(
                domain: SocraticErrorDomain.stt,
                code: .sttSpeechRecognitionPermissionDenied,
                descriptionKO: "음성 인식 권한이 거부되었습니다.",
                descriptionEN: "Speech recognition permission denied.",
                recoverySuggestionKO: "시스템 설정 > 개인 정보 보호 및 보안 > 음성 인식에서 권한을 허용해주세요.",
                recoverySuggestionEN:
                    "Allow speech recognition in System Settings > Privacy & Security > Speech Recognition."
            )
            state = .failed("speech-denied")
            onError?(err)
            return .denied(reason: "speech-recognition")
        case .restricted:
            state = .failed("speech-restricted")
            return .restricted
        case .notDetermined:
            state = .idle
            return .notDetermined
        @unknown default:
            return .denied(reason: "unknown")
        }
        #else
        state = .failed("platform-unsupported")
        return .denied(reason: "Speech framework unavailable on this platform")
        #endif
    }

    // MARK: - Listening

    public func startListening() throws {
        #if canImport(Speech) && canImport(AVFAudio)
        guard state == .ready || state == .idle else { return }

        let bcp47 = (locale == .auto ? Language.ko : locale).bcp47
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: bcp47))
        guard let recognizer, recognizer.isAvailable else {
            throw EngineError.make(
                domain: SocraticErrorDomain.stt,
                code: .sttLocaleModelMissing,
                descriptionKO: "\(bcp47) 음성 모델이 설치되지 않았습니다.",
                descriptionEN: "Speech recognition model for \(bcp47) is not installed."
            )
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true  // NO-CLOUD INVARIANT
        request.shouldReportPartialResults = true
        self.request = request

        // Wire up audio engine input node tap.
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.onFinalTranscript?(transcript, self.locale)
                    } else {
                        self.onPartialTranscript?(transcript)
                    }
                }
                if let error = error as NSError? {
                    self.onError?(error)
                }
            }
        }

        state = .listening(startedAt: Date())
        #else
        throw EngineError.make(
            domain: SocraticErrorDomain.stt,
            code: .sttLocaleModelMissing,
            descriptionKO: "음성 프레임워크 사용 불가.",
            descriptionEN: "Speech framework unavailable."
        )
        #endif
    }

    public func stopListening() {
        #if canImport(Speech) && canImport(AVFAudio)
        state = .finalizing
        request?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        task?.finish()
        // Result delivery happens asynchronously via the recognitionTask callback.
        state = .ready
        #endif
    }
}
