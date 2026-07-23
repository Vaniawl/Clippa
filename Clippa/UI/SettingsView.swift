import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            HistorySettingsView(appState: appState)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            PrivacySettingsView(appState: appState)
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
        }
        .padding(20)
        .frame(width: 580, height: 440)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var appState: AppState
    @State private var accessibilityTrusted = AccessibilityService.isTrusted

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)

                LabeledContent("Shortcut") {
                    Text(appState.settings.showPanelShortcut.displayString)
                        .font(.body.monospaced())
                }
            }

            Section("Auto-Paste") {
                Toggle("Add Space After Paste", isOn: addSpaceAfterPasteBinding)
                    .help("Adds one space after pasted text or links.")

                LabeledContent("Accessibility") {
                    Label(
                        accessibilityTrusted ? "Ready" : "Needs access",
                        systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
                }

                Button {
                    AccessibilityService.openSystemSettings()
                } label: {
                    Label("Open Accessibility Settings", systemImage: "arrow.up.forward.square")
                }
            }

            Section("Clipboard Cleanup") {
                Toggle("Normalize Text", isOn: normalizeCopiedTextBinding)
                    .help("Trims copied text and normalizes line endings before saving it.")
                Toggle("Remove Link Tracking", isOn: removeTrackingParametersBinding)
                    .help("Removes common tracking parameters such as utm_source, fbclid, and gclid.")
            }

            if let message = appState.launchAtLoginController.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clippa")
                            .font(.headline)
                        Text(verbatim: "\(String(localized: "Private clipboard history")) · \(String(localized: "Version")) \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit Clippa") {
                        appState.quit()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            accessibilityTrusted = AccessibilityService.isTrusted
            appState.launchAtLoginController.refresh()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginController.isEnabled },
            set: { appState.launchAtLoginController.setEnabled($0) }
        )
    }

    private var addSpaceAfterPasteBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.addSpaceAfterPaste },
            set: { appState.settings.addSpaceAfterPaste = $0 }
        )
    }

    private var normalizeCopiedTextBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.normalizeCopiedText },
            set: { appState.settings.normalizeCopiedText = $0 }
        )
    }

    private var removeTrackingParametersBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.removeTrackingParametersFromLinks },
            set: { appState.settings.removeTrackingParametersFromLinks = $0 }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private struct HistorySettingsView: View {
    @Bindable var appState: AppState
    @State private var confirmation: HistoryClearConfirmation?

    var body: some View {
        Form {
            Section("Storage") {
                Picker("Keep History", selection: retentionBinding) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(retention.displayName)
                            .tag(retention)
                    }
                }

                Picker("Maximum Items", selection: limitBinding) {
                    ForEach(HistoryLimit.allCases) { limit in
                        Text(limit.displayName)
                            .tag(limit)
                    }
                }
            }

            Section("Current History") {
                LabeledContent("Items", value: "\(appState.store.items.count)")
                LabeledContent("Pinned", value: "\(appState.store.pinnedItemCount)")
            }

            Section("Pinned Clips") {
                HStack {
                    Button {
                        appState.exportPinnedClips()
                    } label: {
                        Label("Export Pinned", systemImage: "square.and.arrow.up")
                    }
                    .disabled(appState.store.pinnedItemCount == 0)

                    Button {
                        appState.importPinnedClips()
                    } label: {
                        Label("Import Pinned", systemImage: "square.and.arrow.down")
                    }

                    Spacer()
                }
            }

            Section {
                HStack {
                    Button("Clear Unpinned", role: .destructive) {
                        confirmation = .unpinned
                    }
                    .disabled(!appState.store.items.contains(where: { !$0.isPinned }))

                    Button("Clear All", role: .destructive) {
                        confirmation = .all
                    }
                    .disabled(appState.store.items.isEmpty)

                    Spacer()

                    Button {
                        appState.undoLastHistoryAction()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!appState.canUndoHistoryAction)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if let confirmation {
                Button(confirmation.buttonTitle, role: .destructive) {
                    clearHistory(confirmation)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can undo this action until Clippa quits.")
        }
    }

    private var retentionBinding: Binding<HistoryRetention> {
        Binding(
            get: { appState.settings.historyRetention },
            set: { appState.setHistoryRetention($0) }
        )
    }

    private var limitBinding: Binding<HistoryLimit> {
        Binding(
            get: { appState.settings.historyLimit },
            set: { appState.setHistoryLimit($0) }
        )
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )
    }

    private func clearHistory(_ confirmation: HistoryClearConfirmation) {
        switch confirmation {
        case .unpinned:
            appState.clearUnpinnedHistory()
        case .all:
            appState.clearAllHistory()
        }
        self.confirmation = nil
    }
}

private enum HistoryClearConfirmation: String, Identifiable {
    case unpinned
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unpinned: String(localized: "Clear Unpinned History?")
        case .all: String(localized: "Clear All History?")
        }
    }

    var buttonTitle: String {
        switch self {
        case .unpinned: String(localized: "Clear Unpinned")
        case .all: String(localized: "Clear All")
        }
    }
}

private struct PrivacySettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(appState.settings.capturePauseDescription, systemImage: appState.settings.isCapturePaused ? "pause.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(appState.settings.isCapturePaused ? Color.orange : Color.green)
                    Spacer()
                    if appState.settings.isCapturePaused {
                        Button("Resume") {
                            appState.settings.resumeCapture()
                        }
                    }
                }

                HStack {
                    Button("Pause 15 Min") {
                        appState.settings.pauseCapture(for: 15 * 60)
                    }
                    Button("Pause 1 Hour") {
                        appState.settings.pauseCapture(for: 60 * 60)
                    }
                    Button("Pause Until Tomorrow") {
                        appState.settings.pauseCapture(for: 24 * 60 * 60)
                    }
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 12))

            Text("Excluded Applications")
                .font(.headline)
            Text("Clippa ignores clipboard changes made by these applications.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(appState.settings.excludedBundleIdentifiers, id: \.self) { identifier in
                    ExcludedApplicationRow(identifier: identifier) {
                        appState.settings.removeExcludedBundleIdentifier(identifier)
                    }
                }
            }
            .overlay {
                if appState.settings.excludedBundleIdentifiers.isEmpty {
                    ContentUnavailableView(
                        "No Excluded Applications",
                        systemImage: "hand.raised.slash",
                        description: Text("Add an application whose clipboard should stay private.")
                    )
                }
            }

            HStack {
                Button {
                    chooseApplication()
                } label: {
                    Label("Add Application", systemImage: "plus")
                }

                Spacer()

                Button("Restore Password Managers") {
                    for identifier in PrivacyFilter.defaultExcludedBundleIdentifiers {
                        appState.settings.addExcludedBundleIdentifier(identifier)
                    }
                }
            }
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose an Application")
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else {
            return
        }
        for url in panel.urls {
            if let identifier = Bundle(url: url)?.bundleIdentifier {
                appState.settings.addExcludedBundleIdentifier(identifier)
            }
        }
    }
}

private struct ExcludedApplicationRow: View {
    let identifier: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: applicationIcon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(applicationName)
                    .lineLimit(1)
                Text(identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 3)
    }

    private var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    private var applicationName: String {
        applicationURL.map { FileManager.default.displayName(atPath: $0.path) } ?? identifier
    }

    private var applicationIcon: NSImage {
        guard let applicationURL else {
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: applicationURL.path)
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
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 440),
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
