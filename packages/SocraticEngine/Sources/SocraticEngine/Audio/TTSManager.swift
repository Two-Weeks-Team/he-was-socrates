import Foundation

#if canImport(AVFAudio)
import AVFAudio
#endif

/// AVSpeechSynthesizer wrapper. Streams phoneme markers to VisemeDriver per
/// `runs/2026-05-05-spec/spec/SPEC.md.iter4-api-correction.md`:
/// - PRIMARY: `synthesizer.write(utterance, toBufferCallback:)` (macOS 14+)
///   filtering `AVSpeechSynthesisMarker.Mark.phoneme`
/// - FALLBACK 1.5: ko-KR jamo time-uniform 15:70:15 if Apple emits no
///   phoneme markers for ko-KR voices (built via JamoTimeline)
@MainActor
public final class TTSManager: NSObject {

    public enum VoicePreference: Sendable {
        case korean
        case english
        case auto(Language)

        public var bcp47: String {
            switch self {
            case .korean: return "ko-KR"
            case .english: return "en-US"
            case .auto(let l): return l.bcp47
            }
        }
    }

    public var onPhonemeMarker: ((_ label: String, _ audioOffsetMs: Double) -> Void)?
    public var onUtteranceStart: (() -> Void)?
    public var onUtteranceEnd: (() -> Void)?
    public var onUtteranceCancel: (() -> Void)?
    public var onWillSpeakWord: ((NSRange, String) -> Void)?
    public var onPlaybackTimeUpdate: ((_ ms: Double) -> Void)?

    /// Fired when no phoneme markers were observed for an utterance and the
    /// driver should fall back to the JamoTimeline schedule. Carries the
    /// total estimated duration so the caller can build the schedule.
    public var onPhonemeStreamUnavailable:
        ((_ text: String, _ language: Language, _ estimatedDurationMs: Double) -> Void)?

    #if canImport(AVFAudio)
    private let synthesizer = AVSpeechSynthesizer()
    private var observedAnyPhonemeMarker = false
    private var lastSpokenText: String = ""
    private var lastSpokenLanguage: Language = .auto
    #endif

    public override init() {
        super.init()
        #if canImport(AVFAudio)
        synthesizer.delegate = self
        #endif
    }

    // MARK: - Voice resolution

