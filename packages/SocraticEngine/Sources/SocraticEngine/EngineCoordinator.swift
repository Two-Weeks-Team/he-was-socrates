import Foundation

#if canImport(AVFAudio)
import AVFAudio
#endif

/// Composes the engine's six subsystems into a hands-free turn loop:
///
///     [user presses Space]
///         AudioInputManager.startListening()
///     [user releases Space]
///         AudioInputManager.stopListening() → onFinalTranscript
///             FunctionCallOrchestrator.runTurn(...) → TurnOutput
///                 (deferred?) → speak short refusal
///                 (else)      → WonderingLog.append + TTSManager.speak
///                                 → VisemeDriver schedule (Apple markers OR JamoTimeline fallback)
///
/// All public mutators dispatch on the @MainActor. Per-turn state advances
/// via the `Phase` enum so UI can reflect progress (idle / listening /
/// thinking / speaking / error).
@MainActor
public final class EngineCoordinator {

    public enum Phase: Sendable, Equatable {
        case bootstrapping
        case idle
        case listening
        case thinking(correlationId: UUID)
        case surfacing(correlationId: UUID)
        case speaking(reply: String, deferred: Bool)
        case failed(String)
    }

    // MARK: - Subsystems

    public let audio: AudioInputManager
    public let tts: TTSManager
    public let viseme: VisemeDriver
    public let log: WonderingLog
    public let gemma: GemmaService
    public let orchestrator: FunctionCallOrchestrator

    // MARK: - State

    public private(set) var phase: Phase = .bootstrapping
    public var locale: Language {
        get { audio.locale }
        set { audio.locale = newValue }
    }

    /// Fired on every phase transition for UI binding.
    public var onPhaseChanged: ((Phase) -> Void)?
    public var onPartialTranscript: ((String) -> Void)?
    public var onCaptionUpdate: ((String) -> Void)?

    // MARK: - Init

    public init(
        audio: AudioInputManager? = nil,
        tts: TTSManager? = nil,
        viseme: VisemeDriver? = nil,
        log: WonderingLog? = nil,
        gemmaMode: GemmaService.RuntimeMode = .stub,
        phonemeMap: PhonemeMap = .default
    ) {
        self.audio = audio ?? AudioInputManager()
        self.tts = tts ?? TTSManager()
        self.viseme = viseme ?? VisemeDriver(phonemeMap: phonemeMap)
        self.log = log ?? WonderingLog()
        self.gemma = GemmaService(mode: gemmaMode)
        self.orchestrator = FunctionCallOrchestrator(gemma: self.gemma)

        wireSubsystems()
    }

