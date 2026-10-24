import AppKit
import SwiftUI

@MainActor
final class TemplateWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    @discardableResult
    func activateIfVisible() -> Bool {
        guard let window, window.isVisible else { return false }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func edit(item: ClipboardItem?, onSave: @escaping (String, String, String) throws -> Void) {
        let body: String
        if case .text(let text) = item?.payload { body = text } else { body = "" }
        let view = TemplateEditorView(
            title: item?.template?.title ?? "",
            folder: item?.template?.folder ?? "",
            bodyText: body,
            onCancel: { [weak self] in self?.close() },
            onSave: { [weak self] title, folder, body in
                try onSave(title, folder, body)
                self?.close()
            }
        )
        show(title: String(localized: item?.isTemplate == true ? "Edit Template" : "New Template"), view: view)
    }

    func fill(item: ClipboardItem, onPaste: @escaping (String) -> Void) {
        guard case .text(let body) = item.payload else { return }
        let view = TemplateFillView(
            title: item.template?.title ?? "",
            bodyText: body,
            variables: TemplateRenderer.variables(in: body),
            onCancel: { [weak self] in self?.close() },
            onPaste: { [weak self] text in
                self?.close()
                onPaste(text)
            }
        )
        show(title: String(localized: "Use Template"), view: view)
    }

    private func show<V: View>(title: String, view: V) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(width: 480, height: 440)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.delegate = self
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

private struct TemplateEditorView: View {
    @State var title: String
    @State var folder: String
    @State var bodyText: String
    var onCancel: () -> Void
    var onSave: (String, String, String) throws -> Void
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            TemplateHeading(title: String(localized: "Text Template"), subtitle: String(localized: "Save text you use often, ready to personalize."))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.headline)
                        TextField("Name", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTitleFocused)
                            .accessibilityLabel(Text("Name"))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folder (optional)").font(.headline)
                        TextField("Folder (optional)", text: $folder)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel(Text("Folder (optional)"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template text").font(.headline)
                        TextEditor(text: $bodyText)
                            .font(.body)
                            .frame(minHeight: 180)
                            .padding(6)
                            .background(.background, in: .rect(cornerRadius: 8))
                            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)) }
                            .accessibilityLabel(Text("Template text"))
                        Text("Use {name} for a field to fill in. {date} and {time} are filled automatically. Ukrainian names such as {ім’я} and {дата} also work.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .accessibilityLabel(Text(errorMessage))
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Template") {
                    do { try onSave(title, folder, bodyText) }
                    catch { errorMessage = error.localizedDescription }
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .task { isTitleFocused = true }
    }
}

private struct TemplateFillView: View {
    let title: String
    let bodyText: String
    let variables: [String]
    let onCancel: () -> Void
    let onPaste: (String) -> Void
    @State private var values: [String: String] = [:]
    @FocusState private var focusedVariable: String?

    private var canPaste: Bool {
        variables.allSatisfy { !(values[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            TemplateHeading(title: title, subtitle: String(localized: "Fill in the fields, then paste into your previous app."))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(variables, id: \.self) { name in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(name).font(.headline)
                            TextField(name, text: Binding(
                                get: { values[name] ?? "" },
                                set: { values[name] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedVariable, equals: name)
                            .accessibilityLabel(Text(name))
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview").font(.headline)
                        Text(TemplateRenderer.render(bodyText, values: values))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.quaternary, in: .rect(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Paste") { onPaste(TemplateRenderer.render(bodyText, values: values)) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canPaste)
            }
            .padding(16)
        }
        .task { focusedVariable = variables.first }
    }
}

private struct TemplateHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "text.badge.plus")
                .font(.title2.weight(.semibold))
                .lineLimit(2)
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}
