import Foundation

/// NSError domains for the engine layer per
/// `runs/2026-05-05-spec/spec/error-catalog.md`.
public enum SocraticErrorDomain {
    public static let stt   = "engineering.twoweeks.HeWasSocrates.STT"
    public static let tts   = "engineering.twoweeks.HeWasSocrates.TTS"
    public static let model = "engineering.twoweeks.HeWasSocrates.Model"
    public static let viseme = "engineering.twoweeks.HeWasSocrates.Viseme"
    public static let mode  = "engineering.twoweeks.HeWasSocrates.Mode"
    public static let media = "engineering.twoweeks.HeWasSocrates.Media"
    public static let sandbox = "engineering.twoweeks.HeWasSocrates.Sandbox"
    public static let storage = "engineering.twoweeks.HeWasSocrates.Storage"
    public static let osCompat = "engineering.twoweeks.HeWasSocrates.OSCompat"
}

public enum SocraticErrorCode: Int {
    // STT
    case sttMicrophonePermissionDenied = 1001
    case sttSpeechRecognitionPermissionDenied = 1002
    case sttLocaleModelMissing = 1003
    case sttSilenceTimeout = 1004
    case sttRecognitionFailed = 1005

    // TTS
    case ttsVoiceNotInstalled = 2001
    case ttsRateClipped = 2002
    case ttsNoVoicesAvailable = 2003

    // Model
    case modelOOM = 3001
    case modelFileCorrupt = 3002
    case modelLoadFailed = 3003
    case modelInferenceTimeout = 3004
    case modelMalformedJSON = 3005
    case modelHallucinatedFunction = 3006

    // Viseme
    case visemeDriftExceeded = 4001
    case visemeStreamStalled = 4002
    case visemeG2PFailed = 4003

    // Mode classification
    case modeConfidenceBelowThreshold = 5001
    case modeAmbiguous = 5002

    // Media permissions
    case mediaTCCRevokedMidSession = 6001

    // Storage
    case storageDiskFull = 7001
    case storageMigrationFailed = 7002
    case storageDBCorrupt = 7003

    // OS compatibility
    case osVersionTooLow = 8001
    case archUnsupportedIntel = 8002
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
