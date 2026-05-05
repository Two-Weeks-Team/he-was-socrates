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

        viseme.start()
        transition(to: .idle)
    }

    public func shutdown() {
        viseme.stop()
        tts.cancel()
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

        let storedWonder = await log.append(Wonder(
            userUtterance: trimmed,
            socraticReply: output.socraticReply,
            mode: output.mode.mode,
            modeConfidence: output.mode.confidence,
            language: language
        ))
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

    // MARK: - Phase transition

    private func transition(to next: Phase) {
        guard phase != next else { return }
        phase = next
        onPhaseChanged?(next)
    }
}
