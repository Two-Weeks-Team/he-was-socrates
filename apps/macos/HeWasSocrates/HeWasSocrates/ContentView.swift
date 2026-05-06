import AVFoundation
import AppKit
import SocraticEngine
import Speech
import SwiftUI

/// Root view of the He Was Socrates fullscreen experience.
///
/// Wires the entire turn loop end-to-end:
///   Spacebar push-to-talk → AudioInputManager (on-device SFSpeechRecognizer)
///     → FunctionCallOrchestrator → GemmaService(.real, gemma-4-e4b-it-4bit)
///     → TTSManager (Yuna ko / Samantha en)
///     → VisemeDriver (30 fps frame swap, 16 visemes)
///
/// First launch downloads the Gemma 4 E4B 4-bit weights (~3.97 GB) into
/// `~/Library/Caches/com.apple.MLX/...`. Progress is surfaced as a status
/// overlay; subsequent launches reuse the cached weights.
struct ContentView: View {
    @StateObject private var vm = SocraticAppViewModel()
    @State private var spaceIsDown: Bool = false

    var body: some View {
        ZStack {
            // background_ink_black per design-approved.json
            Color(red: 0.123, green: 0.115, blue: 0.184).ignoresSafeArea()

            // Iter-6: pre-flight gate. When the eight-check pre-flight has
            // any blocking failure (missing Korean voice, missing English
            // voice, missing STT asset, etc.) the user sees a structured
            // setup screen instead of the bust + a fail-after-the-fact
            // error mid-turn. Once everything resolves the bust appears.
            switch vm.preflightStatus {
            case .blocked(let checks):
                PreflightView(
                    checks: checks,
                    isInstalling: vm.assetInstallActive,
                    installProgress: vm.assetInstallProgress,
                    onAction: { check in
                        Task { await vm.handlePreflightAction(check) }
                    },
                    onRecheck: { Task { await vm.recheckPreflight() } }
                )
            default:
                bustContent
            }
        }
        .background(
            KeyEventHandlerView(
                onKeyDown: { keyCode in handleKeyDown(keyCode) },
                onKeyUp: { keyCode in handleKeyUp(keyCode) }
            )
        )
        .accessibilityElement(children: .contain)
        // PR-δ: phase-driven VoiceOver label. Updates only on phase
        // transitions (handful per turn), not on viseme swaps (30 fps).
        .accessibilityLabel("He Was Socrates · \(FailedMessage.voiceOverLabel(for: vm.phase))")
        .task { await vm.bootstrap() }
        .sheet(isPresented: $vm.permissionExplainerVisible) {
            PermissionExplainerView(
                onAllow: { Task { await vm.grantPermissionsAfterExplainer() } },
                onDismiss: { vm.dismissPermissionExplainer() }
            )
        }
    }

    private var bustContent: some View {
        ZStack {
            BustView(viseme: vm.currentViseme)

            VStack {
                Spacer()
                StatusOverlay(
                    phase: vm.phase,
                    partialTranscript: vm.partialTranscript,
                    loadProgress: vm.loadProgress,
                    bootstrapStage: vm.bootstrapStage
                )
                .padding(.bottom, 24)

                Text("He Was Socrates")
                    .font(.custom("Times New Roman", size: 18))
                    .foregroundColor(Color(white: 0.55))
                    .padding(.bottom, 36)
                    .accessibilityHidden(true)
            }
        }
    }

    private func handleKeyDown(_ keyCode: UInt16) {
        switch keyCode {
        case 53:  // Esc — exit fullscreen → quit
            NSApp.terminate(nil)
        case 49:  // Spacebar — push-to-talk press
            guard !spaceIsDown else { return }
            spaceIsDown = true
            vm.attemptBeginListening()
        default:
            break
        }
    }

    private func handleKeyUp(_ keyCode: UInt16) {
        if keyCode == 49 && spaceIsDown {
            spaceIsDown = false
            vm.endListening()
        }
    }
}

