import SwiftData
import SwiftUI

/// Root shell: tab bar, first-run `AppSettings`, and services in the environment.
struct RootView: View {
    /// Injected from `CaviraApp` (and previews); pushed into the `TabView` subtree explicitly
    /// so every tab / `NavigationStack` sees `AppServices` reliably.
    let appServices: AppServices

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            CaviraTheme.backgroundPrimary.ignoresSafeArea()
            TabView(selection: $selectedTab) {

                HomeTab()
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                    .tag(0)

                CalendarTab()
                    .tabItem {
                        Label(
                            "Calendar",
                            systemImage: selectedTab == 1 ? "calendar.circle.fill" : "calendar.circle"
                        )
                    }
                    .tag(1)

                StoriesTab()
                    .tabItem {
                        Label("Stories", systemImage: selectedTab == 2 ? "film.fill" : "film")
                    }
                    .tag(2)

                SearchTab()
                    .tabItem {
                        Label(
                            "Search",
                            systemImage: selectedTab == 3 ? "magnifyingglass.circle.fill" : "magnifyingglass.circle"
                        )
                    }
                    .tag(3)

                SettingsTab()
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    }
                    .tag(4)
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
