import SwiftUI

/// Placeholder list. **Product:** horizontal shelf of cards + toolbar `+` (Phase 9 — see `archeticturedoc.md`).
struct StoriesListView: View {
    var body: some View {
        Text("No stories yet")
            .font(CaviraTheme.Typography.body)
            .foregroundStyle(CaviraTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CaviraTheme.backgroundPrimary)
            .navigationTitle("Stories")
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Stories, no stories yet")
    }
}

#Preview {
    NavigationStack {
        StoriesListView()
    }
    .caviraPreviewShell()
}