// MARK: - ViewModel

/// Bridges `EngineCoordinator` (an @MainActor type with closure callbacks)
/// to SwiftUI's `@Published` reactive surface.
@MainActor
final class SocraticAppViewModel: ObservableObject {
    private let coordinator: EngineCoordinator
    private var bootstrapStarted: Bool = false
    private var modelLoadStarted: Bool = false
    private var loadProgressPoll: Task<Void, Never>?
    /// Workspace activation observer for the F1/F2 deeplink return-polling
    /// flow. `nonisolated(unsafe)` because Swift 6 strict-concurrency
    /// declares the implicit `deinit` nonisolated, but the property is
    /// MainActor-isolated by default — we need cross-isolation read access.
    /// Safe in practice: the property is only written once (in `init`) and
    /// read once (in `deinit`); `removeObserver` is thread-safe per Apple
    /// NotificationCenter documentation.
    nonisolated(unsafe) private var workspaceObserver: NSObjectProtocol?
    private var permissionsRequested: Bool = false

    @Published var phase: EngineCoordinator.Phase = .bootstrapping
    @Published var currentViseme: VisemeID = .REST
    @Published var partialTranscript: String = ""
    @Published var caption: String = ""
    @Published var loadProgress: Double = 0

    // MARK: - iter-6 first-launch UX

    public enum PreflightStatus: Equatable {
        case idle
        case running
        case allReady
        case blocked(checks: [PreflightCheck])
    }

    /// Drives the top-level branch in `ContentView.body` — when `.blocked`,
    /// the bust is hidden and `PreflightView` takes the full screen until
    /// the user resolves missing items.
    @Published var preflightStatus: PreflightStatus = .idle

    /// Sheet visibility for the in-context permission explainer (F4 / F5).
    /// Driven by `attemptBeginListening()` on the first Spacebar press
    /// when one or both TCC permissions are still `.notDetermined`.
    @Published var permissionExplainerVisible: Bool = false

    /// AssetInventory bilingual STT-asset download progress (0..1). Bound
    /// to a determinate `ProgressView(value:)` inside `PreflightView`.
    @Published var assetInstallProgress: Double = 0

    /// `true` while a `PreflightRunner.installSTTAssetsBilingual` task is
    /// active. Disables the per-row install buttons + recheck button while
    /// the download runs.
    @Published var assetInstallActive: Bool = false

    /// Phase-aware bootstrap label per Apple HIG:
    /// > "Include a label above an activity indicator … avoid vague terms like
    /// > loading or authenticating because they don't usually add any value …
    /// > only use progress bars for tasks that are quantifiable."
    /// (developer.apple.com/design/human-interface-guidelines)
    ///
    /// Drives StatusOverlay's `.bootstrapping` rendering. Set by
    /// `loadProgressPoll` from `GemmaService.LoadState` plus a manual
    /// `.warmingUp` transition once `.ready` is observed but the
    /// coordinator is still inside `gemma.warmup()`.
    @Published var bootstrapStage: BootstrapStage = .loadingIntoMemory

    public enum BootstrapStage: String, Equatable, Sendable {
        case downloadingWeights
        case loadingIntoMemory
        case warmingUp

        public var displayLabel: String {
            switch self {
            case .downloadingWeights: return "Gemma 4 모델 다운로드 중"
            case .loadingIntoMemory: return "모델 메모리에 올리는 중"
            case .warmingUp: return "흉상 깨우는 중"
            }
        }
    }

