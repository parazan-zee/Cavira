import SwiftData
import SwiftUI

/// Root shell: tab bar, first-run `AppSettings`, and services in the environment.
struct RootView: View {
    /// Injected from `CaviraApp` (and previews); pushed into the `TabView` subtree explicitly
    /// so every tab / `NavigationStack` sees `AppServices` reliably.
    let appServices: AppServices

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            CaviraTheme.backgroundPrimary.ignoresSafeArea()
            TabView {
                HomeTab()
                    .tabItem { Label("Home", systemImage: "house") }

                CalendarTab()
                    .tabItem { Label("Calendar", systemImage: "calendar") }

                StoriesTab()
                    .tabItem { Label("Stories", systemImage: "film") }

                SearchTab()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                SettingsTab()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.appServices, appServices)
        .tint(CaviraTheme.accent)
        .onAppear {
            _ = DataService.getOrCreateSettings(context: modelContext)
            DataService.migrateEventsToStoriesIfNeeded(context: modelContext)
            Task {
                await appServices.photoLibrary.requestAuthorization()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appServices.photoLibrary.refreshAuthorizationStatus()
        }
    }
}

#Preview {
    RootView(appServices: AppServices())
        .caviraPreviewContainer()
}
