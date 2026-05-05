import SocraticEngine
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

            BustView(viseme: vm.currentViseme)

            VStack {
                Spacer()
                StatusOverlay(
                    phase: vm.phase,
                    partialTranscript: vm.partialTranscript,
                    loadProgress: vm.loadProgress
                )
                .padding(.bottom, 24)

                Text("He Was Socrates")
                    .font(.custom("Times New Roman", size: 18))
                    .foregroundColor(Color(white: 0.55))
                    .padding(.bottom, 36)
                    .accessibilityHidden(true)
            }
        }
        .background(
            KeyEventHandlerView(
                onKeyDown: { keyCode in handleKeyDown(keyCode) },
                onKeyUp: { keyCode in handleKeyUp(keyCode) }
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("He Was Socrates — a Socratic bust that asks questions")
        .task { await vm.bootstrap() }
    }

    private func handleKeyDown(_ keyCode: UInt16) {
        switch keyCode {
        case 53:  // Esc — exit fullscreen → quit
            NSApp.terminate(nil)
        case 49:  // Spacebar — push-to-talk press
            guard !spaceIsDown else { return }
            spaceIsDown = true
            vm.beginListening()
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
    private var loadProgressPoll: Task<Void, Never>?

    @Published var phase: EngineCoordinator.Phase = .bootstrapping
    @Published var currentViseme: VisemeID = .REST
    @Published var partialTranscript: String = ""
    @Published var caption: String = ""
    @Published var loadProgress: Double = 0

    init(gemmaMode: GemmaService.RuntimeMode = SocraticAppViewModel.defaultGemmaMode()) {
        self.coordinator = EngineCoordinator(gemmaMode: gemmaMode)
        wire()
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

        loadProgressPoll = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let state = await self.coordinator.gemma.loadState
                switch state {
                case .loading(let p):
                    self.loadProgress = p
                case .ready:
                    self.loadProgress = 1.0
                    return
                case .failed:
                    return
                case .unloaded:
                    break
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        await coordinator.bootstrap()
        loadProgressPoll?.cancel()
    }

    func beginListening() {
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
/// a determinate progress bar while Gemma weights are downloading.
struct StatusOverlay: View {
    let phase: EngineCoordinator.Phase
    let partialTranscript: String
    let loadProgress: Double

    var body: some View {
        Group {
            switch phase {
            case .bootstrapping:
                VStack(spacing: 6) {
                    Text(loadingLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.55))
                    ProgressView(value: loadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 360)
                        .tint(Color(white: 0.85))
                }
                .accessibilityLabel("Loading Gemma 4 model: \(Int(loadProgress * 100)) percent")

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

            case .failed(let msg):
                Text("⚠︎ \(msg)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
        }
    }

    private var loadingLabel: String {
        if loadProgress > 0 {
            return "Gemma 4 E4B 4-bit · \(Int(loadProgress * 100))%"
        }
        return "Gemma 4 E4B 4-bit · 준비 중"
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
            .accessibilityLabel("Socrates bust, currently in viseme \(viseme.rawValue)")
        }
    }

    private func loadVisemeImage(_ id: VisemeID) -> NSImage? {
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

#Preview {
    ContentView()
        .frame(width: 1280, height: 800)
}
