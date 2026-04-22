import SwiftData
import SwiftUI

struct StoriesTab: View {
    @Query(sort: \Story.lastEditedDate, order: .reverse) private var stories: [Story]

    var body: some View {
        NavigationStack {
            StoriesListView()
                .navigationDestination(for: UUID.self) { id in
                    if let story = stories.first(where: { $0.id == id }) {
                        StoryViewerView(story: story)
                    } else {
                        ContentUnavailableView(
                            "Unavailable",
                            systemImage: "film",
                            description: Text("This story is no longer here.")
                        )
                        .foregroundStyle(CaviraTheme.textSecondary)
                    }
                }
        }
    }
}

#Preview {
    StoriesTab()
        .caviraPreviewShell()
}
