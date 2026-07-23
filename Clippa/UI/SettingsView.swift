import AppKit
import SwiftUI

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

            AppearanceSettingsView(settings: appState.settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
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
                Toggle("Monitor Clipboard", isOn: monitoringBinding)
                Toggle("Launch at Login", isOn: launchAtLoginBinding)

                LabeledContent("Shortcut") {
                    Text(appState.settings.showPanelShortcut.displayString)
                        .font(.body.monospaced())
                }
            }

            Section("Auto-Paste") {
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

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { !appState.settings.isMonitoringPaused },
            set: { appState.setMonitoringPaused(!$0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginController.isEnabled },
            set: { appState.launchAtLoginController.setEnabled($0) }
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

private struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Appearance", selection: designBinding) {
                ForEach(PanelDesign.allCases) { design in
                    Label(design.displayName, systemImage: design.symbolName)
                        .tag(design)
                }
            }
            .pickerStyle(.segmented)

            AppearancePreview(design: settings.panelDesign)

            Text(appearanceDescription)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var designBinding: Binding<PanelDesign> {
        Binding(
            get: { settings.panelDesign },
            set: { settings.panelDesign = $0 }
        )
    }

    private var appearanceDescription: String {
        switch settings.panelDesign {
        case .glass: String(localized: "A translucent, native macOS surface with balanced spacing.")
        case .focus: String(localized: "More breathing room and a stronger selection indicator.")
        case .compact: String(localized: "Higher information density for larger clipboard histories.")
        }
    }
}

private struct AppearancePreview: View {
    let design: PanelDesign

    var body: some View {
        VStack(spacing: design == .compact ? 5 : 8) {
            HStack {
                Label("Clippa", systemImage: "paperclip")
                    .font(.headline)
                Spacer()
                Image(systemName: design.symbolName)
                    .foregroundStyle(.secondary)
            }

            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(index == 0 ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: ["text.alignleft", "link", "photo"][index])
                                .foregroundStyle(index == 0 ? Color.accentColor : Color.secondary)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.60))
                            .frame(width: CGFloat(150 - index * 18), height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: CGFloat(90 + index * 12), height: 4)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(height: design == .compact ? 40 : 48)
                .background(
                    index == 0 ? Color.accentColor.opacity(0.09) : Color.secondary.opacity(0.025),
                    in: .rect(cornerRadius: design.metrics.rowCornerRadius)
                )
            }
        }
        .padding(design.metrics.panelPadding)
        .background(.regularMaterial, in: .rect(cornerRadius: design.metrics.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: design.metrics.panelCornerRadius)
                .strokeBorder(Color.primary.opacity(0.09))
        }
        .frame(maxWidth: .infinity)
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