    init(gemmaMode: GemmaService.RuntimeMode = SocraticAppViewModel.defaultGemmaMode()) {
        self.coordinator = EngineCoordinator(gemmaMode: gemmaMode)
        wire()
        registerWorkspaceObserver()
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    /// Iter-6 / F1: when the user comes back from System Settings (which
    /// they'd reach via the per-row deeplink), automatically re-run the
    /// pre-flight so newly-installed voices / STT assets are picked up
    /// without an explicit "다시 점검" tap. Only fires when the current
    /// state is `.blocked` — irrelevant once we're past pre-flight.
    private func registerWorkspaceObserver() {
        let bundleId = Bundle.main.bundleIdentifier
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                let bundleId,
                app.bundleIdentifier == bundleId
            else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .blocked = self.preflightStatus, !self.assetInstallActive {
                    await self.recheckPreflight()
                }
            }
        }
    }

    /// Honors `HEWASSOCRATES_GEMMA_MODE=stub` for headless / smoke runs.
    /// Defaults to `.real` so a fresh install on any Mac runs the full
    /// on-device Gemma 4 E4B 4-bit path.
    static func defaultGemmaMode() -> GemmaService.RuntimeMode {
        if let v = ProcessInfo.processInfo.environment["HEWASSOCRATES_GEMMA_MODE"],
            v.lowercased() == "stub"
        {
            return .stub
        }
        return .real
    }

    private func wire() {
        coordinator.onPhaseChanged = { [weak self] newPhase in
            self?.phase = newPhase
        }
        coordinator.onPartialTranscript = { [weak self] partial in
            self?.partialTranscript = partial
        }
        coordinator.onCaptionUpdate = { [weak self] text in
            self?.caption = text
        }
        coordinator.viseme.onVisemeChanged = { [weak self] visemeID in
            Task { @MainActor [weak self] in
                self?.currentViseme = visemeID
            }
        }
    }

    func bootstrap() async {
        guard !bootstrapStarted else { return }
        bootstrapStarted = true

        // PR-γ: warm the viseme image cache once at bootstrap so the
        // 30 fps swap path never pays a Bundle.main.url + PNG decode.
        VisemeImageCache.preloadAll()

        // Apply system Reduce Motion at bootstrap. VisemeDriver runs the
        // §7.6 Tier-3 talking cue (500 ms square wave) instead of phoneme-
        // driven swaps when this is on. Re-evaluating on every utterance
        // would be churn; users typically toggle this rarely.
        coordinator.viseme.setReduceMotion(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )

        // Iter-6 first-launch UX: pre-flight comes BEFORE model load. If
        // any blocking item (Korean voice, English voice, STT asset, …) is
        // missing, we stay in `.blocked` until the user resolves it via
        // deeplink or in-app installer. Only when everything is ready do
        // we proceed to the (expensive) Gemma load + warmup path.
        await runPreflight()
        if case .blocked = preflightStatus { return }
        await proceedToModelLoad()
    }

    /// Re-run pre-flight (called when the user taps "다시 점검" or returns
    /// from System Settings via the workspace activation observer). If
    /// everything resolves, proceed to model load on the same call so the
    /// user doesn't have to manually trigger another step.
    func recheckPreflight() async {
        guard !assetInstallActive else { return }
        await runPreflight()
        if case .allReady = preflightStatus, !modelLoadStarted {
            await proceedToModelLoad()
        }
    }

    private func runPreflight() async {
        preflightStatus = .running
        let checks = await PreflightRunner.runAll()
        let blocking = checks.filter { $0.blocking && !$0.passed }
        preflightStatus = blocking.isEmpty ? .allReady : .blocked(checks: checks)
    }

    /// Decoupled from `bootstrap()` so we can also call it from
    /// `recheckPreflight()` once preflight clears mid-session. Guarded by
    /// `modelLoadStarted` so it cannot run twice. Calls
    /// `coordinator.bootstrap(skipPermissions: true)` because permissions
    /// are now requested in-context at the first Spacebar press, not at
    /// bootstrap (Apple HIG Privacy guidance).
    private func proceedToModelLoad() async {
        guard !modelLoadStarted else { return }
        modelLoadStarted = true

        loadProgressPoll = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let state = await self.coordinator.gemma.loadState
                switch state {
                case .loading(let p):
                    self.loadProgress = p
                    // Below ~95% → user is still observing transfer-driven
                    // motion (HF chunks / cache reads). At 95–100% the bar
                    // pauses while MLX runs final tokenizer + weight wiring,
                    // which feels frozen unless we relabel it.
                    self.bootstrapStage = p < 0.95 ? .downloadingWeights : .loadingIntoMemory
                case .ready:
                    self.loadProgress = 1.0
                    // Model is in memory but coordinator.bootstrap() is now
                    // running gemma.warmup() (~5 s the first launch, near-
                    // instant on subsequent ones thanks to the disk-mediated
                    // KV cache from PR-Λ). Surface that as a distinct stage
                    // so the user doesn't watch a frozen 100 % bar.
                    self.bootstrapStage = .warmingUp
                    return
                case .failed:
                    return
                case .unloaded:
                    break
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        await coordinator.bootstrap(skipPermissions: true)
        loadProgressPoll?.cancel()
    }

    // MARK: - Pre-flight per-row actions (F1 deeplink / F2 in-app install)

    func handlePreflightAction(_ check: PreflightCheck) async {
        if check.inAppInstallable {
            await installSTTAssetsBilingual()
        } else if let url = check.recoveryDeeplink {
            // F1 / F4 / F5: open the relevant System Settings pane. The
            // workspace activation observer (registerWorkspaceObserver)
            // re-runs pre-flight when the user comes back, so they don't
            // need to manually tap "다시 점검".
            NSWorkspace.shared.open(url)
        }
    }

    /// F2 — bilingual STT asset install via macOS 26 AssetInventory.
    /// Both ko-KR and en-US assets are requested in a single
    /// `assetInstallationRequest(supporting: [ko, en])` so the user sees
    /// one Progress bar instead of two sequential downloads. After
    /// completion we re-run pre-flight to verify, then proceed if ready.
    private func installSTTAssetsBilingual() async {
        guard !assetInstallActive else { return }
        assetInstallActive = true
        assetInstallProgress = 0
        defer { assetInstallActive = false }

        do {
            try await PreflightRunner.installSTTAssetsBilingual { [weak self] fraction in
                Task { @MainActor [weak self] in
                    self?.assetInstallProgress = fraction
                }
            }
        } catch {
            // Surface as a phase failure so the user gets the same recovery
            // surface as any other STT issue. The deeplink fallback in the
            // pre-flight row remains visible if AssetInventory itself fails.
            phase = .failed(PhaseFailureKey.sttOnDeviceUnsupported)
        }

        await recheckPreflight()
    }

    // MARK: - First-Spacebar permission flow (F4 / F5)

    /// Called from `handleKeyDown` on the first Spacebar press. Per Apple
    /// HIG Privacy: "context-related permission requests are less likely
    /// to cause surprise" — we show our own SwiftUI explainer first when
    /// either TCC permission is still `.notDetermined`, so the user
    /// understands *why* they're about to see the system alert. Once both
    /// are authorized, subsequent Spacebar presses go straight to listen.
    func attemptBeginListening() {
        if !permissionsRequested && needsPermissionPrompt() {
            permissionExplainerVisible = true
            return
        }
        beginListening()
    }

    private func needsPermissionPrompt() -> Bool {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        let speech = SFSpeechRecognizer.authorizationStatus()
        // notDetermined means the system has never asked → we should show
        // our explainer + then trigger TCC. denied/restricted are handled
        // via the failure surface, not the explainer.
        return mic == .notDetermined || speech == .notDetermined
    }

    /// Triggered when the user taps [허용] on the explainer sheet. Runs
    /// the actual TCC requests (mic first, then speech) via the existing
    /// `coordinator.audio.requestPermissions()` path, then dismisses the
    /// sheet. Does NOT auto-start listening — the user typically released
    /// Space when the sheet appeared, so they should press it again.
    func grantPermissionsAfterExplainer() async {
        let result = await coordinator.audio.requestPermissions()
        permissionsRequested = true
        permissionExplainerVisible = false
        switch result {
        case .granted:
            // Stay idle — let the user press Space again to record. Auto-
            // starting from this callback would race the user's Space
            // key-up event and start a phantom recording.
            break
        case .denied(let reason):
            let key =
                reason == "microphone"
                ? PhaseFailureKey.micDenied : PhaseFailureKey.speechRecognitionDenied
            phase = .failed(key)
        case .restricted:
            phase = .failed(PhaseFailureKey.speechRecognitionRestricted)
        case .notDetermined:
            // Shouldn't happen — the system always reports a final state
            // after `requestRecordPermission` / `requestAuthorization`.
            break
        }
    }

    func dismissPermissionExplainer() {
        permissionExplainerVisible = false
        // Don't set permissionsRequested — user can press Space to retry.
    }

    func beginListening() {
        // iter-6 fix: clear the previous turn's partial transcript before
        // the new STT session emits its first result. Without this the
        // StatusOverlay's `.listening` case (Text(partialTranscript))
        // briefly flashes the previous user utterance during the ~500 ms
        // gap between phase entry and the first SFSpeechRecognizer
        // partial — surprising the user and making the bust feel like
        // it didn't reset between turns. The engine layer's
        // AudioInputManager already clears its own `lastPartialTranscript`
        // at startListening; this mirrors it at the ViewModel layer
        // where the SwiftUI binding actually lives.
        partialTranscript = ""
        do {
            try coordinator.beginListening()
        } catch {
            phase = .failed("listen: \(error.localizedDescription)")
        }
    }

    func endListening() {
        coordinator.endListening()
    }
}

