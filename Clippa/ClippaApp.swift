import AppKit
import SwiftUI

@main
struct ClippaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Clippa", systemImage: "paperclip") {
            Button("Quit") {
                appDelegate.appState.quit()
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        appState.monitor.stop()
        appState.hotKeyService.unregister()
        return .terminateNow
    }
}
