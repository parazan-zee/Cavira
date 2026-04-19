import SwiftData
import SwiftUI

struct EventsTab: View {
    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    var body: some View {
        NavigationStack {
            EventsListView()
                .navigationDestination(for: UUID.self) { id in
                    if let event = events.first(where: { $0.id == id }) {
                        EventDetailView(event: event)
                    } else if let entry = photos.first(where: { $0.id == id }) {
                        PhotoDetailView(entry: entry)
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
    EventsTab()
        .caviraPreviewShell()
}
