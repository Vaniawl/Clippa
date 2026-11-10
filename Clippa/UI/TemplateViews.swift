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
            isEditing: item?.isTemplate == true,
            title: item?.template?.title ?? "",
            folder: item?.template?.folder ?? "",
            bodyText: body,
            onCancel: { [weak self] in self?.close() },
            onSave: { [weak self] title, folder, body in
                try onSave(title, folder, body)
                self?.close()
            }
        )
        show(
            title: String(localized: item?.isTemplate == true ? "Edit Template" : "New Template"),
            contentSize: NSSize(width: 640, height: 620),
            minimumContentSize: NSSize(width: 560, height: 560),
            view: view
        )
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

    private func show<V: View>(
        title: String,
        contentSize: NSSize = NSSize(width: 540, height: 540),
        minimumContentSize: NSSize? = nil,
        view: V
    ) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(width: 480, height: 440)
        if let minimumContentSize { window.contentMinSize = minimumContentSize }
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
    let isEditing: Bool
    @State var title: String
    @State var folder: String
    @State var bodyText: String
    var onCancel: () -> Void
    var onSave: (String, String, String) throws -> Void
    @State private var errorMessage: String?
    @State private var showsVariableGuide = false
    @State private var hasSetInitialFocus = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, folder, text, guide, cancel, save, done
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeading
            VStack(alignment: .leading, spacing: 20) {
                metadataFields
                textComposer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxHeight: .infinity)
            Divider()
            editorActions
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .focusEffectDisabled()
        .defaultFocus($focusedField, .name)
        .onAppear { focusNameIfReady(in: NSApp.keyWindow) }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            focusNameIfReady(in: notification.object as? NSWindow)
        }
        .onChange(of: title) { _, _ in errorMessage = nil }
        .onChange(of: folder) { _, _ in errorMessage = nil }
        .onChange(of: bodyText) { _, _ in errorMessage = nil }
    }

    private func focusNameIfReady(in window: NSWindow?) {
        guard !hasSetInitialFocus, let window, window.isKeyWindow,
              window.contentView is NSHostingView<TemplateEditorView> else { return }
        hasSetInitialFocus = true
        // AppKit establishes the key window's first responder after the view appears.
        DispatchQueue.main.async { focusedField = .name }
    }

    private var editorHeading: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 21, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.10), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Edit your template" : "Create a template")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Save a reply, message, or snippet for quick reuse.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private var metadataFields: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.callout.weight(.semibold))
                    .accessibilityHidden(true)
                TextField("e.g. Follow-up email", text: $title)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .name)
                    .accessibilityLabel(Text("Template name, required"))
                    .onSubmit { focusedField = .folder }
                    .modifier(TemplateInputSurface(isFocused: focusedField == .name))
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Folder").font(.callout.weight(.semibold))
                    Text("Optional").font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
                TextField("e.g. Work", text: $folder)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .folder)
                    .accessibilityLabel(Text("Folder, optional"))
                    .help("Use the same folder name to group related templates.")
                    .onSubmit { focusedField = .text }
                    .modifier(TemplateInputSurface(isFocused: focusedField == .folder))
            }
            .frame(width: 180)
        }
    }

    private var textComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Template text")
                    .font(.callout.weight(.semibold))
                    .accessibilityHidden(true)
                Spacer()
                Text(bodyText.count == 1 ? "1 character" : "\(bodyText.count.formatted()) characters")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .padding(10)
                    .focused($focusedField, equals: .text)
                    .accessibilityLabel(Text("Template text, required"))
                    .accessibilityHint(Text("Use variables in braces, such as name, date, or time."))
                if bodyText.isEmpty {
                    Text("Write your message, reply, or snippet…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 180, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 12))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(focusedField == .text ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.6))
                    .allowsHitTesting(false)
            }
            HStack(spacing: 8) {
                Image(systemName: "curlybraces")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Personalize with {name}, {date}, or {time}.")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button {
                    showsVariableGuide.toggle()
                } label: {
                    Label("Variable guide", systemImage: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .focused($focusedField, equals: .guide)
                .modifier(TemplateKeyboardFocus(isFocused: focusedField == .guide))
                .popover(isPresented: $showsVariableGuide, arrowEdge: .bottom) {
                    variableGuide
                }
            }
            .font(.caption)
        }
    }

    private var variableGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personalize your text")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Put a variable in braces wherever the text should change.")
                .font(.callout)
                .foregroundStyle(.secondary)
            guideExample("{name}", title: "Fill in when pasting", detail: "Clippa asks for a value each time you use the template.")
            Divider()
            guideExample("{date} · {time}", title: "Filled automatically", detail: "The current date and time are added when you use the template.")
            Text("Names in other languages work too, including {ім’я} and {дата}.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done") {
                    showsVariableGuide = false
                    focusedField = .guide
                }
                .keyboardShortcut(.cancelAction)
                .focused($focusedField, equals: .done)
                .modifier(TemplateKeyboardFocus(isFocused: focusedField == .done))
            }
        }
        .padding(20)
        .frame(width: 340)
        .defaultFocus($focusedField, .done)
    }

    private func guideExample(_ token: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: token)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(Color.accentColor)
            Text(title).font(.callout.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var editorActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .focused($focusedField, equals: .cancel)
                    .modifier(TemplateKeyboardFocus(isFocused: focusedField == .cancel))
                Spacer()
                if !canSave {
                    Text("Name and text are required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(isEditing ? "Save Changes" : "Create Template") {
                    do { try onSave(title, folder, bodyText) }
                    catch { errorMessage = error.localizedDescription }
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .focused($focusedField, equals: .save)
                .modifier(TemplateKeyboardFocus(isFocused: focusedField == .save))
                .disabled(!canSave)
                .help("Save template (⌘S)")
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private struct TemplateKeyboardFocus: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isFocused {
                Rectangle()
                    .fill(Color.primary)
                    .frame(height: 1)
                    .padding(.horizontal, 6)
                    .offset(y: 3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct TemplateInputSurface: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .frame(height: DesignSystem.controlHeight)
            .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.6))
                    .allowsHitTesting(false)
            }
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
