import SwiftUI
import UIKit

struct ClipsHomeView: View {
    let store: IOSClipStore
    @State private var searchQuery = ""
    @State private var previewClip: IOSClip?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ClippaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if store.clips.isEmpty {
                            HeaderView()
                            WorkflowCard()
                        } else {
                            CompactHeaderView(count: store.clips.count)
                        }
                        SaveClipboardButton {
                            saveCurrentClipboard()
                        }
                        FilterStrip(store: store)
                        ClipList(
                            clips: store.filteredClips(query: searchQuery),
                            store: store,
                            onCopy: copy,
                            onPreview: { previewClip = $0 }
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 96)
                }
                .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search clips")
                .navigationTitle("Clippa")
                .navigationBarTitleDisplayMode(.inline)

                if let message = store.lastCopyMessage {
                    ToastView(message: message)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(2))
                            store.clearMessage()
                        }
                }
            }
            .animation(.snappy(duration: 0.22), value: store.lastCopyMessage)
            .sheet(item: $previewClip) { clip in
                ClipPreviewSheet(clip: clip, store: store)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func saveCurrentClipboard() {
        let didSave = store.saveCurrentPasteboard()
        UINotificationFeedbackGenerator().notificationOccurred(didSave ? .success : .warning)
    }

    private func copy(_ clip: IOSClip) {
        guard store.copy(clip) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Clipboard you control.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Save what is currently copied, tap any clip later, then return to the previous app and paste.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(.top, 8)
    }
}

private struct CompactHeaderView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tap to copy.")
                    .font(.title2.weight(.bold))
                Text("\(count) saved \(count == 1 ? "clip" : "clips")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct WorkflowCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkflowStep(number: "1", title: "Copy", detail: "Copy text, a link, or an image in another app.")
            WorkflowStep(number: "2", title: "Save", detail: "Open Clippa and save the current clipboard.")
            WorkflowStep(number: "3", title: "Paste", detail: "Tap a saved clip, go back, and paste normally.")
        }
        .padding(14)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct WorkflowStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
                .background(.blue.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SaveClipboardButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Save current clipboard")
                        .font(.headline)
                    Text("Uses the clipboard only when you tap this button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save current clipboard")
        .accessibilityIdentifier("saveCurrentClipboardButton")
    }
}

private struct FilterStrip: View {
    let store: IOSClipStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(IOSClipFilter.allCases) { filter in
                    Button {
                        store.selectedFilter = filter
                    } label: {
                        Label(filter.title, systemImage: filter.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                store.selectedFilter == filter ? Color.blue.opacity(0.14) : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(store.selectedFilter == filter ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filter.\(filter.rawValue)")
                }
            }
        }
    }
}

private struct ClipList: View {
    let clips: [IOSClip]
    let store: IOSClipStore
    let onCopy: (IOSClip) -> Void
    let onPreview: (IOSClip) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if clips.isEmpty {
                EmptyClipsView()
            } else {
                ForEach(clips) { clip in
                    ClipRow(clip: clip) {
                        onCopy(clip)
                    } onPin: {
                        store.togglePin(clip)
                    } onDelete: {
                        store.delete(clip)
                    } onPreview: {
                        onPreview(clip)
                    }
                }
            }
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
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        Label("Copy and return", systemImage: "doc.on.clipboard")
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No clips yet")
                .font(.headline)
            Text("Copy something in another app, open Clippa, and tap Save current clipboard.")
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

#Preview {
    let store = IOSClipStore(defaults: .init(suiteName: "ClippaIOSPreview")!)
    store.saveCurrentPasteboard()
    return ClipsHomeView(store: store)
}
