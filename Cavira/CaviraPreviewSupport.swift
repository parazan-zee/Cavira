import SwiftData
import SwiftUI

/// Shared in-memory SwiftData container + `AppServices` for SwiftUI previews.
enum CaviraPreviewSupport {
    static let inMemoryContainer: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: PhotoEntry.self,
            Event.self,
            Story.self,
            StorySlide.self,
            LocationTag.self,
            PersonTag.self,
            AppSettings.self,
            configurations: configuration
        )
    }()
}

extension View {
    /// In-memory SwiftData only (e.g. `RootView` preview, which injects `AppServices` itself).
    func caviraPreviewContainer() -> some View {
        modelContainer(CaviraPreviewSupport.inMemoryContainer)
    }

    /// Model container + `AppServices` for leaf tab/screen previews that are not wrapped in `RootView`.
    func caviraPreviewShell() -> some View {
        caviraPreviewContainer()
            .environment(\.appServices, AppServices())
    }
}
