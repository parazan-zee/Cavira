import SwiftData
import SwiftUI
import UIKit

@main
struct CaviraApp: App {
    /// `let` avoids extra `State` invalidation; `RootView` re-injects into the `TabView` subtree.
    private let appServices = AppServices()

    init() {
        applyAppearance()
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

    private func applyAppearance() {

        // MARK: Tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(CaviraTheme.barBackground)

        // Top border divider line
        tabBarAppearance.shadowColor = UIColor(CaviraTheme.border)

        // Active tab — accent colour icon and label
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(CaviraTheme.accent)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(CaviraTheme.accent),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]

        // Inactive tab — muted tertiary colour
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(CaviraTheme.textTertiary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(CaviraTheme.textTertiary),
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
        ]

        // Remove the default selection indicator (no pill, no background shape)
        tabBarAppearance.stackedLayoutAppearance.selected.badgeBackgroundColor = .clear
        tabBarAppearance.selectionIndicatorTintColor = .clear

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // MARK: Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(CaviraTheme.backgroundPrimary)
        navAppearance.shadowColor = UIColor(CaviraTheme.border)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(CaviraTheme.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(CaviraTheme.textPrimary),
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(CaviraTheme.accent)
    }
}