// MARK: - Status overlay

/// Renders a single line below the bust matching the current `Phase`. Plus
/// a phase-aware bootstrap label (PR-T1.3 / iter-6) and either a determinate
/// progress bar (download / load-into-memory) or an indeterminate spinner
/// (warmup — model in memory, no quantifiable progress source).
struct StatusOverlay: View {
    let phase: EngineCoordinator.Phase
    let partialTranscript: String
    let loadProgress: Double
    let bootstrapStage: SocraticAppViewModel.BootstrapStage

    var body: some View {
        Group {
            switch phase {
            case .bootstrapping:
                VStack(spacing: 8) {
                    Text(bootstrapStage.displayLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                    if bootstrapStage == .warmingUp {
                        // Apple HIG: "only use progress bars for tasks that are
                        // quantifiable." Warmup has no progress source, so we
                        // surface activity with an indeterminate spinner +
                        // phase label rather than a misleading frozen 100% bar.
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    } else {
                        VStack(spacing: 4) {
                            ProgressView(value: loadProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 360)
                                .tint(Color(white: 0.85))
                            Text("\(Int(loadProgress * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.45))
                        }
                    }
                }
                .accessibilityLabel("\(bootstrapStage.displayLabel) \(Int(loadProgress * 100)) percent")

            case .idle:
                Text("Press Space — 누르고 말하라")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))

            case .listening:
                Text(partialTranscript.isEmpty ? "Listening…" : partialTranscript)
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)

            case .thinking:
                Text("Thinking…")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))

