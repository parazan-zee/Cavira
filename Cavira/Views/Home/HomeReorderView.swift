import SwiftData
import SwiftUI

struct HomeReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true && $0.homeCollection == nil }
    )
    private var queriedStandalone: [PhotoEntry]

    @Query(sort: \HomeCollection.createdDate, order: .reverse)
    private var allCollections: [HomeCollection]

    @State private var local: [HomeAlbumRow] = []
    @State private var hasNormalized = false

    init() {}

    var body: some View {
        NavigationStack {
            HomeReorderScreen(
                local: $local,
                mergedRows: mergedRows,
                onDone: { dismiss() },
                onMove: move(from:to:),
                onNormalize: normalizeIfNeeded
            )
        }
    }

    private var mergedRows: [HomeAlbumRow] {
        let photos = queriedStandalone
            .filter { $0.mediaKind == .image }
            .map { HomeAlbumRow.standalone($0) }
        let cols = allCollections
            .filter { $0.coverEntry != nil }
            .map { HomeAlbumRow.collection($0) }
        return (photos + cols).sorted(by: HomeAlbumRow.mergedSort)
    }

    private var mergedRowIDs: [String] {
        mergedRows.map(rowID)
    }

    private func rowID(_ row: HomeAlbumRow) -> String {
        switch row {
        case .standalone(let e): "p:\(e.id.uuidString)"
        case .collection(let c): "c:\(c.id.uuidString)"
        }
    }

    private func normalizeIfNeeded() {
        guard !hasNormalized else {
            if local.isEmpty { local = mergedRows }
            return
        }
        local = mergedRows
        var needsSave = false
        if local.contains(where: { row in
            switch row {
            case .standalone(let e): e.homeOrderIndex == nil
            case .collection(let c): c.homeOrderIndex == nil
            }
        }) {
            for (idx, row) in local.enumerated() {
                switch row {
                case .standalone(let e):
                    e.homeOrderIndex = idx
                case .collection(let c):
                    c.homeOrderIndex = idx
                }
            }
            needsSave = true
        }
        if needsSave { try? modelContext.save() }
        hasNormalized = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        local.move(fromOffsets: source, toOffset: destination)
        for (idx, row) in local.enumerated() {
            switch row {
            case .standalone(let e):
                e.homeOrderIndex = idx
            case .collection(let c):
                c.homeOrderIndex = idx
            }
        }
        try? modelContext.save()
    }
}

private struct HomeReorderScreen: View {
    @Binding var local: [HomeAlbumRow]
    let mergedRows: [HomeAlbumRow]
    let onDone: () -> Void
    let onMove: (IndexSet, Int) -> Void
    let onNormalize: () -> Void

    private var mergedRowIDs: [String] {
        mergedRows.map { rowID($0) }
    }

    private func rowID(_ row: HomeAlbumRow) -> String {
        switch row {
        case .standalone(let e): "p:\(e.id.uuidString)"
        case .collection(let c): "c:\(c.id.uuidString)"
        }
    }

    var body: some View {
        List {
            ForEach(local) { row in
                HomeReorderRow(row: row)
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
        .onChange(of: mergedRowIDs) { _, _ in
            local = mergedRows
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
    let row: HomeAlbumRow

    var body: some View {
        HStack(spacing: 12) {
            switch row {
            case .standalone(let entry):
                PhotoThumbnailView(entry: entry)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    titleLine(for: entry)
                    kindLine(for: entry)
                }
            case .collection(let collection):
                if let cover = collection.coverEntry {
                    PhotoThumbnailView(entry: cover)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CaviraTheme.surfacePhoto)
                        .frame(width: 54, height: 54)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title)
                        .font(CaviraTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Text("Collection · \(collection.entries.count) items")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func titleLine(for entry: PhotoEntry) -> some View {
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

    private func kindLine(for entry: PhotoEntry) -> some View {
        Text(kindLabel(for: entry))
            .font(CaviraTheme.Typography.caption)
            .foregroundStyle(CaviraTheme.textTertiary)
    }

    private func kindLabel(for entry: PhotoEntry) -> String {
        if entry.mediaKind == .video { return "Video" }
        if entry.isLivePhoto { return "Live Photo" }
        return "Photo"
    }
}

#Preview {
    NavigationStack {
        HomeReorderView()
    }
    .caviraPreviewShell()
}