    private func wireSubsystems() {
        // Audio → coordinator
        audio.onFinalTranscript = { [weak self] (text, lang) in
            Task { @MainActor [weak self] in
                await self?.handleFinalTranscript(text, language: lang)
            }
        }
        audio.onPartialTranscript = { [weak self] partial in
            Task { @MainActor [weak self] in
                self?.onPartialTranscript?(partial)
            }
        }
        audio.onError = { [weak self] err in
            Task { @MainActor [weak self] in
                self?.transition(to: .failed("audio: \(err.localizedDescription)"))
            }
        }

        // TTS → viseme + caption
        tts.onWillSpeakWord = { [weak self] (range, fullText) in
            Task { @MainActor [weak self] in
                self?.onCaptionUpdate?(fullText)
            }
        }
        tts.onUtteranceStart = { [weak self] in
            Task { @MainActor [weak self] in
                self?.viseme.notePlaybackStarted()
            }
        }
        tts.onUtteranceEnd = { [weak self] in
            Task { @MainActor [weak self] in
                self?.viseme.reset()
                self?.transition(to: .idle)
            }
        }
        // PR-β: AVSpeechSynthesizer.stopSpeaking(at: .immediate) fires
        // didCancel on the synthesizer delegate (see Apple Speech Synthesis
        // docs). The watchdog calls `tts.cancel()` and we must mirror the
        // viseme/phase teardown the success path runs in `onUtteranceEnd`.
        // Otherwise the bust mouth is left mid-shape and the phase only
        // advances via the watchdog's own `transition(.idle)` call —
        // visible for one render frame as a frozen non-REST viseme.
        tts.onUtteranceCancel = { [weak self] in
            Task { @MainActor [weak self] in
                self?.viseme.reset()
                self?.transition(to: .idle)
            }
        }
        tts.onPhonemeMarker = { [weak self] (label, offsetMs) in
            Task { @MainActor [weak self] in
                self?.viseme.ingest(appleLabel: label, audioOffsetMs: offsetMs)
            }
        }
        tts.onPlaybackTimeUpdate = { [weak self] ms in
            Task { @MainActor [weak self] in
                self?.viseme.updateAudioClock(ms)
            }
        }
        // Korean fallback when Apple emits no phoneme markers.
        tts.onPhonemeStreamUnavailable = { [weak self] (text, lang, durationMs) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let entries = JamoTimeline.buildSchedule(
                    text: text,
                    totalDurationMs: durationMs,
                    phonemeMap: .default
                )
                let driverSchedule = JamoTimeline.toDriverSchedule(entries)
                self.viseme.ingestSchedule(driverSchedule)
            }
        }
    }

    // MARK: - Lifecycle

    /// Bootstrap: request permissions, load Gemma model, start viseme tick.
    public func bootstrap() async {
        transition(to: .bootstrapping)

        let permission = await audio.requestPermissions()
        if case .denied(let reason) = permission {
            transition(to: .failed("permission denied: \(reason)"))
            return
        }
        if case .restricted = permission {
            transition(to: .failed("permission restricted"))
            return
        }

        do {
            try await gemma.loadModel()
        } catch {
            transition(to: .failed("gemma load: \(error.localizedDescription)"))
            return
        }

        // Warm the inference path so turn 1 doesn't eat a 1-2 s GPU pipeline
        // cold-start on top of the actual generation. Failure here is
        // non-fatal — the first real turn would simply pay the warm-up cost
        // itself, with the same bust UX we already shipped.
        await gemma.warmup()

        viseme.start()
        transition(to: .idle)
    }

    public func shutdown() {
        viseme.stop()
        tts.cancel()
        Task { await gemma.resetSession() }
        transition(to: .idle)
    }

    // MARK: - Turn

    /// Press space → start listening.
    public func beginListening() throws {
        guard phase == .idle else { return }
        try audio.startListening()
        transition(to: .listening)
    }

    /// Release space → stop listening (final transcript flows in async).
    public func endListening() {
        guard phase == .listening else { return }
        audio.stopListening()
    }

    private func handleFinalTranscript(_ text: String, language: Language) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            transition(to: .idle)
            return
        }

        let correlationId = UUID()
        transition(to: .thinking(correlationId: correlationId))

        let input = FunctionCallOrchestrator.TurnInput(
            utterance: trimmed,
            language: language,
            recentHistoryCompressed: await compressedRecentHistory()
        )

        let output: FunctionCallOrchestrator.TurnOutput
        do {
            output = try await orchestrator.runTurn(input, correlationId: correlationId)
        } catch {
            transition(to: .failed("orchestrator: \(error.localizedDescription)"))
            return
        }

        let storedWonder = await log.append(
            Wonder(
                userUtterance: trimmed,
                socraticReply: output.socraticReply,
                mode: output.mode.mode,
                modeConfidence: output.mode.confidence,
                language: language
            )
        )
        _ = storedWonder

        transition(to: .speaking(reply: output.socraticReply, deferred: output.deferred))

        // Pick voice per detected language; mode classification is informational.
        let voicePref: TTSManager.VoicePreference =
            (language == .ko || language == .auto) ? .korean : .english

        do {
            try await tts.speak(output.socraticReply, voice: voicePref)
        } catch {
            transition(to: .failed("tts: \(error.localizedDescription)"))
        }
    }

    /// Compress recent wondering log for surface_past_wonder context. Phase 1
    /// uses a simple "newest 5 truncated" projection; Phase 4 will replace
    /// with an embedding-backed compressed summary.
    private func compressedRecentHistory() async -> String {
        let count = await log.count()
        guard count > 0 else { return "" }
        // Stub: caller's last few user utterances joined.
        // Real impl in Phase 4 replaces with Gemma compressed summary.
        return "(\(count) past wonders, surface available)"
    }

    // MARK: - Phase transition + watchdog

    /// Outstanding watchdog that fires if the current phase hasn't ended
    /// within its expected window. Recovers to `.idle` so the user can
    /// press Spacebar again. Cancelled on every phase change.
    private var phaseWatchdog: Task<Void, Never>?

    private func transition(to next: Phase) {
        guard phase != next else { return }
        phase = next
        onPhaseChanged?(next)
        scheduleWatchdog(for: next)
    }

    /// Phase budgets:
    ///   bootstrapping — permission prompts + Gemma model load + warmup.
    ///                   600 s ceiling covers a slow first launch (cache
    ///                   miss, MLX kernel JIT). Beyond it we surface a
    ///                   `.failed` so the user isn't wedged on a black
    ///                   screen indefinitely. Closes RCA finding N3.
    ///   listening — user holds Space; STT can lag a beat
    ///   thinking  — first Gemma turn includes a one-time MLX warmup,
    ///               subsequent turns are seconds. 60s window covers both.
    ///   surfacing — pure-engine search over the wondering log
    ///                (reserved — iter2 §A7 stall fallback; no transition
    ///                path active in Phase 1–3, but budget kept for forward
    ///                compatibility per CONTRIBUTING.md L27-31)
    ///   speaking  — TTS playback for a long Socratic question
    ///   failed    — auto-rearm to .idle after 5 s. Not a teardown —
    ///               just clears the failure UI so the user can retry
    ///               without restarting the app. Closes finding D + N8.
    ///   idle      — terminal; no watchdog.
    private func scheduleWatchdog(for next: Phase) {
        phaseWatchdog?.cancel()
        let budget: TimeInterval?
        switch next {
        case .bootstrapping: budget = 600
        case .listening: budget = 60
        case .thinking: budget = 60
        case .surfacing: budget = 10
        case .speaking: budget = 60
        case .failed: budget = 5
        case .idle:
            budget = nil
        }
        guard let budget else { return }
        let snapshot = next
        phaseWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(budget * 1_000_000_000))
            guard let self else { return }
            guard self.phase == snapshot else { return }

            self.runWatchdogBody(snapshot: snapshot)
        }
    }

    /// Watchdog body extracted so test seams can invoke it without
    /// waiting on a real `Task.sleep`. Internal so `@testable` can call it
    /// via `_test_simulateWatchdogElapsed()`.
    @MainActor
    internal func runWatchdogBody(snapshot: Phase) {
        guard self.phase == snapshot else { return }
        _runWatchdogTransitions(snapshot: snapshot)
    }

    @MainActor
    private func _runWatchdogTransitions(snapshot: Phase) {
        switch snapshot {
        case .failed:
            // Auto-rearm: clear the failure surface so the user can
            // press Spacebar again. Don't tear down audio (it's already
            // inactive) or TTS (it's already cancelled by whatever
            // caused the failure).
            self.transition(to: .idle)

        case .bootstrapping:
            // Bootstrapping itself ran past its budget — `loadModel` or
            // `warmup` is wedged. Surface a clean failure so the user
            // gets a recoverable phase rather than an indefinite black
            // screen. Encoded key per PR-δ failure-key plan.
            self.transition(to: .failed("bootstrap.timeout"))

        default:
            // Active turn or surfacing — full teardown then idle.
            self.tts.cancel()
            self.viseme.reset()
            // `abortListening()` (PR-α) tears down the recognition
            // session WITHOUT synthesizing a phantom final.
            self.audio.abortListening()
            self.transition(to: .idle)
        }
    }

    // MARK: - Test seams (PR-β)
    //
    // Internal hooks reachable from `@testable import SocraticEngine` so
    // tests can drive watchdog logic without waiting on real Task.sleep
    // budgets. Each carries a `_test_` prefix to keep them visually
    // distinct from production surface.

    internal func _test_forceTransition(to phase: Phase) {
        // Mirror the production `transition(to:)` body: write phase, fire
        // the callback, AND arm the watchdog so .failed/.bootstrapping
        // auto-rearm logic is exercised from tests.
        self.phase = phase
        onPhaseChanged?(phase)
        scheduleWatchdog(for: phase)
    }

    internal func _test_simulateWatchdogElapsed() {
        runWatchdogBody(snapshot: self.phase)
    }

    internal func _test_fireOnUtteranceCancel() {
        Task { @MainActor [weak self] in
            self?.viseme.reset()
            self?.transition(to: .idle)
        }
    }
}
