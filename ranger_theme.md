# Cavira — Ranger theme (design reference)

**Canonical implementation:** `Cavira/Theme/CaviraTheme.swift` (`CaviraTheme`). **Hex values in code must match this document exactly** — no informal rounding or “close enough” swaps.

The block below is the **original Cursor prompt** (historical **Folio** working name). Treat **`CaviraTheme`** as the real type name in the Cavira repo.

---

Copy and paste the following prompt directly into Cursor:

---

```
Create a file called CaviraTheme.swift inside a new folder called Theme/ under the Cavira app target.

This file defines the entire visual identity of the app. Every view, button, label, background, and control must reference these tokens — never use hardcoded colours anywhere else in the project.

## CaviraTheme.swift

```swift
import SwiftUI

struct CaviraTheme {

    // MARK: — Backgrounds
    /// Main app background — the darkest layer, behind everything
    static let backgroundPrimary   = Color(hex: "#2B2A20")
    /// Secondary background — used for sheets, bottom sheets, tab bar
    static let backgroundSecondary = Color(hex: "#332F23")

    // MARK: — Surfaces
    /// Cards, list rows, event cards, story cards
    static let surfaceCard         = Color(hex: "#4E4936")
    /// Elevated surfaces — selected states, active cells, popovers
    static let surfaceElevated     = Color(hex: "#6B6448")
    /// Photo grid cell placeholder background
    static let surfacePhoto        = Color(hex: "#3D3828")

    // MARK: — Accent
    /// Primary accent — FAB, primary buttons, selected tab indicator, active toggles, progress bars
    static let accent              = Color(hex: "#D4B96A")
    /// Accent when pressed / tapped
    static let accentPressed       = Color(hex: "#B8994E")
    /// Accent used as a very subtle tint on backgrounds (e.g. selected cell overlay)
    static let accentSubtle        = Color(hex: "#D4B96A").opacity(0.15)

    // MARK: — Text
    /// Primary text — headings, body, photo dates, event titles
    static let textPrimary         = Color(hex: "#E2D5B0")
    /// Secondary text — subtitles, metadata, photo counts, timestamps
    static let textSecondary       = Color(hex: "#C4B48A")
    /// Tertiary text — placeholders, hints, disabled labels
    static let textTertiary        = Color(hex: "#8B8060")
    /// Text that sits ON the accent colour (e.g. inside a filled accent button)
    static let textOnAccent        = Color(hex: "#2B2A20")

    // MARK: — Borders & Dividers
    /// Default border for cards, cells, input fields
    static let border              = Color(hex: "#4E4936")
    /// Stronger border — focused inputs, selected cards
    static let borderStrong        = Color(hex: "#6B6448")

    // MARK: — Semantic
    /// Destructive actions — delete buttons, remove from event
    static let destructive         = Color(hex: "#E05C4A")
    /// Success states — import complete checkmark, saved indicator
    static let success             = Color(hex: "#7FAF68")
    /// Pin badge colour
    static let pinBadge            = Color(hex: "#D4B96A")

    // MARK: — Overlays
    /// Semi-transparent overlay on photos for text readability (story viewer gradient, photo detail scrim)
    static let photoScrim          = Color.black.opacity(0.45)
    /// Tab bar / nav bar background
    static let barBackground       = Color(hex: "#1A1912")

    // MARK: — Typography
    struct Font {
        /// Large titles — screen headers, event names
        static let largeTitle  = SwiftUI.Font.system(size: 28, weight: .semibold, design: .default)
        /// Section titles — month headers in timeline, story titles
        static let title       = SwiftUI.Font.system(size: 20, weight: .semibold, design: .default)
        /// Card titles, event card names
        static let headline    = SwiftUI.Font.system(size: 16, weight: .medium, design: .default)
        /// Body text, notes, descriptions
        static let body        = SwiftUI.Font.system(size: 15, weight: .regular, design: .default)
        /// Metadata — dates, photo counts, tag chips
        static let caption     = SwiftUI.Font.system(size: 13, weight: .regular, design: .default)
        /// Smallest labels — timestamps, file sizes
        static let micro       = SwiftUI.Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: — Corner Radii
    struct Radius {
        static let small   : CGFloat = 6    // tag chips, small badges
        static let medium  : CGFloat = 10   // buttons, input fields, photo cells in lists
        static let large   : CGFloat = 16   // cards, sheets, event cards, story cards
        static let xl      : CGFloat = 24   // bottom sheets, modal cards
        static let full    : CGFloat = 999  // FAB, circle buttons, story bubbles
    }

    // MARK: — Spacing
    struct Spacing {
        static let xs  : CGFloat = 4
        static let sm  : CGFloat = 8
        static let md  : CGFloat = 12
        static let lg  : CGFloat = 16
        static let xl  : CGFloat = 24
        static let xxl : CGFloat = 32
    }

