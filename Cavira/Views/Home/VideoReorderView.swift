import SwiftData
import SwiftUI

struct VideoReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true }
    )
    private var queriedVideos: [PhotoEntry]

    @State private var local: [PhotoEntry] = []
    @State private var hasNormalized = false

    init() {}

    var body: some View {
        NavigationStack {
            VideoReorderScreen(
                local: $local,
                videos: videos,
                onDone: { dismiss() },
                onMove: move(from:to:),
                onNormalize: normalizeIfNeeded
            )
        }
    }

    private var videos: [PhotoEntry] {
        queriedVideos
            .filter { $0.mediaKind == .video }
            .sorted(by: videoSort)
    }

    private var videoIDs: [UUID] {
        videos.map(\.id)
    }

    private func normalizeIfNeeded() {
        guard !hasNormalized else {
            if local.isEmpty { local = videos }
            return
        }
        local = videos
        if local.contains(where: { $0.videoOrderIndex == nil }) {
            for (idx, entry) in local.enumerated() {
                entry.videoOrderIndex = idx
            }
            try? modelContext.save()
        }
        hasNormalized = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        local.move(fromOffsets: source, toOffset: destination)
        for (idx, entry) in local.enumerated() {
            entry.videoOrderIndex = idx
        }
        try? modelContext.save()
    }
}

private struct VideoReorderScreen: View {
    @Binding var local: [PhotoEntry]
    let videos: [PhotoEntry]
    let onDone: () -> Void
    let onMove: (IndexSet, Int) -> Void
    let onNormalize: () -> Void

    private var videoIDs: [UUID] { videos.map(\.id) }

    var body: some View {
        List {
            ForEach(local, id: \.id) { entry in
                VideoReorderRow(entry: entry)
                    .listRowBackground(CaviraTheme.surfaceCard)
            }
            .onMove(perform: onMove)
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(CaviraTheme.backgroundSecondary)
        .navigationTitle("Reorder videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar { toolbarContent }
        .onAppear { onNormalize() }
        .onChange(of: videoIDs) { _, _ in
            local = videos
            onNormalize()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { onDone() }
                .foregroundStyle(CaviraTheme.accent)
        }
        ToolbarItem(placement: .principal) {
            Text("Reorder")
                .font(CaviraTheme.Typography.headline)
                .foregroundStyle(CaviraTheme.textPrimary)
        }
    }
}

private struct VideoReorderRow: View {
    let entry: PhotoEntry

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(entry: entry)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                if let title = entry.title, !title.isEmpty {
                    Text(title)
                        .font(CaviraTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.textPrimary)
                } else {
                    Text(entry.capturedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(CaviraTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.textPrimary)
                }
                Text("Video")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

private func videoSort(_ lhs: PhotoEntry, _ rhs: PhotoEntry) -> Bool {
    switch (lhs.videoOrderIndex, rhs.videoOrderIndex) {
    case let (l?, r?):
        if l != r { return l < r }
    case (nil, nil):
        break
    case (nil, _?):
        return false
    case (_?, nil):
        return true
    }
    return lhs.capturedDate > rhs.capturedDate
}

#Preview {
    NavigationStack {
        VideoReorderView()
    }
    .caviraPreviewShell()
}