            case .surfacing:
                Text("Recalling past wonders…")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))

            case .speaking(let reply, let deferred):
                Text((deferred ? "⊘ " : "") + reply)
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)

            case .failed(let key):
                VStack(spacing: 6) {
                    Text("⚠︎ \(FailedMessage.title(for: key))")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.45))
                    if let recovery = FailedMessage.recovery(for: key) {
                        Text(recovery)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.55))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 80)
            }
        }
    }

}

// MARK: - Failure-key localization (PR-δ)

/// Maps `PhaseFailureKey` strings (carried in `Phase.failed(String)`) to
/// localized title + optional recovery hint shown in the StatusOverlay.
/// Keeping the lookup in the SwiftUI layer means the engine layer
/// remains free of UI strings, and adding a new locale is a single-file
/// edit. Rendered in 단정한 평어체 per the locked Korean voice.
enum FailedMessage {
    static func title(for key: String) -> String {
        switch key {
        case PhaseFailureKey.micDenied:
            return "마이크 권한이 없다"
        case PhaseFailureKey.speechRecognitionDenied:
            return "음성 인식 권한이 없다"
        case PhaseFailureKey.speechRecognitionRestricted:
            return "음성 인식이 제한되어 있다"
        case PhaseFailureKey.audioRuntimeError:
            return "오디오 입력 오류"
        case PhaseFailureKey.sttOnDeviceUnsupported:
            return "기기 내 음성 인식이 지원되지 않는다"
        case PhaseFailureKey.audioInterrupted:
            return "오디오가 다른 앱에 의해 중단되었다"
        case PhaseFailureKey.gemmaLoadFailed:
            return "Gemma 4 모델을 불러오지 못했다"
        case PhaseFailureKey.modelMalformedOutput:
            return "모델 응답을 해석할 수 없다"
        case PhaseFailureKey.orchestratorError:
            return "추론 중 오류가 발생했다"
        case PhaseFailureKey.ttsVoiceMissing:
            return "음성을 찾을 수 없다"
        case PhaseFailureKey.ttsRuntimeError:
            return "음성 합성 중 오류"
        case PhaseFailureKey.bootstrapTimeout:
            return "초기화가 시간 안에 끝나지 않았다"
        case PhaseFailureKey.turnTimeout:
            return "응답이 시간 안에 끝나지 않았다"
        default:
            // Unknown key — surface the raw string so a developer can
            // diagnose, but prefix it with the same warning ideogram so
            // the user still gets a consistent visual cue.
            return key
        }
    }

