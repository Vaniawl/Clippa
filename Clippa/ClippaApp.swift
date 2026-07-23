import AppKit
import SwiftUI

@main
struct ClippaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Clippa", systemImage: "paperclip") {
            Button("Show Panel") {
                appDelegate.appState.panelController.show(appState: appDelegate.appState)
            }
            Button("Settings") {
                appDelegate.appState.showSettings()
            }
            Divider()
            Button("Quit") {
                appDelegate.appState.quit()
            }
        }
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var accessibilityTrusted = AccessibilityService.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "paperclip.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clippa")
                        .font(.title3.weight(.semibold))
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                SettingsRow(title: "Shortcut", value: appState.settings.showPanelShortcut.displayString)
                Divider()
                SettingsRow(title: "History", value: "\(appState.store.items.count) \(String(localized: "Items"))")
                Divider()
                SettingsRow(
                    title: "Accessibility",
                    value: accessibilityTrusted ? String(localized: "Ready") : String(localized: "Needs access")
                ) {
                    Button("Open") {
                        AccessibilityService.openSystemSettings()
                    }
                }
            }
            .background(.regularMaterial, in: .rect(cornerRadius: 12))

            HStack {
                Button("Clear History", role: .destructive) {
                    _ = appState.store.clearAll()
                }
                .disabled(appState.store.items.isEmpty)

                Spacer()

                Button("Quit") {
                    appState.quit()
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            accessibilityTrusted = AccessibilityService.isTrusted
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: LocalizedStringKey
    let value: String
    @ViewBuilder var trailing: Trailing

    init(title: LocalizedStringKey, value: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.value = value
        self.trailing = trailing()
    }

    init(title: LocalizedStringKey, value: String) where Trailing == EmptyView {
        self.title = title
        self.value = value
        self.trailing = EmptyView()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
            trailing
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(appState: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Clippa Settings")
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(appState: appState))
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
