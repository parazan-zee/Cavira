import SwiftUI

struct SearchView: View {
    var body: some View {
        Text("Search placeholder")
            .font(CaviraTheme.Typography.body)
            .foregroundStyle(CaviraTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CaviraTheme.backgroundPrimary)
            .navigationTitle("Search")
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Search placeholder")
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .caviraPreviewShell()
}