    static func recovery(for key: String) -> String? {
        switch key {
        case PhaseFailureKey.micDenied:
            return "시스템 설정 → 개인 정보 보호 및 보안 → 마이크에서 허용하라."
        case PhaseFailureKey.speechRecognitionDenied:
            return "시스템 설정 → 개인 정보 보호 및 보안 → 음성 인식에서 허용하라."
        case PhaseFailureKey.speechRecognitionRestricted:
            return "기기 관리자에 의해 제한되어 있다. 정책을 확인하라."
        case PhaseFailureKey.gemmaLoadFailed:
            return "터미널에서 `make install-gemma-weights`를 다시 실행하라."
        case PhaseFailureKey.bootstrapTimeout:
            return "잠시 뒤 다시 시도하라. 그래도 멈추면 앱을 다시 실행하라."
        case PhaseFailureKey.sttOnDeviceUnsupported:
            return "시스템 설정 → 키보드 → 받아쓰기 → 언어에서\n한국어와 영어를 모두 추가하라."
        case PhaseFailureKey.ttsVoiceMissing:
            return "시스템 설정 → 손쉬운 사용 → 음성 콘텐츠 → 시스템 음성에서\n한국어(Yuna)와 영어(Samantha) 모두 고품질로 다운로드하라."
        case PhaseFailureKey.audioInterrupted:
            return "다른 오디오 앱을 닫고 Spacebar로 다시 시도하라."
        case PhaseFailureKey.turnTimeout:
            return "Spacebar를 다시 눌러 새로 묻어라."
        default:
            return nil
        }
    }

    /// Phase-level VoiceOver label. Replaces the per-viseme spam (30 fps)
    /// with a single human-readable phase string. Closes finding N (RCA
    /// + Critic agreed: announcing every viseme swap is unusable for
    /// VoiceOver users).
    static func voiceOverLabel(for phase: EngineCoordinator.Phase) -> String {
        switch phase {
        case .bootstrapping: return "준비 중"
        case .idle: return "대기 중. Spacebar를 눌러 말하라."
        case .listening: return "듣는 중"
        case .thinking: return "생각 중"
        case .surfacing: return "지난 호기심 떠올리는 중"
        case .speaking(let reply, _): return "응답: \(reply)"
        case .failed(let key): return "오류: \(title(for: key))"
        }
    }
}

