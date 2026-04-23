import SwiftUI
import UIKit

/// Cavira visual tokens. Default palette is **Ranger**.
enum CaviraTheme {

    // MARK: - Palette plumbing

    private struct PaletteTokens {
        let backgroundPrimary: Color
        let backgroundSecondary: Color

        let surfaceCard: Color
        let surfaceElevated: Color
        let surfacePhoto: Color

        let accent: Color
        let accentPressed: Color
        let accentSubtle: Color

        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let textOnAccent: Color

        let border: Color
        let borderStrong: Color

        let destructive: Color
        let success: Color
        let pinBadge: Color

        let photoScrim: Color
        let barBackground: Color
        let cardShadowColor: Color
    }

    /// Current palette used by all token getters.
    /// Updated via `ThemeStore.apply(_)` when user changes Theme in Settings.
    private static var activePalette: ThemePalette = .ranger

    static func setActivePalette(_ palette: ThemePalette) {
        activePalette = palette
    }

    private static var tokens: PaletteTokens {
        // NOTE: Colors are intentionally centralized here. UI/layout stays identical; only palettes change.
        switch activePalette {
        case .ranger:
            return PaletteTokens(
                backgroundPrimary: Color(hex: "#2B2A20"),
                backgroundSecondary: Color(hex: "#332F23"),
                surfaceCard: Color(hex: "#4E4936"),
                surfaceElevated: Color(hex: "#6B6448"),
                surfacePhoto: Color(hex: "#3D3828"),
                accent: Color(hex: "#D4B96A"),
                accentPressed: Color(hex: "#B8994E"),
                accentSubtle: Color(hex: "#D4B96A").opacity(0.15),
                textPrimary: Color(hex: "#E2D5B0"),
                textSecondary: Color(hex: "#C4B48A"),
                textTertiary: Color(hex: "#8B8060"),
                textOnAccent: Color(hex: "#2B2A20"),
                border: Color(hex: "#4E4936"),
                borderStrong: Color(hex: "#6B6448"),
                destructive: Color(hex: "#E05C4A"),
                success: Color(hex: "#7FAF68"),
                pinBadge: Color(hex: "#D4B96A"),
                photoScrim: Color.black.opacity(0.45),
                barBackground: Color(hex: "#1A1912"),
                cardShadowColor: Color.black.opacity(0.35)
            )
        case .cloud:
            // Pure white base, warm off-white surfaces, ink black accent.
            return PaletteTokens(
                backgroundPrimary: Color(hex: "#FFFFFF"),
                backgroundSecondary: Color(hex: "#F4F1EA"),
                surfaceCard: Color(hex: "#EEE9DF"),
                surfaceElevated: Color(hex: "#E6E0D4"),
                surfacePhoto: Color(hex: "#F0ECE3"),
                accent: Color(hex: "#111111"),
                accentPressed: Color(hex: "#000000"),
                accentSubtle: Color(hex: "#111111").opacity(0.10),
                textPrimary: Color(hex: "#141414"),
                textSecondary: Color(hex: "#2C2C2C"),
                textTertiary: Color(hex: "#6A6A6A"),
                textOnAccent: Color(hex: "#FFFFFF"),
                border: Color(hex: "#E1DBCF"),
                borderStrong: Color(hex: "#D2CBBE"),
                destructive: Color(hex: "#C13E33"),
                success: Color(hex: "#2F7D3B"),
                pinBadge: Color(hex: "#111111"),
                photoScrim: Color.black.opacity(0.18),
                barBackground: Color(hex: "#FFFFFF"),
                cardShadowColor: Color.black.opacity(0.12)
            )
        case .midnight:
            // Pure black base, near-black surfaces, white accent.
            return PaletteTokens(
                backgroundPrimary: Color(hex: "#000000"),
                backgroundSecondary: Color(hex: "#0B0B0B"),
                surfaceCard: Color(hex: "#121212"),
                surfaceElevated: Color(hex: "#1A1A1A"),
                surfacePhoto: Color(hex: "#0F0F0F"),
                accent: Color(hex: "#F4F4F4"),
                accentPressed: Color(hex: "#D9D9D9"),
                accentSubtle: Color(hex: "#F4F4F4").opacity(0.12),
                textPrimary: Color(hex: "#F2F2F2"),
                textSecondary: Color(hex: "#D6D6D6"),
                textTertiary: Color(hex: "#8B8B8B"),
                textOnAccent: Color(hex: "#000000"),
                border: Color(hex: "#1C1C1C"),
                borderStrong: Color(hex: "#2A2A2A"),
                destructive: Color(hex: "#E05C4A"),
                success: Color(hex: "#7FAF68"),
                pinBadge: Color(hex: "#F4F4F4"),
                photoScrim: Color.black.opacity(0.55),
                barBackground: Color(hex: "#000000"),
                cardShadowColor: Color.black.opacity(0.45)
            )
        case .arctic:
            // Deep navy base, midnight blue surfaces, sky blue accent.
            return PaletteTokens(
                backgroundPrimary: Color(hex: "#0B1626"),
                backgroundSecondary: Color(hex: "#0F1D33"),
                surfaceCard: Color(hex: "#12243F"),
                surfaceElevated: Color(hex: "#162B4B"),
                surfacePhoto: Color(hex: "#0F1F35"),
                accent: Color(hex: "#5FA8FF"),
                accentPressed: Color(hex: "#3E8FF2"),
                accentSubtle: Color(hex: "#5FA8FF").opacity(0.14),
                textPrimary: Color(hex: "#E6F0FF"),
                textSecondary: Color(hex: "#C8DAF7"),
                textTertiary: Color(hex: "#7F97B8"),
                textOnAccent: Color(hex: "#0B1626"),
                border: Color(hex: "#1A2D4D"),
                borderStrong: Color(hex: "#244066"),
                destructive: Color(hex: "#FF6B5A"),
                success: Color(hex: "#7FD39A"),
                pinBadge: Color(hex: "#5FA8FF"),
                photoScrim: Color.black.opacity(0.48),
                barBackground: Color(hex: "#08111E"),
                cardShadowColor: Color.black.opacity(0.40)
            )
        case .ember:
            // Deep espresso base, burnt sienna surfaces, vivid orange accent.
            return PaletteTokens(
                backgroundPrimary: Color(hex: "#1A120D"),
                backgroundSecondary: Color(hex: "#21160F"),
                surfaceCard: Color(hex: "#2A1B12"),
                surfaceElevated: Color(hex: "#352114"),
                surfacePhoto: Color(hex: "#24170F"),
                accent: Color(hex: "#FF8A3D"),
                accentPressed: Color(hex: "#E8742E"),
                accentSubtle: Color(hex: "#FF8A3D").opacity(0.14),
                textPrimary: Color(hex: "#F4E7DD"),
                textSecondary: Color(hex: "#E2CFC1"),
                textTertiary: Color(hex: "#A58B78"),
                textOnAccent: Color(hex: "#1A120D"),
                border: Color(hex: "#3A2416"),
                borderStrong: Color(hex: "#4A2D1B"),
                destructive: Color(hex: "#FF6B5A"),
                success: Color(hex: "#7FD39A"),
                pinBadge: Color(hex: "#FF8A3D"),
                photoScrim: Color.black.opacity(0.50),
                barBackground: Color(hex: "#120C08"),
                cardShadowColor: Color.black.opacity(0.45)
            )
        }
    }

