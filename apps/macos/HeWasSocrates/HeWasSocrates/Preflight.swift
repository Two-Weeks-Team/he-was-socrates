import AVFoundation
import Foundation
import Speech

/// First-launch readiness check (iter-6).
///
/// Runs before `EngineCoordinator.bootstrap()` so the user sees a single
/// "준비 상태" screen instead of fail-after-the-fact errors when a Korean /
/// English speech voice is missing or the on-device STT model is not yet
/// installed. The eight checks are independent and run in parallel via
/// async-let; the longest single check is `SpeechTranscriber.isAvailable`
/// (~50 ms on a warm process).
///
/// All checks are bilingual where applicable (the project speaks Korean
/// and English; both must be ready before the bust appears).
///
/// References:
///   - Apple HIG Onboarding (defer non-essential setup, guide step-by-step)
///   - WWDC25 #277 — SpeechAnalyzer / AssetInventory (macOS 26)
///   - rmcdongit System Preferences URL Scheme reference (Sequoia 15.2)
///   - claudedocs/2026-05-06-firstlaunch-ux-bestpractices.html §F1, §F2, §F6
public struct PreflightCheck: Identifiable, Equatable, Sendable {
    public enum Kind: String, CaseIterable, Equatable, Sendable {
        case macOSVersion
        case appleSilicon
        case diskSpace
        case koreanVoice
        case englishVoice
        case koreanSTT
        case englishSTT
        case microphonePermission
        case speechPermission
    }

    public let id: UUID
    public let kind: Kind
    public let passed: Bool
    public let userMessage: String?
    /// Raw deeplink string (kept as String so `PreflightCheck` is Equatable
    /// — `URL` itself is Equatable but storing closure-style installers is
    /// not, so we keep all action data as plain values and route by `kind`
    /// in the host layer).
    public let recoveryDeeplinkRaw: String?
    /// `true` when the check has an in-app remediation path (currently:
    /// `koreanSTT` / `englishSTT` via `AssetInventory`). `recoveryDeeplinkRaw`
    /// remains as a fallback for users who hit an `AssetInventory` failure.
    public let inAppInstallable: Bool
    /// `true` when the check is a "soft" item that should not block the
    /// "시작하기" button — the canonical example is the TCC permissions,
    /// which Apple HIG says to defer to point of use rather than gate at
    /// onboarding.
    public let blocking: Bool

    public var recoveryDeeplink: URL? {
        recoveryDeeplinkRaw.flatMap(URL.init(string:))
    }

    public init(
        kind: Kind,
        passed: Bool,
        userMessage: String?,
        recoveryDeeplinkRaw: String?,
        inAppInstallable: Bool,
        blocking: Bool
    ) {
        self.id = UUID()
        self.kind = kind
        self.passed = passed
        self.userMessage = userMessage
        self.recoveryDeeplinkRaw = recoveryDeeplinkRaw
        self.inAppInstallable = inAppInstallable
        self.blocking = blocking
    }
}

public enum PreflightRunner {

    /// Run every check in parallel; return in declaration order so the UI
    /// can render a stable list.
    public static func runAll() async -> [PreflightCheck] {
        async let macOS = checkMacOSVersion()
        async let arm = checkAppleSilicon()
        async let disk = checkDiskSpace(minBytes: 8 * 1024 * 1024 * 1024)
        async let voiceKo = checkVoice(language: "ko-KR", kind: .koreanVoice)
        async let voiceEn = checkVoice(language: "en-US", kind: .englishVoice)
        async let sttKo = checkSTT(localeId: "ko-KR", kind: .koreanSTT)
        async let sttEn = checkSTT(localeId: "en-US", kind: .englishSTT)
        let mic = checkMicrophonePermission()
        let speech = checkSpeechPermission()
        return [
            await macOS, await arm, await disk,
            await voiceKo, await voiceEn,
            await sttKo, await sttEn,
            mic, speech,
        ]
    }