// MARK: - Bust view (viseme PNG swap)

/// PR-γ: process-wide viseme image cache. Previous implementation paid a
/// `Bundle.main.url(forResource:...)` lookup + `NSImage(contentsOf:)` PNG
/// decode on EVERY frame swap (30 fps), measuring ~1–3 ms per swap. The
/// 16 viseme PNGs are immutable across the app's lifetime, so we preload
/// them once and cache by id. Swap cost drops to a dictionary lookup.
private enum VisemeImageCache {
    nonisolated(unsafe) private static var cache: [VisemeID: NSImage] = [:]

    static func image(for id: VisemeID) -> NSImage? {
        if let cached = cache[id] { return cached }
        guard let img = loadFromBundle(id) else { return nil }
        cache[id] = img
        return img
    }

    static func preloadAll() {
        for id in VisemeID.allCases {
            if cache[id] == nil, let img = loadFromBundle(id) {
                cache[id] = img
            }
        }
    }

    private static func loadFromBundle(_ id: VisemeID) -> NSImage? {
        if let url = Bundle.main.url(
            forResource: id.resourceName,
            withExtension: "png",
            subdirectory: "visemes"
        ) {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: id.resourceName, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

/// Renders the active viseme PNG centered on screen, scaled to ~52% height
/// per design-approved.json `layout.bust_screen_height_fraction`.
struct BustView: View {
    let viseme: VisemeID

    var body: some View {
        GeometryReader { proxy in
            let bustHeight = proxy.size.height * 0.52
            let bustWidth = bustHeight * 1.0  // 1024×1024 source aspect

            Group {
                if let nsImage = VisemeImageCache.image(for: viseme) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    // Fallback if PNGs aren't bundled (dev hot-reload edge case).
                    Circle()
                        .fill(Color(red: 0.92, green: 0.87, blue: 0.77))
                        .frame(width: bustWidth * 0.6, height: bustHeight * 0.6)
                        .overlay(
                            Text("missing viseme: \(viseme.rawValue)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.2))
                        )
                }
            }
            .frame(width: bustWidth, height: bustHeight)
            .position(x: proxy.size.width / 2, y: proxy.size.height * (0.50 - 0.05))
            // PR-δ: per-viseme accessibility label removed. Updating
            // accessibilityLabel at 30 fps queues a VoiceOver utterance
            // for every frame — unusable for VoiceOver users (finding
            // N + N-CRIT-9). The bust is now hidden from accessibility;
            // the live narration comes from the phase-driven label on
            // ContentView itself (see `accessibilityLabel(_:)` there).
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Key event handler

/// Bridge for AppKit key events into SwiftUI (since SwiftUI on macOS lacks
/// global keyboard event capture for non-text views, and we need both
/// keyDown AND keyUp to drive push-to-talk).
struct KeyEventHandlerView: NSViewRepresentable {
    let onKeyDown: (UInt16) -> Void
    let onKeyUp: (UInt16) -> Void

    func makeNSView(context: Context) -> KeyHandlerNSView {
        let view = KeyHandlerNSView()
        view.onKeyDown = onKeyDown
        view.onKeyUp = onKeyUp
        return view
    }

    func updateNSView(_ nsView: KeyHandlerNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onKeyUp = onKeyUp
    }
}

final class KeyHandlerNSView: NSView {
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        onKeyDown?(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event.keyCode)
    }
}

// MARK: - Pre-flight setup screen (iter-6)

/// Setup screen shown before the bust appears on first launch (or any
/// later launch where the user uninstalled a Korean voice / disabled
/// Korean dictation / etc.).
///
/// Renders the eight pre-flight checks as a simple list with per-row
/// action buttons:
///   - In-app installable items (STT assets) → "다운로드" runs
///     `AssetInventory.assetInstallationRequest(supporting: [ko, en])`
///     and shows a Progress bar.
///   - Deeplink items (TTS voice, denied permissions) → "시스템 설정" opens
///     the relevant pane via `x-apple.systempreferences:` URL. The
///     workspace activation observer auto-rechecks on return.
///   - Hard-stop items (macOS < 26, Intel) → message only, no action.
struct PreflightView: View {
    let checks: [PreflightCheck]
    let isInstalling: Bool
    let installProgress: Double
    let onAction: (PreflightCheck) -> Void
    let onRecheck: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 6) {
                Text("준비 상태")
                    .font(.custom("Times New Roman", size: 28))
                    .foregroundColor(Color(white: 0.85))
                Text("He Was Socrates를 시작하기 전에 확인해야 할 것")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.55))
            }

            VStack(spacing: 6) {
                ForEach(checks) { check in
                    PreflightRowView(
                        check: check,
                        isInstalling: isInstalling,
                        action: { onAction(check) }
                    )
                }
            }
            .frame(maxWidth: 640)

            if isInstalling {
                VStack(spacing: 6) {
                    Text(
                        "음성 인식 자료 다운로드 중 — \(Int(installProgress * 100))%"
                    )
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white: 0.7))
                    ProgressView(value: installProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 360)
                        .tint(Color(white: 0.85))
                }
                .padding(.top, 8)
            } else {
                Button("다시 점검") { onRecheck() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(Color(white: 0.85))
                    .foregroundColor(Color(red: 0.123, green: 0.115, blue: 0.184))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PreflightRowView: View {
    let check: PreflightCheck
    let isInstalling: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(statusGlyph)
                .font(.system(size: 14))
                .foregroundColor(statusColor)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.kind.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.85))
                if let msg = check.userMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.55))
                }
            }

            Spacer()

            if !check.passed && actionLabel != nil {
                Button(actionLabel ?? "") { action() }
                    .controlSize(.small)
                    .disabled(isInstalling)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.16).opacity(0.5))
        .cornerRadius(6)
    }

    private var statusGlyph: String {
        check.passed ? "✓" : (check.blocking ? "✗" : "—")
    }

    private var statusColor: Color {
        if check.passed { return Color(red: 0.4, green: 0.85, blue: 0.5) }
        return check.blocking
            ? Color(red: 0.95, green: 0.45, blue: 0.45) : Color(white: 0.55)
    }

    private var actionLabel: String? {
        if check.inAppInstallable { return "다운로드" }
        if check.recoveryDeeplink != nil { return "시스템 설정" }
        return nil
    }
}

