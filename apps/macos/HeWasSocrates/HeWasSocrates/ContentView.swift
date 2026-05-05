import SwiftUI
import SocraticEngine

/// Root view of the He Was Socrates fullscreen experience.
/// Phase 1 skeleton: ink-black bg + placeholder REST viseme. Phase 3 wires
/// in audio + caption + thought-silhouette + mode-chip + offline-proof badge.
struct ContentView: View {
    @State private var currentViseme: VisemeID = .REST
    @State private var didDismissEsc: Bool = false

    var body: some View {
        ZStack {
            // background_ink_black per design-approved.json
            Color(red: 0.123, green: 0.115, blue: 0.184).ignoresSafeArea()

            BustView(viseme: currentViseme)

            VStack {
                Spacer()
                Text("He Was Socrates")
                    .font(.custom("Times New Roman", size: 18))
                    .foregroundColor(Color(white: 0.55))
                    .padding(.bottom, 36)
                    .accessibilityHidden(true)
            }
        }
        .background(KeyEventHandlerView { keyCode in
            // Esc keyCode = 53. Exit fullscreen → quit.
            if keyCode == 53 {
                NSApp.terminate(nil)
            }
            // Spacebar keyCode = 49 — Phase 3 will start STT push-to-talk.
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("He Was Socrates — a Socratic bust that asks questions")
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
                if let nsImage = loadVisemeImage(viseme) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    // Phase 1 fallback if PNGs not yet bundled in Resources.
                    Circle()
                        .fill(Color(red: 0.92, green: 0.87, blue: 0.77))
                        .frame(width: bustWidth * 0.6, height: bustHeight * 0.6)
                        .overlay(
                            Text("Phase 1 placeholder · viseme \(viseme.rawValue)")
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
        // Phase 1: try Bundle.main first (when Xcode bundles the PNGs from
        // Resources/visemes/). Falls back to nil → placeholder above.
        if let url = Bundle.main.url(forResource: id.resourceName, withExtension: "png", subdirectory: "visemes") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: id.resourceName, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

/// Bridge for AppKit key events into SwiftUI (since SwiftUI macOS lacks
/// global keyboard event capture for non-text views).
struct KeyEventHandlerView: NSViewRepresentable {
    let onKeyDown: (UInt16) -> Void

    func makeNSView(context: Context) -> KeyHandlerNSView {
        let view = KeyHandlerNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyHandlerNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

final class KeyHandlerNSView: NSView {
    var onKeyDown: ((UInt16) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode)
    }
}

#Preview {
    ContentView()
        .frame(width: 1280, height: 800)
}
