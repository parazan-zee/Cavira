import SwiftData
import SwiftUI

struct SearchTab: View {
    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]
    @Query(sort: \HomeCollection.createdDate, order: .reverse) private var homeCollections: [HomeCollection]

    var body: some View {
        NavigationStack {
            SearchView()
                .navigationDestination(for: SearchBrowseDestination.self) { dest in
                    switch dest {
                    case .photo(let id):
                        if let entry = photos.first(where: { $0.id == id }) {
                            PhotoDetailView(entry: entry)
                        } else {
                            ContentUnavailableView(
                                "Unavailable",
                                systemImage: "photo",
                                description: Text("This content is no longer here.")
                            )
                            .foregroundStyle(CaviraTheme.textSecondary)
                        }
                    case .collection(let id):
                        if let collection = homeCollections.first(where: { $0.id == id }) {
                            HomeCollectionViewer(collection: collection)
                        } else {
                            ContentUnavailableView(
                                "Unavailable",
                                systemImage: "square.stack",
                                description: Text("This collection is no longer here.")
                            )
                            .foregroundStyle(CaviraTheme.textSecondary)
                        }
                    }
                }
        }
    }
}

#Preview {
    SearchTab()
        .caviraPreviewShell()
}
