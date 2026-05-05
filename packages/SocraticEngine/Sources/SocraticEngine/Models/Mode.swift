import Foundation

/// User mode classified by Gemma `mode_classify` function-call.
/// Locked enum per `spec/function_call_contract.yaml`.
public enum Mode: String, Codable, Sendable, CaseIterable {
    case curiousAdult = "curious_adult"
    case learningStudent = "learning_student"
    case skeptical
    case other

    public var displayLabel: (ko: String, en: String) {
        switch self {
        case .curiousAdult:    return ("호기심 있는 어른", "Curious Adult")
        case .learningStudent: return ("배움 중인 학생", "Learning Student")
        case .skeptical:       return ("회의적", "Skeptical")
        case .other:           return ("기타", "Other")
        }
    }
}

/// Confidence-tagged classification result.
public struct ModeClassification: Codable, Sendable {
    public let mode: Mode
    public let confidence: Double
    public let reasoningSummary: String

    public init(mode: Mode, confidence: Double, reasoningSummary: String) {
        self.mode = mode
        self.confidence = confidence
        self.reasoningSummary = reasoningSummary
    }
}
