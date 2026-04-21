import SwiftUI
import UIKit

/// **Ranger** visual tokens for Cavira. **Hex values are fixed** — do not change without an explicit design pass (`ranger_theme.md` + this file).
enum CaviraTheme {

    // MARK: — Backgrounds

    static let backgroundPrimary = Color(hex: "#2B2A20")
    static let backgroundSecondary = Color(hex: "#332F23")

    // MARK: — Surfaces

    static let surfaceCard = Color(hex: "#4E4936")
    static let surfaceElevated = Color(hex: "#6B6448")
    static let surfacePhoto = Color(hex: "#3D3828")

    // MARK: — Accent

    static let accent = Color(hex: "#D4B96A")
    static let accentPressed = Color(hex: "#B8994E")
    static let accentSubtle = Color(hex: "#D4B96A").opacity(0.15)

    // MARK: — Text

    static let textPrimary = Color(hex: "#E2D5B0")
    static let textSecondary = Color(hex: "#C4B48A")
    static let textTertiary = Color(hex: "#8B8060")
    static let textOnAccent = Color(hex: "#2B2A20")

    // MARK: — Borders & Dividers

    static let border = Color(hex: "#4E4936")
    static let borderStrong = Color(hex: "#6B6448")

    // MARK: — Semantic

    static let destructive = Color(hex: "#E05C4A")
    static let success = Color(hex: "#7FAF68")
    static let pinBadge = Color(hex: "#D4B96A")

    // MARK: — Overlays

    static let photoScrim = Color.black.opacity(0.45)
    static let barBackground = Color(hex: "#1A1912")

    // MARK: — Shadows

    static let cardShadowColor = Color.black.opacity(0.35)

    // MARK: — Typography (system; matches `ranger_theme.md` scale)

    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .semibold, design: .default)
        static let title = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 16, weight: .medium, design: .default)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
        static let micro = Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: — Corner radii

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: — Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: — Global UIKit chrome (tab bar, navigation bar, segmented control)

    /// Call once at launch (`CaviraApp.init`). **v1:** single dark Ranger skin; revisit in Phase 12 if SwiftUI-only chrome is desired.
    static func applyGlobalChrome() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(barBackground)
        tabBar.stackedLayoutAppearance.selected.iconColor = UIColor(accent)
        tabBar.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(accent)]
        tabBar.stackedLayoutAppearance.normal.iconColor = UIColor(textTertiary)
        tabBar.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(textTertiary)]
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(barBackground)
        nav.titleTextAttributes = [.foregroundColor: UIColor(textPrimary)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(textPrimary)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(accent)

        // Match tab bar semantics: unselected = light text, selected = accent.
        // We keep a dark selected pill for contrast (instead of accent pill + dark text).
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(barBackground)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(accent)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(textPrimary)],
            for: .normal
        )
        UISegmentedControl.appearance().backgroundColor = UIColor(surfaceCard)

        UITableView.appearance().backgroundColor = UIColor(backgroundPrimary)
    }
}

// MARK: — Hex colour initialiser (tokens only; no ad-hoc hex elsewhere)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
