import Foundation

/// Public umbrella entry point for the He Was Socrates engine layer.
///
/// Convenience composer that wires the Phase 3+ subsystems together:
///   AudioInputManager → FunctionCallOrchestrator → TTSManager + VisemeDriver
///                                                ↘ WonderingLog
public enum SocraticEngineInfo {
    public static let bundleVersion = "0.1.0-phase1"
    public static let visemeCount = VisemeID.allCases.count
}
