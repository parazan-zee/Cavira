import Foundation
import SwiftUI

enum StorageMode: String, Codable { case reference, localCopy }
/// Home header layout. **`.profile`** is kept for SwiftData / migration only.
enum HomeViewMode: String, Codable {
    case grid
    case timeline
    case videos
    /// Legacy value kept for SwiftData migration; not shown in the UI.
    case events
    case profile
}
enum AppearanceMode: String, Codable { case system, light, dark }

/// Visual theme palette (colors only). Default remains `.ranger`.
enum ThemePalette: String, Codable, CaseIterable, Identifiable {
    case ranger
    case cloud
    case midnight
    case arctic
    case ember

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ranger: return "Ranger"
        case .cloud: return "Cloud"
        case .midnight: return "Midnight"
        case .arctic: return "Arctic"
        case .ember: return "Ember"
        }
    }

    /// Default scheme that best matches the palette.
    var defaultColorScheme: ColorScheme {
        switch self {
        case .cloud:
            return .light
        default:
            return .dark
        }
    }

    /// Matches `CaviraTheme` accent; used for global `.tint()` (tab bar, controls).
    var swatchColor: Color {
        switch self {
        case .ranger: return Color(hex: "#D4B96A")
        case .cloud: return Color(hex: "#111111")
        case .midnight: return Color(hex: "#F4F4F4")
        case .arctic: return Color(hex: "#5FA8FF")
        case .ember: return Color(hex: "#FF8A3D")
        }
    }

    /// Small color chip in Settings / theme picker. Same as `swatchColor` except **Cloud** and
    /// **Midnight**, where the accent is black / off‑white and would read backwards beside the name;
    /// those use a typical surface tone instead.
    var themePickerSwatchColor: Color {
        switch self {
        case .cloud: return Color(hex: "#F4F1EA")
        case .midnight: return Color(hex: "#121212")
        default: return swatchColor
        }
    }
}

/// Library asset kind for a `PhotoEntry`. Live Photos use `.image` with `isLivePhoto == true`.
enum PhotoAssetKind: String, Codable {
    case image
    case video
}
