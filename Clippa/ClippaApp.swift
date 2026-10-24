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
            appState.panelController.show(appState: appState)
        } label: {
            Label("Show Clipboard History", systemImage: "doc.on.clipboard")
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
            appState.editTemplate()
        } label: {
            Label("New Template", systemImage: "text.badge.plus")
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
        // Unit tests own isolated stores and must not capture or overwrite real history.
        if NSClassFromString("XCTestCase") == nil { appState.start() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.refreshAccessibilityState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if appState.templateWindowController.activateIfVisible() { return false }
        if !flag { appState.panelController.show(appState: appState) }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        appState.monitor.stop()
        appState.hotKeyService.unregister()
        return .terminateNow
    }
}
