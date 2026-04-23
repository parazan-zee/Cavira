import SwiftUI

struct GridView: View {
    let photos: [PhotoEntry]
    /// Shown when `photos` is empty (e.g. Videos-only mode uses different copy when the album has photos but no videos).
    var emptyTitle: String = "Import your media to start"
    var emptySubtitle: String? = "Your album stays in Apple Photos; Cavira is where you curate what appears here."
    let onRequestRemove: (PhotoEntry) -> Void
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
            if photos.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(photos, id: \.id) { entry in
                            NavigationLink(value: entry.id) {
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
                                    onRequestRemove(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, gridSpacing)
                }
                .background(CaviraTheme.backgroundPrimary)
            }
        }
    }
}
