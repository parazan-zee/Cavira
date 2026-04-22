import SwiftData
import SwiftUI

struct SearchTab: View {
    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    var body: some View {
        NavigationStack {
            SearchView()
                .navigationDestination(for: UUID.self) { id in
                    if let entry = photos.first(where: { $0.id == id }) {
                        PhotoDetailView(entry: entry)
                    } else if let event = events.first(where: { $0.id == id }) {
                        EventDetailView(event: event)
                    } else {
                        ContentUnavailableView(
                            "Unavailable",
                            systemImage: "photo",
                            description: Text("This content is no longer here.")
                        )
                        .foregroundStyle(CaviraTheme.textSecondary)
                    }
                }
        }
    }
}

#Preview {
    SearchTab()
        .caviraPreviewShell()
}
