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
        if appState.settings.isCapturePaused {
            Button {
                appState.settings.resumeCapture()
            } label: {
                Label(appState.settings.capturePauseDescription, systemImage: "pause.circle.fill")
            }
            Divider()
        } else {
            Menu {
                Button("15 Minutes") {
                    appState.settings.pauseCapture(for: 15 * 60)
                }
                Button("1 Hour") {
                    appState.settings.pauseCapture(for: 60 * 60)
                }
                Button("Until Tomorrow") {
                    appState.settings.pauseCapture(for: 24 * 60 * 60)
                }
            } label: {
                Label("Pause History", systemImage: "pause.circle")
            }
            Divider()
        }

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
            Task {
                await appState.store.synchronize()
            }
        } label: {
            Label(appState.store.syncState.title, systemImage: appState.store.syncState.symbolName)
        }
        .disabled(appState.store.syncState.isSyncing)

        Divider()

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
    private var terminationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.refreshAccessibilityState()
        appState.requestAutomaticCloudSync()
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        appState.requestAutomaticCloudSync()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationTask == nil else {
            return .terminateLater
        }
        terminationTask = Task { [weak self, weak sender] in
            guard let self else {
                sender?.reply(toApplicationShouldTerminate: true)
                return
            }
            await appState.prepareForTermination()
            sender?.reply(toApplicationShouldTerminate: true)
            terminationTask = nil
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopImmediately()
    }
}
