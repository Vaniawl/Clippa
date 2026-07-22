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
    @State private var confirmClearUnpinned = false
    @State private var confirmClearAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: String(localized: "General")) {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                    Toggle("Save new copies", isOn: captureEnabledBinding)
                    statusRow(
                        title: String(localized: "Login item"),
                        value: LoginItemService.statusDescription,
                        symbol: settings.launchAtLogin ? "checkmark.circle.fill" : "circle",
                        color: settings.launchAtLogin ? .green : .secondary
                    )
                }

                SettingsPanel(title: String(localized: "Keyboard")) {
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

                SettingsPanel(title: String(localized: "Privacy")) {
                    statusRow(
                        title: String(localized: "Accessibility"),
                        value: AccessibilityService.isTrusted ? String(localized: "Granted") : String(localized: "Required for automatic paste"),
                        symbol: AccessibilityService.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        color: AccessibilityService.isTrusted ? .green : .orange
                    )
                    Text("Clipboard history stays on this Mac and is encrypted locally.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Request Access") {
                            AccessibilityService.requestPrompt()
                        }
                        Button("Open Privacy & Security") {
                            AccessibilityService.openSystemSettings()
                        }
                    }
                }

                SettingsPanel(title: String(localized: "History")) {
                    LabeledContent("Stored items", value: "100")
                    LabeledContent("Pinned items", value: String(localized: "Kept until deleted"))
                    Text("Unpinned history is cleaned automatically. You can clear it any time.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(title: String(localized: "Actions")) {
                    HStack {
                        Button("Clear unpinned history") {
                            confirmClearUnpinned = true
                        }
                        Button("Clear all history", role: .destructive) {
                            confirmClearAll = true
                        }
                    }
                }

                SettingsPanel(title: String(localized: "About")) {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? String(localized: "Unknown"))
                }
            }
            .padding(24)
        }
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

    private var captureEnabledBinding: Binding<Bool> {
        Binding(
            get: { !settings.isMonitoringPaused },
            set: { settings.isMonitoringPaused = !$0 }
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

struct SettingsPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator.opacity(0.5))
            }
        }
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
