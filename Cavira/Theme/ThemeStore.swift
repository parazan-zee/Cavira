import Observation
import SwiftUI

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var palette: ThemePalette = .ranger

    func apply(_ palette: ThemePalette) {
        self.palette = palette
        CaviraTheme.setActivePalette(palette)
        CaviraTheme.applyGlobalChrome()
    }
}

