import SwiftUI
import UIKit

struct ClipsHomeView: View {
    let store: IOSClipStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchQuery = ""
    @State private var sheet: IOSSheetDestination?

    private var visibleClips: [IOSClip] {
        store.filteredClips(query: searchQuery)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ClippaBackground()
                List {
                    Section {
                        HeaderSummaryView(
                            clipCount: store.clips.count,
                            pinnedCount: store.pinnedCount
                        )
                        .listRowInsets(.init(top: 8, leading: 18, bottom: 8, trailing: 18))

                        if !store.clips.isEmpty {
                            FilterStrip(store: store)
                                .listRowInsets(.init(top: 8, leading: 18, bottom: 8, trailing: 0))
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    Section {
                        if visibleClips.isEmpty {
                            EmptyClipsView(hasClips: !store.clips.isEmpty)
                                .listRowInsets(.init(top: 8, leading: 18, bottom: 8, trailing: 18))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(visibleClips) { clip in
                                ClipRow(
                                    clip: clip,
                                    onCopy: { copy(clip) },
                                    onPin: { togglePin(clip) },
                                    onDelete: { delete(clip) },
                                    onPreview: { sheet = .preview(clip) }
                                )
                                .listRowInsets(.init(top: 5, leading: 18, bottom: 5, trailing: 18))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(clip)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        togglePin(clip)
                                    } label: {
                                        Label(clip.isPinned ? "Unpin" : "Pin", systemImage: clip.isPinned ? "pin.slash" : "pin")
                                    }
                                    .tint(.blue)

                                    Button {
                                        copy(clip)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.clipboard")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(
                    text: $searchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search clips"
                )
                .navigationTitle("Clippa")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            sheet = .settings
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let message = store.lastCopyMessage {
                    ToastView(message: message)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(2))
                            store.clearMessage()
                        }
                }
            }
            .animation(.snappy(duration: 0.22), value: store.lastCopyMessage)
            .onAppear {
                captureClipboardIfNeeded(showMessage: false)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    captureClipboardIfNeeded(showMessage: false)
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(900))
                    captureClipboardIfNeeded(showMessage: false)
                }
            }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .preview(let clip):
                    ClipPreviewSheet(clip: clip, store: store)
                        .presentationDetents([.medium, .large])
                case .settings:
                    IOSSettingsSheet(store: store)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func captureClipboardIfNeeded(showMessage: Bool) {
        guard !IOSRuntimeEnvironment.isRunningUnitTests else {
            return
        }
        let result = store.captureCurrentPasteboardIfNeeded(showMessage: showMessage)
        if result.didSave {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func copy(_ clip: IOSClip) {
        guard store.copy(clip) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func togglePin(_ clip: IOSClip) {
        withAnimation(.snappy(duration: 0.2)) {
            store.togglePin(clip)
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func delete(_ clip: IOSClip) {
        withAnimation(.snappy(duration: 0.2)) {
            store.delete(clip)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private enum IOSRuntimeEnvironment {
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["CLIPPA_DISABLE_AUTOMATIC_CLIPBOARD_CAPTURE"] == "1" ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

private enum IOSSheetDestination: Identifiable, Hashable {
    case preview(IOSClip)
    case settings

    var id: String {
        switch self {
        case .preview(let clip):
            "preview-\(clip.id.uuidString)"
        case .settings:
            "settings"
        }
    }
}

private struct HeaderSummaryView: View {
    let clipCount: Int
    let pinnedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "paperclip.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clippa")
                        .font(.title2.weight(.bold))
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if clipCount == 0 {
                Text("Copy something in another app, return here, and Clippa keeps it ready.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    MetricPill(value: "\(clipCount)", label: clipCount == 1 ? "clip" : "clips", systemImage: "tray.full")
                    MetricPill(value: "\(pinnedCount)", label: "pinned", systemImage: "pin")
                }
            }
        }
        .padding(.top, 4)
    }

    private var summary: String {
        if clipCount == 0 {
            return "Private clipboard history"
        }
        return "Ready when you return"
    }
}

private struct MetricPill: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        Label {
            Text(value)
                .font(.subheadline.weight(.bold)) +
            Text(" \(label)")
                .font(.subheadline)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private struct FilterStrip: View {
    let store: IOSClipStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(IOSClipFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            store.selectedFilter = filter
                        }
                    } label: {
                        Label(filter.title, systemImage: filter.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                store.selectedFilter == filter ? Color.blue.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(store.selectedFilter == filter ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filter.\(filter.rawValue)")
                }
            }
            .padding(.trailing, 18)
        }
    }
}

private struct ClipRow: View {
    let clip: IOSClip
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            ClipIcon(clip: clip)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(clip.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if clip.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                    }
                }
                Text(clip.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button(action: onPreview) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview clip")
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onCopy)
        .contextMenu {
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
            Button(action: onPreview) {
                Label("Preview", systemImage: "eye")
            }
            Button(action: onPin) {
                Label(clip.isPinned ? "Unpin" : "Pin", systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Copy", onCopy)
        .accessibilityAction(named: clip.isPinned ? "Unpin" : "Pin", onPin)
        .accessibilityAction(named: "Delete", onDelete)
        .accessibilityIdentifier("clipRow.\(clip.id.uuidString)")
    }
}

private struct ClipPreviewSheet: View {
    let clip: IOSClip
    let store: IOSClipStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ClipIcon(clip: clip)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clip.kind.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(clip.title)
                                .font(.title3.weight(.bold))
                                .lineLimit(2)
                        }
                    }

                    PreviewBody(clip: clip)

                    Button {
                        store.copy(clip)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Label("Copy", systemImage: "doc.on.clipboard")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("copyPreviewButton")
                }
                .padding(18)
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let content = clip.content {
                        ShareLink(item: content) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share clip")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct IOSSettingsSheet: View {
    let store: IOSClipStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingClear: IOSClearScope?

    var body: some View {
        NavigationStack {
            List {
                Section("Privacy") {
                    Label("Saved locally on this iPhone", systemImage: "iphone")
                    Label("No account and no cloud sync", systemImage: "icloud.slash")
                    Label("New copies appear when Clippa is active", systemImage: "checkmark.shield")
                }

                Section("History") {
                    LabeledContent("Saved clips", value: "\(store.clips.count)")
                    LabeledContent("Pinned", value: "\(store.pinnedCount)")
                    LabeledContent("Limit", value: "200")

                    if store.unpinnedCount > 0 {
                        Button(role: .destructive) {
                            pendingClear = .unpinned
                        } label: {
                            Label("Clear Unpinned", systemImage: "tray")
                        }
                    }

                    if !store.clips.isEmpty {
                        Button(role: .destructive) {
                            pendingClear = .all
                        } label: {
                            Label("Clear All History", systemImage: "trash")
                        }
                    }
                }

                Section("Tips") {
                    Text("Shortcuts can still save the current clipboard or copy your latest Clippa item.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                pendingClear?.title ?? "",
                isPresented: Binding(
                    get: { pendingClear != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingClear = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let pendingClear {
                    Button(pendingClear.actionTitle, role: .destructive) {
                        switch pendingClear {
                        case .unpinned:
                            store.clearUnpinned()
                        case .all:
                            store.clearAll()
                        }
                        self.pendingClear = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingClear = nil
                }
            }
        }
    }
}

private enum IOSClearScope {
    case unpinned
    case all

    var title: String {
        switch self {
        case .unpinned:
            "Clear unpinned clips?"
        case .all:
            "Clear all Clippa history?"
        }
    }

    var actionTitle: String {
        switch self {
        case .unpinned:
            "Clear Unpinned"
        case .all:
            "Clear All"
        }
    }
}

private struct PreviewBody: View {
    let clip: IOSClip

    var body: some View {
        Group {
            if clip.kind == .image,
               let data = clip.imageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Text(clip.content ?? clip.detail)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct ClipIcon: View {
    let clip: IOSClip

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconColor.opacity(0.12))
                .frame(width: 46, height: 46)

            if clip.kind == .image,
               let data = clip.imageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Image(systemName: clip.kind.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
        }
        .accessibilityHidden(true)
    }

    private var iconColor: Color {
        switch clip.kind {
        case .text: .blue
        case .link: .teal
        case .image: .purple
        }
    }
}

private struct EmptyClipsView: View {
    let hasClips: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: hasClips ? "magnifyingglass" : "tray")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(hasClips ? "No matching clips" : "No clips yet")
                .font(.headline)
            Text(hasClips ? "Try another search or filter." : "Copy something in another app, then open Clippa.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityIdentifier("emptyClipsView")
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .accessibilityIdentifier("toast")
    }
}

private struct ClippaBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview("With Clips") {
    let store = IOSClipStore(defaults: .init(suiteName: "ClippaIOSPreview.withClips")!)
    store.replaceAll(IOSClip.sampleClips)
    return ClipsHomeView(store: store)
}

#Preview("Empty") {
    let store = IOSClipStore(defaults: .init(suiteName: "ClippaIOSPreview.empty")!)
    store.replaceAll([])
    return ClipsHomeView(store: store)
}
