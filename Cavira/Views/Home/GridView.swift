import SwiftUI

struct GridView: View {
    let rows: [HomeAlbumRow]
    /// Shown when `rows` is empty (e.g. Videos-only mode uses different copy when the album has photos but no videos).
    var emptyTitle: String = "Import your media to start"
    var emptySubtitle: String? = "Your album stays in Apple Photos; Cavira is where you curate what appears here."
    /// When false, only the `LazyVGrid` is emitted (for nesting inside a parent `ScrollView`).
    var embedInScrollView: Bool = true
    let onRequestRemoveRow: (HomeAlbumRow) -> Void
    var onEdit: ((PhotoEntry) -> Void)? = nil

    private let gridSpacing: CGFloat = 4

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
        ]
    }

    var body: some View {
        Group {
            if rows.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                let grid = LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(rows) { row in
                        switch row {
                        case .standalone(let entry):
                            NavigationLink(value: HomeDestination.photo(entry.id)) {
                                PhotoThumbnailView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let onEdit {
                                    Button("Edit", systemImage: "pencil") {
                                        onEdit(entry)
                                    }
                                }
                                Button("Remove from album", systemImage: "rectangle.badge.minus", role: .destructive) {
                                    onRequestRemoveRow(row)
                                }
                            }
                        case .collection(let collection):
                            NavigationLink(value: HomeDestination.collection(collection.id)) {
                                collectionCell(collection)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove from album", systemImage: "rectangle.badge.minus", role: .destructive) {
                                    onRequestRemoveRow(row)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, gridSpacing)

                if embedInScrollView {
                    ScrollView {
                        grid
                    }
                    .background(CaviraTheme.backgroundPrimary)
                } else {
                    grid
                }
            }
        }
    }

    private func collectionCell(_ collection: HomeCollection) -> some View {
        ZStack(alignment: .topTrailing) {
            if let cover = collection.coverEntry {
                PhotoThumbnailView(entry: cover)
            } else {
                Rectangle()
                    .fill(CaviraTheme.surfacePhoto)
                    .aspectRatio(1, contentMode: .fit)
            }

            Image(systemName: "square.stack.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(5)
                .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(6)
        }
    }
}