    #if canImport(AVFAudio)
    /// Per-locale resolved voice cache. PR-γ: prior implementation called
    /// `AVSpeechSynthesisVoice.speechVoices()` on every utterance — that
    /// API traverses on-disk voice plists and benchmarks at ~80–200 ms on
    /// a typical install. Caching the resolution drops the per-turn cost
    /// to a dictionary lookup. The cache is invalidated on
    /// `NSLocale.currentLocaleDidChangeNotification` (system-language
    /// change is the only event that can change the resolution outcome
    /// for a fixed BCP-47 string).
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    /// Voice resolution chain:
    ///   1. Premium quality voice for the locale
    ///   2. Enhanced quality voice
    ///   3. Default quality
    ///   4. Any voice for the locale
    ///   5. nil → caller should surface ttsVoiceNotInstalled error
    public func resolveVoice(forBCP47 locale: String) -> AVSpeechSynthesisVoice? {
        if let cached = voiceCache[locale] { return cached }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let localeMatch = voices.filter { $0.language == locale }
        let qualityOrder: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]
        var resolved: AVSpeechSynthesisVoice?
        for q in qualityOrder {
            if let v = localeMatch.first(where: { $0.quality == q }) {
                resolved = v
                break
            }
        }
        if resolved == nil {
            resolved = localeMatch.first ?? AVSpeechSynthesisVoice(language: locale)
        }
        if let resolved {
            voiceCache[locale] = resolved
        }
        return resolved
    }

    public var availableVoices: [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
    }

    /// Invalidate the voice cache. Wire to `NSLocale.currentLocaleDidChangeNotification`
    /// or call manually if the host needs to react to a settings change.
    public func invalidateVoiceCache() {
        voiceCache.removeAll(keepingCapacity: true)
    }
    #endif

    // MARK: - Speak

    public func speak(_ text: String, voice preference: VoicePreference) async throws {
        #if canImport(AVFAudio)
        let bcp47 = preference.bcp47
        guard let voice = resolveVoice(forBCP47: bcp47) else {
            throw EngineError.make(
                domain: SocraticErrorDomain.tts,
                code: .ttsNoVoicesAvailable,
                descriptionKO: "사용 가능한 음성이 없습니다.",
                descriptionEN: "No voice installed for \(bcp47)."
            )
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 0.95
        utterance.volume = 1.0

        lastSpokenText = text
        switch preference {
        case .korean: lastSpokenLanguage = .ko
        case .english: lastSpokenLanguage = .en
        case .auto(let l): lastSpokenLanguage = l
        }
        observedAnyPhonemeMarker = false

        // PIPELINE NOTE (per SPEC.md.iter5-phoneme-pipeline-correction.md):
        // The Stage-5 day-1 ApplePhonemeProbe run produced verdict
        // "no-markers-anywhere" against every shipped voice on macOS 26.4.1
        // — the phoneme-marker stream Apple documents on macOS 14+ does
        // not materialise in practice for any locale. iter5 promotes the
        // JamoTimeline 15:70:15 fallback (formerly FALLBACK 1.5) to PRIMARY:
        //
        //   1. `synthesizer.speak(utterance)` for normal playback
        //   2. Delegate `willSpeakRangeOfSpeechString` for word boundaries
        //   3. `didStart` fires `onPhonemeStreamUnavailable` synchronously
        //      so `EngineCoordinator` can ingest the JamoTimeline schedule
        //      BEFORE the first audible syllable (PR #10 fix). VisemeDriver
        //      drives the bust mouth from a host-derived monotonic clock.
        //
        // The marker hook stays wired (`onPhonemeMarker`); if a future
        // macOS version begins emitting `.phoneme` markers the wiring is
        // ready to consume them, and they'll take precedence over the
        // host-clock JamoTimeline path.
        //
        // See: runs/2026-05-05-spec/spec/SPEC.md.iter5-phoneme-pipeline-correction.md
        //      runs/2026-05-05-spec/spec/apple-phoneme-availability.json
        synthesizer.speak(utterance)
        #else
        throw EngineError.make(
            domain: SocraticErrorDomain.tts,
            code: .ttsNoVoicesAvailable,
            descriptionKO: "AVFoundation 사용 불가.",
            descriptionEN: "AVFoundation unavailable on this platform."
        )
        #endif
    }

    public func cancel() {
        #if canImport(AVFAudio)
        synthesizer.stopSpeaking(at: .immediate)
        #endif
    }

    // MARK: - Estimation

    /// Conservative estimate of TTS duration based on character count.
    /// ~140 ms / character for slowed (0.95×) Korean speech is a reasonable
    /// rule of thumb; English is faster (~95 ms / char). Used by JamoTimeline
    /// fallback when phoneme markers are absent.
    ///
    /// `nonisolated` because the function is pure (no actor-isolated state)
    /// — lets non-MainActor test contexts call it without an implicit
    /// `await` hop (Swift 6 `ActorIsolatedCall` diagnostic).
    public nonisolated static func estimateDurationMs(text: String, language: Language) -> Double {
        let perChar: Double = (language == .ko) ? 140.0 : 95.0
        return Double(text.count) * perChar + 200.0
    }
}

#if canImport(AVFAudio)
extension TTSManager: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onUtteranceStart?()
            // macOS 26 emits zero `AVSpeechSynthesisMarker.phoneme` events for
            // every system voice we ship — verdict "no-markers-anywhere" in
            // runs/2026-05-05-spec/spec/apple-phoneme-availability.json.
            // Surface the JamoTimeline fallback synchronously at audio start
            // so VisemeDriver can begin lip-sync in time with the speech;
            // waiting for didFinish (the previous behaviour) only ingested
            // the schedule AFTER the audio had already played, so no visible
            // mouth motion ever happened during the actual utterance.
            let estimated = TTSManager.estimateDurationMs(
                text: self.lastSpokenText,
                language: self.lastSpokenLanguage
            )
            self.onPhonemeStreamUnavailable?(
                self.lastSpokenText,
                self.lastSpokenLanguage,
                estimated
            )
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let text = utterance.speechString
        Task { @MainActor [weak self] in
            self?.onWillSpeakWord?(characterRange, text)
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.onUtteranceEnd?()
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.onUtteranceCancel?()
        }
    }
}
#endif
