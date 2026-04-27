import SwiftData
import SwiftUI

struct HomeReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true }
    )
    private var queriedPhotos: [PhotoEntry]

    @State private var local: [PhotoEntry] = []
    @State private var hasNormalized = false

    // Explicit initializer prevents Swift from synthesizing a private memberwise init
    // (which can happen when stored properties are `private`, like `photos`).
    init() {}

    var body: some View {
        NavigationStack {
            HomeReorderScreen(
                local: $local,
                photos: photos,
                onDone: { dismiss() },
                onMove: move(from:to:),
                onNormalize: normalizeIfNeeded
            )
        }
    }

    private var photos: [PhotoEntry] {
        queriedPhotos.sorted(by: photoSort)
    }

    private var photoIDs: [UUID] {
        photos.map(\.id)
    }

    private func normalizeIfNeeded() {
        guard !hasNormalized else {
            if local.isEmpty { local = photos }
            return
        }
        local = photos
        // If any are nil, assign indices based on current order.
        if local.contains(where: { $0.homeOrderIndex == nil }) {
            for (idx, entry) in local.enumerated() {
                entry.homeOrderIndex = idx
            }
            try? modelContext.save()
        }
        hasNormalized = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        local.move(fromOffsets: source, toOffset: destination)
        for (idx, entry) in local.enumerated() {
            entry.homeOrderIndex = idx
        }
        try? modelContext.save()
    }
}

private struct HomeReorderScreen: View {
    @Binding var local: [PhotoEntry]
    let photos: [PhotoEntry]
    let onDone: () -> Void
    let onMove: (IndexSet, Int) -> Void
    let onNormalize: () -> Void

    private var photoIDs: [UUID] { photos.map(\.id) }

    var body: some View {
        List {
            ForEach(local, id: \.id) { entry in
                HomeReorderRow(entry: entry)
                    .listRowBackground(CaviraTheme.surfaceCard)
            }
            .onMove(perform: onMove)
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(CaviraTheme.backgroundSecondary)
        .navigationTitle("Reorder album")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar { toolbarContent }
        .onAppear { onNormalize() }
        .onChange(of: photoIDs) { _, _ in
            local = photos
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

private struct HomeReorderRow: View {
    let entry: PhotoEntry

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(entry: entry)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                titleLine
                kindLine
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var titleLine: some View {
        if let title = entry.title, !title.isEmpty {
            Text(title)
                .font(CaviraTheme.Typography.body.weight(.semibold))
                .foregroundStyle(CaviraTheme.textPrimary)
        } else {
            Text(entry.capturedDate.formatted(date: .abbreviated, time: .omitted))
                .font(CaviraTheme.Typography.body.weight(.semibold))
                .foregroundStyle(CaviraTheme.textPrimary)
        }
    }

    private var kindLine: some View {
        Text(kindLabel)
            .font(CaviraTheme.Typography.caption)
            .foregroundStyle(CaviraTheme.textTertiary)
    }

    private var kindLabel: String {
        if entry.mediaKind == .video { return "Video" }
        if entry.isLivePhoto { return "Live Photo" }
        return "Photo"
    }
}

private func photoSort(_ lhs: PhotoEntry, _ rhs: PhotoEntry) -> Bool {
    switch (lhs.homeOrderIndex, rhs.homeOrderIndex) {
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
        HomeReorderView()
    }
    .caviraPreviewShell()
}