    // MARK: — Shadows
    /// Subtle shadow for elevated cards
    static func cardShadow() -> some View {
        return Color.black.opacity(0.35)
    }
}

// MARK: — Hex colour initialiser
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
            (a, r, g, b) = (1, 1, 1, 0)
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
```

## Usage rules — apply these throughout every view you generate:

### Backgrounds
- Root view background: `.background(FolioTheme.backgroundPrimary)`
- Sheets and modals: `.background(FolioTheme.backgroundSecondary)`
- Tab bar and navigation bar: `FolioTheme.barBackground` via UITabBarAppearance / UINavigationBarAppearance

### Cards & Surfaces
- All cards (EventCardView, StoryCardView, list rows): `FolioTheme.surfaceCard` background with `FolioTheme.border` stroke at 0.5pt
- Selected or active cells: `FolioTheme.surfaceElevated`
- Photo grid placeholder (while loading): `FolioTheme.surfacePhoto`

### Buttons
- Primary filled button (e.g. "Import", "Save Story"):
  - Background: `FolioTheme.accent`
  - Label: `FolioTheme.textOnAccent`
  - Corner radius: `FolioTheme.Radius.medium`
  - Pressed state: `FolioTheme.accentPressed`
- FAB (floating action "+"):
  - Background: `FolioTheme.accent`
  - Icon: `FolioTheme.textOnAccent`
  - Size: 56×56, corner radius `FolioTheme.Radius.full`
  - Shadow: black 0.3 opacity, radius 8, y 4
- Destructive button (Delete, Remove):
  - Label colour: `FolioTheme.destructive`
  - No filled background — text-only or outlined
- Secondary / ghost button:
  - Border: `FolioTheme.borderStrong` at 1pt
  - Label: `FolioTheme.textSecondary`
  - Background: clear

### Text
- All screen titles and large headings: `FolioTheme.textPrimary` + `FolioTheme.Font.largeTitle`
- Section headers (e.g. "June 2024" in timeline): `FolioTheme.textPrimary` + `FolioTheme.Font.title`
- Card titles, event names: `FolioTheme.textPrimary` + `FolioTheme.Font.headline`
- Body / notes / descriptions: `FolioTheme.textPrimary` + `FolioTheme.Font.body`
- Dates, counts, metadata: `FolioTheme.textSecondary` + `FolioTheme.Font.caption`
- Placeholders and hints: `FolioTheme.textTertiary` + `FolioTheme.Font.caption`

### Tab Bar
Apply this in FolioApp.swift on launch:
```swift
let tabBarAppearance = UITabBarAppearance()
tabBarAppearance.configureWithOpaqueBackground()
tabBarAppearance.backgroundColor = UIColor(FolioTheme.barBackground)
tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(FolioTheme.accent)
tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(FolioTheme.accent)]
tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(FolioTheme.textTertiary)
tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(FolioTheme.textTertiary)]
UITabBar.appearance().standardAppearance = tabBarAppearance
UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
```

### Navigation Bar
Apply this in FolioApp.swift on launch:
```swift
let navAppearance = UINavigationBarAppearance()
navAppearance.configureWithOpaqueBackground()
navAppearance.backgroundColor = UIColor(FolioTheme.backgroundPrimary)
navAppearance.titleTextAttributes = [.foregroundColor: UIColor(FolioTheme.textPrimary)]
navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(FolioTheme.textPrimary)]
UINavigationBar.appearance().standardAppearance = navAppearance
UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
UINavigationBar.appearance().tintColor = UIColor(FolioTheme.accent)
```

### Inputs & Text Fields
- Background: `FolioTheme.surfaceCard`
- Border: `FolioTheme.border` at 0.5pt, `FolioTheme.borderStrong` when focused
- Text: `FolioTheme.textPrimary`
- Placeholder: `FolioTheme.textTertiary`
- Corner radius: `FolioTheme.Radius.medium`

### Tag Chips
- Background: `FolioTheme.surfaceElevated`
- Text: `FolioTheme.textSecondary`
- Remove button (×): `FolioTheme.textTertiary`
- Corner radius: `FolioTheme.Radius.small`

### Toggles & Switches
- Tint (on state): `FolioTheme.accent` via `.tint(FolioTheme.accent)`

### Progress & Loading
- ProgressView tint: `FolioTheme.accent`
- Story viewer progress bar: `FolioTheme.accent` fill on `FolioTheme.surfaceElevated` track

### Pin Badge
- Background: `FolioTheme.pinBadge`
- Icon: pin.fill SF Symbol in `FolioTheme.textOnAccent`
- Size: 20×20, corner radius `FolioTheme.Radius.full`

### Story Viewer
- Background: `.black`
- Photo: full bleed, `.scaledToFill`
- Gradient scrim at top and bottom: `LinearGradient` from `.black.opacity(0.6)` to `.clear`
- Text overlays on photos: white or user-chosen colour
- Progress bar background track: `Color.white.opacity(0.3)`
- Progress bar fill: `Color.white`
- Close button: SF Symbol `xmark` in white, 44×44 tap target

### Empty States
- Icon: SF Symbol, `FolioTheme.textTertiary`, font size 44
- Title: `FolioTheme.textSecondary` + `FolioTheme.Font.headline`
- Subtitle: `FolioTheme.textTertiary` + `FolioTheme.Font.body`

### Photo Grid Cells
- Spacing between cells: 2pt (tight, like Instagram)
- Loading placeholder: `FolioTheme.surfacePhoto` with a `photo` SF Symbol in `FolioTheme.textTertiary`
- Missing photo placeholder: `FolioTheme.surfaceCard` with `photo.badge.exclamationmark` in `FolioTheme.textTertiary`

Apply FolioTheme to every view from Phase 3 onwards. Do not use any hardcoded Color(), UIColor(), or hex value outside of FolioTheme.swift itself.
```
