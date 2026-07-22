import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: ClipboardStore
    let hotKeyStatus: String
    @State private var newExcludedIdentifier = ""
    @State private var confirmClearAll = false

    var body: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Accessibility", value: AccessibilityService.isTrusted ? String(localized: "Granted") : String(localized: "Required for automatic paste"))
                Button("Request Accessibility Access") {
                    AccessibilityService.requestPrompt()
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { enabled in
                        do {
                            try LoginItemService.setEnabled(enabled)
                            settings.launchAtLogin = enabled
                        } catch {
                            settings.launchAtLogin = false
                        }
                    }
                ))
                LabeledContent("Login item status", value: LoginItemService.statusDescription)
                LabeledContent("Shortcut", value: "⌘⇧V")
                LabeledContent("Shortcut status", value: hotKeyStatus)
                Toggle(settings.isMonitoringPaused ? "Resume monitoring" : "Pause monitoring", isOn: $settings.isMonitoringPaused)
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
                    store.clearUnpinned()
                }
                Button("Clear all history", role: .destructive) {
                    confirmClearAll = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 620)
        .confirmationDialog("Clear all clipboard history?", isPresented: $confirmClearAll) {
            Button("Clear all history", role: .destructive) {
                store.clearAll()
            }
        }
    }
}