    // MARK: - System

    private static func checkMacOSVersion() async -> PreflightCheck {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let ok = v.majorVersion >= 26
        return PreflightCheck(
            kind: .macOSVersion,
            passed: ok,
            userMessage: ok ? nil : "macOS 26 Tahoe 이상이 필요해. 현재 \(v.majorVersion).\(v.minorVersion).",
            recoveryDeeplinkRaw: nil,
            inAppInstallable: false,
            blocking: true
        )
    }

    private static func checkAppleSilicon() async -> PreflightCheck {
        // Gemma 4 MLX 4-bit weights require Apple Silicon. The runtime
        // check covers the (unlikely) case of an Intel Mac that somehow
        // got past the LSMinimumSystemVersion gate.
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        var value: Int32 = 0
        sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        let ok = value == 1
        return PreflightCheck(
            kind: .appleSilicon,
            passed: ok,
            userMessage: ok ? nil : "Apple Silicon이 필요해. Intel Mac에서는 Gemma 4 MLX가 동작하지 않는다.",
            recoveryDeeplinkRaw: nil,
            inAppInstallable: false,
            blocking: true
        )
    }

    private static func checkDiskSpace(minBytes: Int64) async -> PreflightCheck {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values?.volumeAvailableCapacityForImportantUsage ?? 0
        let ok = available >= minBytes
        let gbAvail = Double(available) / 1024.0 / 1024.0 / 1024.0
        return PreflightCheck(
            kind: .diskSpace,
            passed: ok,
            userMessage: ok ? nil
                : String(format: "디스크 여유가 부족해 — 약 %.1f GB만 남아 있어. 최소 8 GB가 필요해.", gbAvail),
            recoveryDeeplinkRaw: nil,
            inAppInstallable: false,
            blocking: true
        )
    }

    // MARK: - TTS voices (F1)

    /// Detects whether at least one voice for the given BCP-47 language is
    /// installed at `.enhanced` or `.premium` quality. `default` quality
    /// fallback sounds robotic in this project's 단정한 평어체 tone and is
    /// treated as "missing" for UX purposes.
    private static func checkVoice(language: String, kind: PreflightCheck.Kind) async -> PreflightCheck {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        let hasUsable = voices.contains { $0.quality == .enhanced || $0.quality == .premium }
        let displayName = language == "ko-KR" ? "한국어 음성 (Yuna 권장)" : "영어 음성 (Samantha 권장)"
        return PreflightCheck(
            kind: kind,
            passed: hasUsable,
            userMessage: hasUsable ? nil : "\(displayName) — 고품질 다운로드 필요",
            recoveryDeeplinkRaw: "x-apple.systempreferences:com.apple.preference.universalaccess?SpokenContent",
            inAppInstallable: false,  // Apple exposes no programmatic install for AVSpeechSynthesisVoice
            blocking: true
        )
    }

    // MARK: - STT assets (F2)

    /// Detects whether on-device speech recognition for the given locale is
    /// available. Uses `SFSpeechRecognizer.supportsOnDeviceRecognition`,
    /// which returns `true` once the OS-level speech model for the locale
    /// is installed — the same asset that `AssetInventory` (macOS 26)
    /// downloads. The two share the underlying on-device assets.
    private static func checkSTT(localeId: String, kind: PreflightCheck.Kind) async -> PreflightCheck {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        let ok = recognizer?.supportsOnDeviceRecognition == true
        let displayName = localeId == "ko-KR" ? "한국어 음성 인식" : "영어 음성 인식"
        return PreflightCheck(
            kind: kind,
            passed: ok,
            userMessage: ok ? nil : "\(displayName) — 자료 다운로드 필요 (~70 MB)",
            recoveryDeeplinkRaw: "x-apple.systempreferences:com.apple.preference.speech?Dictation",
            inAppInstallable: true,  // AssetInventory (macOS 26) handles install
            blocking: true
        )
    }

