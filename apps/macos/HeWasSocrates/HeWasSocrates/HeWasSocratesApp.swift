import SwiftUI
import SocraticEngine

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
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.title = "He Was Socrates"
            // Defer toggleFullScreen to next runloop tick so SwiftUI scene is ready.
            DispatchQueue.main.async {
                window.toggleFullScreen(nil)
            }
        }
        NSApp.presentationOptions.insert(.autoHideMenuBar)
        NSApp.presentationOptions.insert(.autoHideDock)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
