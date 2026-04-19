import SwiftUI

/// Matches the **Calendar** tab “new” control: accent + tertiary ring **`plus.circle.fill`**.
struct AlbumImportToolbarButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(CaviraTheme.accent, CaviraTheme.textTertiary)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
