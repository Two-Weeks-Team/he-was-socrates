import Foundation

/// Stable, dot-notation keys passed inside `EngineCoordinator.Phase.failed(String)`.
///
/// Background: per `CONTRIBUTING.md` L27-31 the `Phase` enum is part of
/// the stable public API surface — adding a struct payload would be a
/// source-breaking change requiring a SpecDD delta document. Rather than
/// widen the case shape we encode failure context as a stable string key
/// and let the SwiftUI layer (`StatusOverlay`) localize. The key surface
/// is itself stable: callers must use these constants instead of free-form
/// literals so a future Korean / English / Japanese translation can be
/// added without touching the engine layer.
///
/// Pattern: `<subsystem>.<noun>.<qualifier>` — domain dot notation, no
/// abbreviations (parses cleanly in any UI lookup table).
public enum PhaseFailureKey {

    // MARK: - Audio / permissions

    /// Microphone permission denied at startup or revoked mid-session.
    public static let micDenied = "audio.permission.microphone.denied"

    /// Speech-recognition permission denied at startup.
    public static let speechRecognitionDenied = "audio.permission.speech.denied"

    /// Speech-recognition restricted by parental controls / MDM.
    public static let speechRecognitionRestricted = "audio.permission.speech.restricted"

    /// Recognition or audio engine raised an NSError mid-session.
    public static let audioRuntimeError = "audio.runtime.error"

    /// PR-θ F8: SFSpeechRecognizer for the user's locale does not support
    /// on-device recognition. The NO-CLOUD invariant forbids the network
    /// fallback Apple's framework would otherwise use, so the engine
    /// surfaces this as a hard failure with a recoverable hint pointing
    /// users at the System Settings → Speech Recognition pane.
    public static let sttOnDeviceUnsupported = "audio.permission.speech.on-device-unsupported"

    /// PR-θ F9: AVAudioSession-class interruption (incoming call, route
    /// change, etc.) raised by AVAudioEngine mid-utterance.
    public static let audioInterrupted = "audio.runtime.interrupted"

    // MARK: - Gemma / orchestrator

    /// `GemmaService.loadModel` threw — usually missing weights, network
    /// unavailable to HuggingFace (NO-CLOUD: should never happen at
    /// runtime — staged at install via `make install-gemma-weights`).
    public static let gemmaLoadFailed = "gemma.load.failed"

    /// Inference completed but produced output that the parser couldn't
    /// recover into a `FunctionCallParser.Result`.
    public static let modelMalformedOutput = "gemma.output.malformed"

    /// `FunctionCallOrchestrator.runTurn` threw on the active turn.
    public static let orchestratorError = "orchestrator.error"

    // MARK: - TTS

    /// `AVSpeechSynthesizer.speak` failed (no installed voice for locale).
    public static let ttsVoiceMissing = "tts.voice.missing"

    /// TTS synthesis raised mid-utterance.
    public static let ttsRuntimeError = "tts.runtime.error"

    // MARK: - Lifecycle

    /// Bootstrap timed out (PR-β watchdog 600 s budget).
    public static let bootstrapTimeout = "bootstrap.timeout"

    /// Internal turn-loop watchdog tripped on a `.thinking` / `.speaking`.
    public static let turnTimeout = "turn.timeout"
}
