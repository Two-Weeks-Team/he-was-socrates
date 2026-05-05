import Foundation

/// User language. Lock-step with `function_call_contract.yaml`.
public enum Language: String, Codable, Sendable, CaseIterable {
    case ko
    case en
    case auto

    /// Mapping to BCP-47 locale identifier used by Speech framework + AVSpeechSynthesizer.
    public var bcp47: String {
        switch self {
        case .ko:   return "ko-KR"
        case .en:   return "en-US"
        case .auto: return "auto"  // resolved at runtime by AudioInputManager
        }
    }
}
