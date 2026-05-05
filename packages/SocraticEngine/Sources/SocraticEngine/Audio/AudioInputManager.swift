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

    /// Most recent partial transcript observed during the active session.
    /// `stopListening()` promotes this to a final transcript synchronously
    /// when the recognition task didn't deliver `isFinal=true` — Apple's
    /// `SFSpeechRecognitionTask.finish()` does not contractually guarantee
    /// a final callback (see Apple forum thread 125279, ko-KR observed
    /// drop-rate is non-trivial on short / silent-tail utterances).
    private var lastPartialTranscript: String = ""

    /// Per-session token captured by value into the recognition closure.
    /// On every `startListening()` we mint a fresh `UUID` and stamp this
    /// field; the closure compares its captured copy against
    /// `currentSessionId` before touching any state. A stale callback
    /// (different session OR session aborted via `abortListening()`) is
    /// dropped at the guard. Aligns with the Swift 6 strict-concurrency
    /// "task identity tokens across actor hops" pattern documented in
    /// WWDC24 session 10169 "Migrate your app to Swift 6".
    private var currentSessionId: UUID?

    /// Sentinel for the "final has already been promoted (via real or
    /// fallback path) for the current session" condition. Apple's
    /// `SFSpeechRecognitionTask` resultHandler is empirically observed to
    /// emit `isFinal=true` more than once on rare iOS / macOS versions
    /// (forum 125279) and to fire `isFinal` followed by an error in normal
    /// flow. Guarding `onFinalTranscript` with this flag is the
    /// documented-best-effort substitute for a contract Apple does not
    /// supply.
    private var didPromoteFinal: Bool = false

    #if canImport(Speech) && canImport(AVFAudio)
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    #endif

    public override init() {
        super.init()
    }

    // MARK: - Audio tap installer (nonisolated)

    /// Installs an audio buffer tap on `inputNode` whose closure forwards
    /// every buffer into `request`. Declared `nonisolated` (and `static`)
    /// so the closure literal is built outside any actor isolation context;
    /// AVAudioEngine then invokes it freely from its realtime queue.
    /// SFSpeechAudioBufferRecognitionRequest.append is thread-safe per
    /// Apple's documentation.
    nonisolated private static func installNonisolatedTap(
        onInputNode inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
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

        // 2. Speech recognition authorization.
        //
        // The TCC callback fires on a background queue
        // (com.apple.root.default-qos); under Swift 6 strict concurrency a
        // bare `withCheckedContinuation` from a MainActor method produces a
        // MainActor-isolated continuation, and resuming it from the TCC
        // background queue trips `_swift_task_checkIsolatedSwift` →
        // `dispatch_assert_queue_fail` → SIGTRAP at first launch. We hop
        // into `Task.detached` so the continuation runs in a nonisolated
        // context; we re-enter MainActor naturally on the surrounding
        // `await`.
        //
        // PR-β: in rare cases (process-termination signal during the OS
        // prompt, tccd hang, audit-log denial) TCC has been observed to
        // never invoke the completion at all, leaving the bootstrap
        // wedged forever in `.bootstrapping` (RCA finding N1). We race
        // the authorization callback against a 10 s deadline using a
        // TaskGroup — first to finish wins, and a stalled TCC degrades to
        // `.notDetermined` instead of an indefinite await.
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withTaskGroup(
            of: SFSpeechRecognizerAuthorizationStatus.self
        ) { group in
            group.addTask {
                await Task.detached {
                    await withCheckedContinuation {
                        (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                        SFSpeechRecognizer.requestAuthorization { status in
                            cont.resume(returning: status)
                        }
                    }
                }.value
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 s
                return .notDetermined
            }
            // Whichever task completes first is the result.
            let result = await group.next() ?? .notDetermined
            group.cancelAll()
            return result
        }
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

        // Mint a fresh per-session token. Captured by VALUE in the
        // recognition closure below — Swift 6 strict concurrency declares
        // `UUID` Sendable, so this survives the closure crossing onto
        // SFSpeech's internal queue and back to MainActor without any
        // capture diagnostics. Apple-endorsed identity-token pattern per
        // WWDC24 #10169 "Migrate your app to Swift 6".
        let sessionId = UUID()
        self.currentSessionId = sessionId
        self.didPromoteFinal = false
        self.lastPartialTranscript = ""

        // Cancel any lingering task from a prior session before installing
        // a new one. SFSpeechRecognitionTask.cancel() is the documented
        // teardown for an in-flight recognition; without it, a delayed
        // callback from the previous session would race the new one.
        self.task?.cancel()
        self.task = nil

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
        // PR-θ F8: NO-CLOUD invariant means we cannot fall back to network
        // recognition. If `supportsOnDeviceRecognition` is false for this
        // locale, setting `requiresOnDeviceRecognition = true` later (line
        // ~233) produces kLSRErrorDomain code 1101 at the first audio
        // buffer — surfaced as a generic runtime error mid-utterance.
        // Apple Speech docs document `supportsOnDeviceRecognition` as the
        // precheck. We fail early with a specific code so the host can
        // render the recovery hint in `FailedMessage`.
        guard recognizer.supportsOnDeviceRecognition else {
            throw EngineError.make(
                domain: SocraticErrorDomain.stt,
                code: .sttLocaleModelMissing,
                descriptionKO: "\(bcp47) 음성 모델의 기기 내 처리를 지원하지 않습니다.",
                descriptionEN:
                    "On-device recognition not supported for \(bcp47). NO-CLOUD invariant prevents network fallback."
            )
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true  // NO-CLOUD INVARIANT
        request.shouldReportPartialResults = true
        self.request = request

        // Audio engine input node tap. AVAudioEngine invokes this on a
        // realtime audio queue (CADeprecated::RealtimeMessenger). A
        // MainActor-isolated closure would trip
        // `_swift_task_checkIsolatedSwift` → SIGTRAP on the first audio
        // buffer; we delegate installation to a `nonisolated` static
        // helper so the closure literal is built outside any actor.
        // SFSpeechAudioBufferRecognitionRequest.append is documented
        // thread-safe.
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Apple's Speech sample "Recognizing speech in live audio" calls
        // `removeTap` defensively before `installTap` — the canonical
        // guard against the documented `installTap`-twice crash.
        inputNode.removeTap(onBus: 0)
        Self.installNonisolatedTap(onInputNode: inputNode, format: format, request: request)

        audioEngine.prepare()
        try audioEngine.start()

        // SFSpeechRecognitionTask resultHandler fires on an arbitrary
        // queue. The outer closure doesn't capture `self`; the inner
        // `Task { @MainActor }` pulls `weak self` plus the by-value
        // `sessionId` token so a stale callback (different session OR
        // session aborted) is dropped at the guard before any state
        // mutation. Apple does not contract single-fire on isFinal
        // (forum 125279); `didPromoteFinal` is the documented best-effort
        // substitute.
        self.task = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.currentSessionId == sessionId else { return }
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        guard !self.didPromoteFinal else { return }
                        self.didPromoteFinal = true
                        self.lastPartialTranscript = ""
                        self.onFinalTranscript?(transcript, self.locale)
                    } else {
                        self.lastPartialTranscript = transcript
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

    /// Stop listening. Tear down audio + recognition AND synchronously
    /// promote the latest partial transcript to a final, so the host's
    /// turn loop never wedges waiting for a final callback Apple's
    /// `SFSpeechRecognitionTask.finish()` does not contractually deliver.
    ///
    /// Earlier revisions used a 1.5 s `Task.sleep` safety net that fired
    /// `onFinalTranscript` from a deferred timer; that timer was the
    /// dominant per-turn latency tax (1.5 s pinned per ko-KR utterance)
    /// and produced phantom-final re-entries when the watchdog called
    /// this method on an idle session. Replaced with synchronous promote
    /// gated by `didPromoteFinal` so a real final still wins if it
    /// arrives between `task.finish()` and the next runloop tick.
    public func stopListening() {
        #if canImport(Speech) && canImport(AVFAudio)
        state = .finalizing

        // Apple SpeakToMe sample stop sequence.
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        let partialAtStop = lastPartialTranscript
        let captureLocale = locale
        task?.finish()

        // Synchronous promote. If the recognition callback has already
        // promoted a real final on the same MainActor turn (which would
        // have set `didPromoteFinal = true` above), this is a no-op.
        if !didPromoteFinal {
            didPromoteFinal = true
            lastPartialTranscript = ""
            onFinalTranscript?(partialAtStop, captureLocale)
        }

        state = .ready
        #endif
    }

    // MARK: - Test seams
    //
    // Internal hooks used by `@testable import SocraticEngine` to drive the
    // session-token + promote-guard logic without standing up a full
    // SFSpeechRecognizer pipeline. Marked `internal` so they're invisible
    // to release SDK consumers but reachable from `SocraticEngineTests`.
    // Each name carries the `_test_` prefix so a reader can't confuse it
    // for a public surface.

    internal func _test_seedPartial(_ text: String) {
        lastPartialTranscript = text
    }

    internal func _test_setStateForStop() {
        // Tests don't go through `startListening()`, so we mint a fake
        // session token by hand to exercise the promote path.
        currentSessionId = UUID()
        didPromoteFinal = false
    }

    internal var _test_currentSessionId: UUID? { currentSessionId }

    internal func _test_beginFakeSession() -> UUID {
        let id = UUID()
        currentSessionId = id
        didPromoteFinal = false
        return id
    }

    internal func _test_callbackWouldAccept(sessionId: UUID) -> Bool {
        return currentSessionId == sessionId
    }

    /// Tear down the recognition session WITHOUT firing any onFinal
    /// callback. Used by `EngineCoordinator`'s watchdog when the host
    /// wants to abandon the turn entirely (e.g. the watchdog timed out
    /// while we were still in `.listening`); without this method the
    /// watchdog's call to `stopListening()` would itself synthesize a
    /// phantom final and re-enter the turn loop. The session token is
    /// also cleared so any in-flight resultHandler hop drops at the
    /// `currentSessionId == sessionId` guard.
    public func abortListening() {
        #if canImport(Speech) && canImport(AVFAudio)
        // Invalidate the session token first so any callback already
        // in-flight on the MainActor queue early-returns at its guard.
        currentSessionId = nil
        didPromoteFinal = true
        lastPartialTranscript = ""

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        // `cancel()` (vs `finish()`) explicitly does NOT promise a final
        // result — exactly what we want for an aborted session.
        task?.cancel()
        task = nil

        state = .idle
        #endif
    }
}
