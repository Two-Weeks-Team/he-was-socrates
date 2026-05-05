import Foundation

/// NSError domains for the engine layer per
/// `runs/2026-05-05-spec/spec/error-catalog.md`.
public enum SocraticErrorDomain {
    public static let stt = "com.twoweeks.hewassocrates.stt"
    public static let tts = "com.twoweeks.hewassocrates.tts"
    public static let model = "com.twoweeks.hewassocrates.model"
    public static let viseme = "com.twoweeks.hewassocrates.viseme"
    public static let mode = "com.twoweeks.hewassocrates.mode"
    public static let media = "com.twoweeks.hewassocrates.media"
    public static let sandbox = "com.twoweeks.hewassocrates.sandbox"
    public static let storage = "com.twoweeks.hewassocrates.storage"
    public static let osCompat = "com.twoweeks.hewassocrates.oscompat"
}

/// Catalog of NSError codes per `runs/2026-05-05-spec/spec/error-catalog.md`.
///
/// PR-ε: cases are annotated with their emit status as of the audit
/// (2026-05-06). "Emitted" means at least one runtime call site exists in
/// `Sources/`. "Reserved" means the spec defined the code but no runtime
/// path raises it yet — usually a Phase-4 wiring placeholder. A future PR
/// that lights one up should drop the `// reserved — Phase-4` annotation.
public enum SocraticErrorCode: Int {
    // STT
    case sttMicrophonePermissionDenied = 1001  // emitted
    case sttSpeechRecognitionPermissionDenied = 1002  // emitted
    case sttLocaleModelMissing = 1003  // emitted
    case sttSilenceTimeout = 1004  // reserved — Phase-4 (silence VAD)
    case sttRecognitionFailed = 1005  // reserved — Phase-4 (delegate didFail)

    // TTS
    case ttsVoiceNotInstalled = 2001  // reserved — Phase-4 (specific voice missing)
    case ttsRateClipped = 2002  // reserved — Phase-4
    case ttsNoVoicesAvailable = 2003  // emitted

    // Model
    case modelOOM = 3001  // reserved — Phase-4 (MLX runtime OOM)
    case modelFileCorrupt = 3002  // reserved — Phase-4 (SHA mismatch)
    case modelLoadFailed = 3003  // emitted
    case modelInferenceTimeout = 3004  // emitted
    case modelMalformedJSON = 3005  // emitted
    case modelHallucinatedFunction = 3006  // reserved — Phase-4 (parser unknown function)

    // Viseme
    case visemeDriftExceeded = 4001  // reserved — Phase-4 (driftAlert hookup)
    case visemeStreamStalled = 4002  // reserved — Phase-4
    case visemeG2PFailed = 4003  // reserved — Phase-4

    // Mode classification
    case modeConfidenceBelowThreshold = 5001  // reserved — Phase-4
    case modeAmbiguous = 5002  // reserved — Phase-4

    // Media permissions
    case mediaTCCRevokedMidSession = 6001  // reserved — Phase-4 (mid-session revocation watcher)

    // Storage
    case storageDiskFull = 7001  // reserved — Phase-4 (Core Data migration)
    case storageMigrationFailed = 7002  // reserved — Phase-4
    case storageDBCorrupt = 7003  // reserved — Phase-4

    // OS compatibility
    case osVersionTooLow = 8001  // reserved — Phase-4 (App Sandbox check)
    case archUnsupportedIntel = 8002  // reserved — Phase-4
}

/// Helper to construct domain-tagged NSErrors with localized messages.
public struct EngineError {
    public static func make(
        domain: String,
        code: SocraticErrorCode,
        descriptionKO: String,
        descriptionEN: String,
        recoverySuggestionKO: String? = nil,
        recoverySuggestionEN: String? = nil,
        underlying: Error? = nil
    ) -> NSError {
        var info: [String: Any] = [
            NSLocalizedDescriptionKey: "\(descriptionKO) / \(descriptionEN)",
            "ko.NSLocalizedDescription": descriptionKO,
            "en.NSLocalizedDescription": descriptionEN,
        ]
        if let recoveryKO = recoverySuggestionKO, let recoveryEN = recoverySuggestionEN {
            info[NSLocalizedRecoverySuggestionErrorKey] = "\(recoveryKO) / \(recoveryEN)"
            info["ko.NSLocalizedRecoverySuggestion"] = recoveryKO
            info["en.NSLocalizedRecoverySuggestion"] = recoveryEN
        }
        if let underlying {
            info[NSUnderlyingErrorKey] = underlying as NSError
        }
        return NSError(domain: domain, code: code.rawValue, userInfo: info)
    }
}
