import SocraticEngine
import SwiftUI

@main
struct HeWasSocratesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                EmptyView()
            }
            CommandGroup(after: .appInfo) {
                Text("\(SocraticEngineInfo.bundleVersion)")
                    .accessibilityLabel("Engine version")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Guard so we only toggle fullscreen once. `applicationDidBecomeActive`
    /// fires whenever the user re-focuses the app, but we only want the
    /// initial entry — otherwise a Cmd-Tab back into the app would re-toggle
    /// and exit fullscreen.
    private var didEnterFullScreen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.presentationOptions.insert(.autoHideMenuBar)
        NSApp.presentationOptions.insert(.autoHideDock)
    }

    /// SwiftUI may not have created the window yet during
    /// `applicationDidFinishLaunching`, so we hook the next viable lifecycle
    /// event. `applicationDidBecomeActive` fires after the scene's window is
    /// installed and key.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !didEnterFullScreen else { return }
        guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.isVisible })
        else {
            return
        }
        didEnterFullScreen = true
        window.title = "He Was Socrates"
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
