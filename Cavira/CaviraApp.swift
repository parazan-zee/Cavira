import SwiftData
import SwiftUI
import UIKit

@main
struct CaviraApp: App {
    /// `let` avoids extra `State` invalidation; `RootView` re-injects into the `TabView` subtree.
    private let appServices = AppServices()

    init() {
        CaviraTheme.applyGlobalChrome()
    }

    var body: some Scene {
        WindowGroup {
            RootView(appServices: appServices)
                .modelContainer(for: [
                    PhotoEntry.self,
                    Event.self,
                    Story.self,
                    StorySlide.self,
                    LocationTag.self,
                    PersonTag.self,
                    AppSettings.self,
                ])
        }
    }

    // UIKit chrome is configured in `CaviraTheme.applyGlobalChrome()` so it can be re-applied
    // when the user changes the theme palette.
}

