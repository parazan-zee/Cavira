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
    @State private var showMissingCleanupAlert = false
    @State private var missingCleanupCount: Int = 0

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
                runMissingHomeCleanupIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appServices.photoLibrary.refreshAuthorizationStatus()
            runMissingHomeCleanupIfNeeded()
        }
        .alert("Some items were removed", isPresented: $showMissingCleanupAlert) {
            Button("OK", role: .cancel) {
                let runStamp = UserDefaults.standard.double(forKey: Self.missingCleanupLastRunKey)
                UserDefaults.standard.set(runStamp, forKey: Self.missingCleanupLastShownKey)
            }
        } message: {
            Text("We removed \(missingCleanupCount) item\(missingCleanupCount == 1 ? "" : "s") from Home because they’re no longer in your Photos library. Stories keep a small preview so your story layout remains intact.")
        }
    }

    private static let missingCleanupLastRunKey = "cavira.missingCleanupLastRun"
    private static let missingCleanupLastShownKey = "cavira.missingCleanupLastShown"

    @MainActor
    private func runMissingHomeCleanupIfNeeded() {
        switch appServices.photoLibrary.authorizationStatus {
        case .authorized, .limited:
            break
        default:
            return
        }

        let removed = DataService.removeMissingFromHomeAlbumIfNeeded(
            context: modelContext,
            photoLibrary: appServices.photoLibrary
        )
        guard removed > 0 else { return }

        missingCleanupCount = removed
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: Self.missingCleanupLastRunKey)

        let lastShown = UserDefaults.standard.double(forKey: Self.missingCleanupLastShownKey)
        if lastShown != now {
            showMissingCleanupAlert = true
        }
    }
}

#Preview {
    RootView(appServices: AppServices())
        .caviraPreviewContainer()
}
