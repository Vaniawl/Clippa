import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: ClipboardStore
    let hotKeyStatus: String
    @State private var newExcludedIdentifier = ""
    @State private var confirmClearUnpinned = false
    @State private var confirmClearAll = false

    var body: some View {
        Form {
            Section("Permissions") {
                statusRow(
                    title: String(localized: "Accessibility"),
                    value: AccessibilityService.isTrusted ? String(localized: "Granted") : String(localized: "Required for automatic paste"),
                    symbol: AccessibilityService.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    color: AccessibilityService.isTrusted ? .green : .orange
                )
                HStack {
                    Button("Request Access") {
                        AccessibilityService.requestPrompt()
                    }
                    Button("Open Privacy & Security") {
                        AccessibilityService.openSystemSettings()
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                statusRow(
                    title: String(localized: "Login item"),
                    value: LoginItemService.statusDescription,
                    symbol: settings.launchAtLogin ? "checkmark.circle.fill" : "circle",
                    color: settings.launchAtLogin ? .green : .secondary
                )
                statusRow(
                    title: String(localized: "Shortcut"),
                    value: "⌘⇧V",
                    symbol: "keyboard",
                    color: .secondary
                )
                statusRow(
                    title: String(localized: "Shortcut status"),
                    value: hotKeyStatus,
                    symbol: hotKeyStatus == String(localized: "Registered") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    color: hotKeyStatus == String(localized: "Registered") ? .green : .orange
                )
                Toggle("Pause clipboard monitoring", isOn: $settings.isMonitoringPaused)
                statusRow(
                    title: String(localized: "Capture status"),
                    value: settings.isMonitoringPaused ? String(localized: "Paused") : String(localized: "Watching"),
                    symbol: settings.isMonitoringPaused ? "pause.circle.fill" : "record.circle",
                    color: settings.isMonitoringPaused ? .orange : .green
                )
            }

            Section("Retention") {
                LabeledContent("History", value: "100 unpinned items / 7 days")
                Text("Pinned items are kept until you delete them. Clipboard history is encrypted locally with a Keychain-backed AES-GCM key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Excluded Apps") {
                Text("Source app detection is best-effort. Apps listed here are not saved to history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("Bundle identifier", text: $newExcludedIdentifier)
                    Button {
                        settings.addExcludedBundleIdentifier(newExcludedIdentifier)
                        newExcludedIdentifier = ""
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add excluded app"))
                }
                ForEach(settings.excludedBundleIdentifiers, id: \.self) { identifier in
                    HStack {
                        Text(identifier)
                        Spacer()
                        Button {
                            settings.removeExcludedBundleIdentifier(identifier)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Remove \(identifier)"))
                    }
                }
            }

            Section("History") {
                Button("Clear unpinned history") {
                    confirmClearUnpinned = true
                }
                Button("Clear all history", role: .destructive) {
                    confirmClearAll = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 660)
        .confirmationDialog("Clear unpinned clipboard history?", isPresented: $confirmClearUnpinned) {
            Button("Clear unpinned history", role: .destructive) {
                store.clearUnpinned()
            }
        }
        .confirmationDialog("Clear all clipboard history?", isPresented: $confirmClearAll) {
            Button("Clear all history", role: .destructive) {
                store.clearAll()
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { enabled in
                do {
                    try LoginItemService.setEnabled(enabled)
                    settings.launchAtLogin = enabled
                } catch {
                    settings.launchAtLogin = false
                }
            }
        )
    }

    private func statusRow(title: String, value: String, symbol: String, color: Color) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(color)
            }
        }
    }
}
