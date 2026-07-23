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
        if appState.settings.isMonitoringPaused {
            Label("Monitoring Paused", systemImage: "pause.circle.fill")
        } else {
            Text(historySummary)
        }

        if !appState.isAutoPasteReady {
            Button {
                AccessibilityService.openSystemSettings()
            } label: {
                Label("Enable Auto-Paste", systemImage: "accessibility")
            }
        }

        Button {
            appState.setMonitoringPaused(!appState.settings.isMonitoringPaused)
        } label: {
            Label(
                appState.settings.isMonitoringPaused ? "Resume Clipboard Monitoring" : "Pause Clipboard Monitoring",
                systemImage: appState.settings.isMonitoringPaused ? "play.fill" : "pause.fill"
            )
        }

        Menu {
            Picker("Appearance", selection: panelDesignBinding) {
                ForEach(PanelDesign.allCases) { design in
                    Label(design.displayName, systemImage: design.symbolName)
                        .tag(design)
                }
            }
        } label: {
            Label("Appearance", systemImage: appState.settings.panelDesign.symbolName)
        }

        Divider()

        if appState.canUndoHistoryAction {
            Button {
                appState.undoLastHistoryAction()
            } label: {
                Label("Undo History Change", systemImage: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: .command)
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

    private var historySummary: String {
        let count = appState.store.items.count
        return "\(count) \(String(localized: "Items")) · \(appState.settings.showPanelShortcut.displayString)"
    }

    private var panelDesignBinding: Binding<PanelDesign> {
        Binding(
            get: { appState.settings.panelDesign },
            set: { appState.settings.panelDesign = $0 }
        )
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