    /// Bilingual STT asset installation via macOS 26's `AssetInventory`.
    /// Both ko_KR and en_US assets are requested in a single
    /// `AssetInstallationRequest` so the user sees one Progress bar instead
    /// of two sequential downloads.
    ///
    /// `progressUpdate` is invoked as the underlying `Progress` advances;
    /// callers should treat it as a 0..1 fraction suitable for binding to a
    /// SwiftUI `ProgressView(value:)`.
    ///
    /// Throws on download/install error. Returns silently when no install
    /// is needed (assets already present on-device).
    public static func installSTTAssetsBilingual(
        progressUpdate: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        let ko = SpeechTranscriber(
            locale: Locale(identifier: "ko-KR"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let en = SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [ko, en])
        else {
            // Nothing to install — assets are already present on-device.
            progressUpdate(1.0)
            return
        }

        // Observe `Foundation.Progress.fractionCompleted` via NSKeyValueObservation.
        // The change handler runs on whatever thread KVO chooses (typically
        // the queue that mutated the Progress); the @Sendable callback +
        // explicit `Task { @MainActor }` in the host bounce keeps this
        // Swift-6-strict-concurrency-clean.
        let observer = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) {
            progress, _ in
            progressUpdate(progress.fractionCompleted)
        }
        defer { observer.invalidate() }

        try await request.downloadAndInstall()
        progressUpdate(1.0)
    }

    // MARK: - TCC permissions (F4 / F5 — informational only at preflight)

    /// Reports the current microphone authorization status. The check is
    /// always non-blocking: per Apple HIG we defer the actual TCC prompt to
    /// the first Spacebar press. This row is shown in the preflight table
    /// for transparency only and never gates the "시작하기" button.
    private static func checkMicrophonePermission() -> PreflightCheck {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let granted = status == .authorized
        let pending = status == .notDetermined
        let userMessage: String?
        if granted {
            userMessage = nil
        } else if pending {
            userMessage = "처음 말할 때 한 번 묻는다."
        } else {
            userMessage = "마이크 권한이 거부되어 있다 — 시스템 설정에서 허용 필요."
        }
        return PreflightCheck(
            kind: .microphonePermission,
            passed: granted || pending,  // pending → not blocking, will ask later
            userMessage: userMessage,
            recoveryDeeplinkRaw: granted || pending
                ? nil
                : "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            inAppInstallable: false,
            blocking: false  // Always non-blocking — first Spacebar handles it.
        )
    }

    private static func checkSpeechPermission() -> PreflightCheck {
        let status = SFSpeechRecognizer.authorizationStatus()
        let granted = status == .authorized
        let pending = status == .notDetermined
        let userMessage: String?
        if granted {
            userMessage = nil
        } else if pending {
            userMessage = "처음 말할 때 한 번 묻는다."
        } else {
            userMessage = "음성 인식 권한이 거부되어 있다 — 시스템 설정에서 허용 필요."
        }
        return PreflightCheck(
            kind: .speechPermission,
            passed: granted || pending,
            userMessage: userMessage,
            recoveryDeeplinkRaw: granted || pending
                ? nil
                : "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition",
            inAppInstallable: false,
            blocking: false
        )
    }
}

extension PreflightCheck.Kind {
    /// Human-readable Korean label for the preflight table row.
    public var displayName: String {
        switch self {
        case .macOSVersion: return "macOS 버전"
        case .appleSilicon: return "Apple Silicon"
        case .diskSpace: return "디스크 여유"
        case .koreanVoice: return "한국어 음성 (Yuna)"
        case .englishVoice: return "영어 음성 (Samantha)"
        case .koreanSTT: return "한국어 음성 인식"
        case .englishSTT: return "영어 음성 인식"
        case .microphonePermission: return "마이크 권한"
        case .speechPermission: return "음성 인식 권한"
        }
    }
}
