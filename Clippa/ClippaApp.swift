import AppKit
import SwiftUI

@main
struct ClippaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Clippa", systemImage: "paperclip") {
            Button("Open Clippa") {
                appDelegate.appState.openAppWindow()
            }
            Button("Show History") {
                appDelegate.appState.togglePanel()
            }
            Button(appDelegate.appState.settings.isMonitoringPaused ? "Resume" : "Pause") {
                appDelegate.appState.settings.isMonitoringPaused.toggle()
            }
            Button("Clear Unpinned") {
                appDelegate.appState.store.clearUnpinned()
            }
            Divider()
            Button("Settings") {
                appDelegate.appState.openSettings()
            }
            Button("Quit") {
                appDelegate.appState.quit()
            }
        }
        Settings {
            SettingsView(
                settings: appDelegate.appState.settings,
                store: appDelegate.appState.store,
                hotKeyStatus: appDelegate.appState.hotKeyService.registrationStatus,
                onShowShortcutChange: { shortcut in
                    appDelegate.appState.updateShowPanelShortcut(shortcut)
                },
                onPinShortcutChange: { shortcut in
                    appDelegate.appState.updatePinShortcut(shortcut)
                }
            )
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
