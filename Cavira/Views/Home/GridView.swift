import SwiftUI

struct GridView: View {
    let photos: [PhotoEntry]
    /// Shown when `photos` is empty (e.g. Videos-only mode uses different copy when the album has photos but no videos).
    var emptyTitle: String = "Import your media to start"
    var emptySubtitle: String? = "Your album stays in Apple Photos; Cavira is where you curate what appears here."
    let onRequestRemove: (PhotoEntry) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        Group {
            if photos.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos, id: \.id) { entry in
                            NavigationLink(value: entry.id) {
                                PhotoThumbnailView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove from album", systemImage: "rectangle.badge.minus", role: .destructive) {
                                    onRequestRemove(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 0)
                }
                .background(CaviraTheme.backgroundPrimary)
            }
        }
    }
}
