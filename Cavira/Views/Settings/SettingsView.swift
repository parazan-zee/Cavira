import SwiftUI

struct SettingsView: View {
    var body: some View {
        Text("Settings placeholder")
            .font(CaviraTheme.Typography.body)
            .foregroundStyle(CaviraTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CaviraTheme.backgroundPrimary)
            .navigationTitle("Settings")
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Settings placeholder")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .caviraPreviewShell()
}
