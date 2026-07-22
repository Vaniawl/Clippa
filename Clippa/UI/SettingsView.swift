import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: ClipboardStore
    let hotKeyStatus: String
    var usesFixedFrame = true
    var onUndoableItemsRemoved: @MainActor (_ message: String, _ restoredMessage: String, _ items: [ClipboardItem]) -> Void = { _, _, _ in }
    let onShowShortcutChange: (HotKeyShortcut) -> Void
    let onPinShortcutChange: (HotKeyShortcut) -> Void
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
                    title: String(localized: "Capture status"),
                    value: settings.isMonitoringPaused ? String(localized: "Paused") : String(localized: "Watching"),
                    symbol: settings.isMonitoringPaused ? "pause.circle.fill" : "record.circle",
                    color: settings.isMonitoringPaused ? .orange : .green
                )
                Toggle("Pause clipboard monitoring", isOn: $settings.isMonitoringPaused)
            }

            Section("Keyboard") {
                LabeledContent {
                    HStack(spacing: 8) {
                        HotKeyRecorder(shortcut: showShortcutBinding, onCommit: onShowShortcutChange)
                            .frame(width: 116, height: 30)
                        resetShortcutButton {
                            onShowShortcutChange(.defaultShowPanel)
                        }
                    }
                } label: {
                    Label("Show history", systemImage: "keyboard")
                }
                statusRow(
                    title: String(localized: "Shortcut status"),
                    value: hotKeyStatus,
                    symbol: hotKeyStatus == String(localized: "Registered") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    color: hotKeyStatus == String(localized: "Registered") ? .green : .orange
                )
                LabeledContent {
                    HStack(spacing: 8) {
                        HotKeyRecorder(shortcut: pinShortcutBinding, onCommit: onPinShortcutChange)
                            .frame(width: 116, height: 30)
                        resetShortcutButton {
                            onPinShortcutChange(.defaultPinSelected)
                        }
                    }
                } label: {
                    Label("Pin selected item", systemImage: "pin")
                }
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

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? String(localized: "Unknown"))
            }
        }
        .formStyle(.grouped)
        .frame(
            width: usesFixedFrame ? 560 : nil,
            height: usesFixedFrame ? 720 : nil
        )
        .confirmationDialog("Clear unpinned clipboard history?", isPresented: $confirmClearUnpinned) {
            Button("Clear unpinned history", role: .destructive) {
                let removed = store.clearUnpinned()
                onUndoableItemsRemoved(
                    String(localized: "Unpinned history cleared."),
                    String(localized: "History restored."),
                    removed
                )
            }
        }
        .confirmationDialog("Clear all clipboard history?", isPresented: $confirmClearAll) {
            Button("Clear all history", role: .destructive) {
                let removed = store.clearAll()
                onUndoableItemsRemoved(
                    String(localized: "History cleared."),
                    String(localized: "History restored."),
                    removed
                )
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

    private var showShortcutBinding: Binding<HotKeyShortcut> {
        Binding(
            get: { settings.showPanelShortcut },
            set: { onShowShortcutChange($0) }
        )
    }

    private var pinShortcutBinding: Binding<HotKeyShortcut> {
        Binding(
            get: { settings.pinShortcut },
            set: { onPinShortcutChange($0) }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
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

    private func resetShortcutButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.borderless)
        .help(String(localized: "Reset shortcut"))
        .accessibilityLabel(Text("Reset shortcut"))
    }
}

private struct HotKeyRecorder: NSViewRepresentable {
    @Binding var shortcut: HotKeyShortcut
    let onCommit: (HotKeyShortcut) -> Void

    func makeNSView(context: Context) -> HotKeyRecorderButton {
        let button = HotKeyRecorderButton(shortcut: shortcut)
        let shortcutBinding = $shortcut
        button.onShortcut = { newShortcut in
            shortcutBinding.wrappedValue = newShortcut
            onCommit(newShortcut)
        }
        return button
    }

    func updateNSView(_ nsView: HotKeyRecorderButton, context: Context) {
        nsView.shortcut = shortcut
        let shortcutBinding = $shortcut
        nsView.onShortcut = { newShortcut in
            shortcutBinding.wrappedValue = newShortcut
            onCommit(newShortcut)
        }
    }
}

private final class HotKeyRecorderButton: NSButton {
    var shortcut: HotKeyShortcut {
        didSet { updateTitle() }
    }
    var onShortcut: ((HotKeyShortcut) -> Void)?
    private var isRecording = false {
        didSet { updateTitle() }
    }
    private var validationMessage: String?

    override var acceptsFirstResponder: Bool { true }

    init(shortcut: HotKeyShortcut) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        bezelStyle = .rounded
        controlSize = .regular
        font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(startRecording)
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func startRecording() {
        validationMessage = nil
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            validationMessage = nil
            isRecording = false
            return
        }
        guard let newShortcut = HotKeyShortcut.from(event: event) else {
            NSSound.beep()
            validationMessage = String(localized: "Use Command, Control, or Option with another key.")
            updateTitle()
            return
        }
        shortcut = newShortcut
        validationMessage = nil
        isRecording = false
        onShortcut?(newShortcut)
    }

    private func updateTitle() {
        title = isRecording ? String(localized: "Press shortcut") : shortcut.displayString
        toolTip = validationMessage ?? String(localized: "Click to record shortcut")
    }
}
