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
        Button {
            appState.togglePanelFromShortcut()
        } label: {
            Label("Open History", systemImage: "clock.arrow.circlepath")
        }
        Divider()

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
    private var isPreparingToTerminate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.refreshAccessibilityState()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isPreparingToTerminate else {
            return .terminateLater
        }
        isPreparingToTerminate = true
        appState.monitor.stop()
        appState.hotKeyService.unregister()
        Task {
            do {
                try await appState.store.flushPendingSave()
                sender.reply(toApplicationShouldTerminate: true)
            } catch {
                isPreparingToTerminate = false
                appState.monitor.start()
                appState.registerShowPanelShortcut()
                sender.reply(toApplicationShouldTerminate: false)

                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String(localized: "Clippa Could Not Save History")
                alert.informativeText = String(localized: "Clippa is still running so you can retry without losing the latest clipboard changes.")
                alert.runModal()
            }
        }
        return .terminateLater
    }
}