// MARK: - Permission explainer sheet (F4 + F5)

/// In-context permission explainer per Apple HIG Privacy:
/// > "Context-related permission requests are less likely to cause surprise"
///
/// Shown the first time the user holds Spacebar while either TCC permission
/// is `.notDetermined`. A unified explanation covers BOTH mic and speech
/// recognition because the user's mental model is "the app wants to listen"
/// — splitting into two prompts without context surprises them mid-turn.
struct PermissionExplainerView: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("처음 한 번만 묻는다")
                    .font(.custom("Times New Roman", size: 22))
                Text("스페이스바를 누르면, 마이크와 음성 인식이 함께 동작해.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.55))
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "당신이 묻는 동안만 동작하고, 손을 떼면 멈춘다.",
                    systemImage: "mic"
                )
                Label(
                    "음성은 기기 안에서만 처리된다.",
                    systemImage: "lock.shield"
                )
                Label(
                    "0 byte의 데이터도 외부로 나가지 않는다.",
                    systemImage: "wifi.slash"
                )
            }
            .font(.system(size: 12))
            .foregroundColor(Color(white: 0.7))

            HStack(spacing: 12) {
                Button("나중에") { onDismiss() }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button("허용") { onAllow() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 420)
    }
}

#Preview {
    ContentView()
        .frame(width: 1280, height: 800)
}