    // MARK: — Backgrounds

    static var backgroundPrimary: Color { tokens.backgroundPrimary }
    static var backgroundSecondary: Color { tokens.backgroundSecondary }

    // MARK: — Surfaces

    static var surfaceCard: Color { tokens.surfaceCard }
    static var surfaceElevated: Color { tokens.surfaceElevated }
    static var surfacePhoto: Color { tokens.surfacePhoto }

    // MARK: — Accent

    static var accent: Color { tokens.accent }
    static var accentPressed: Color { tokens.accentPressed }
    static var accentSubtle: Color { tokens.accentSubtle }

    // MARK: — Text

    static var textPrimary: Color { tokens.textPrimary }
    static var textSecondary: Color { tokens.textSecondary }
    static var textTertiary: Color { tokens.textTertiary }
    static var textOnAccent: Color { tokens.textOnAccent }

    // MARK: — Borders & Dividers

    static var border: Color { tokens.border }
    static var borderStrong: Color { tokens.borderStrong }

    // MARK: — Semantic

    static var destructive: Color { tokens.destructive }
    static var success: Color { tokens.success }
    static var pinBadge: Color { tokens.pinBadge }

    // MARK: — Overlays

    static var photoScrim: Color { tokens.photoScrim }
    static var barBackground: Color { tokens.barBackground }

    // MARK: — Shadows

    static var cardShadowColor: Color { tokens.cardShadowColor }

    // MARK: — Typography (system; keep scale consistent across palettes)

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
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(barBackground)
        tabBarAppearance.shadowColor = UIColor(border)
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(accent)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(accent),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(textTertiary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(textTertiary),
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
        ]
        tabBarAppearance.stackedLayoutAppearance.selected.badgeBackgroundColor = .clear
        tabBarAppearance.selectionIndicatorTintColor = .clear

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(backgroundPrimary)
        navAppearance.shadowColor = UIColor(border)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(textPrimary),
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(accent)

        // Segmented controls (used in Home toolbar).
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
