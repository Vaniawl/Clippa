import AppKit
import SwiftUI

@main
struct ClippaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Clippa", systemImage: "paperclip") {
            MenuBarContentView(appState: appDelegate.appState)
        }
    }
}

private struct MenuBarContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        if !appState.isAutoPasteReady {
            Button {
                AccessibilityService.openSystemSettings()
            } label: {
                Label("Auto-Paste Needs Access", systemImage: "accessibility")
            }
            Divider()
        }

        if appState.canUndoHistoryAction {
            Button {
                appState.undoLastHistoryAction()
            } label: {
                Label("Undo History Change", systemImage: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: .command)
            Divider()
        }

        Button {
            appState.showSettings()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button {
            appState.quit()
        } label: {
            Label("Quit Clippa", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.refreshAccessibilityState()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        appState.monitor.stop()
        appState.hotKeyService.unregister()
        return .terminateNow
    }
}
