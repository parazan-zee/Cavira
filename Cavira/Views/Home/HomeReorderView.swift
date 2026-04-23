import SwiftData
import SwiftUI

struct HomeReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true },
        sort: [
            SortDescriptor(\PhotoEntry.homeOrderIndex, order: .forward),
            SortDescriptor(\PhotoEntry.capturedDate, order: .reverse),
        ]
    )
    private var photos: [PhotoEntry]

    @State private var local: [PhotoEntry] = []
    @State private var hasNormalized = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(local, id: \.id) { entry in
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
                            Text(entry.mediaKind == .video ? "Video" : (entry.isLivePhoto ? "Live Photo" : "Photo"))
                                .font(CaviraTheme.Typography.caption)
                                .foregroundStyle(CaviraTheme.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(CaviraTheme.surfaceCard)
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Reorder album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaviraTheme.accent)
                }
                ToolbarItem(placement: .principal) {
                    Text("Reorder")
                        .font(CaviraTheme.Typography.headline)
                        .foregroundStyle(CaviraTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
            }
            .onAppear {
                normalizeIfNeeded()
            }
            .onChange(of: photos.map(\.id)) { _, _ in
                // Keep local list in sync with the query.
                local = photos
                normalizeIfNeeded()
            }
        }
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

#Preview {
    NavigationStack {
        HomeReorderView()
    }
    .caviraPreviewShell()
}

