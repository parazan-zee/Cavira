import SwiftUI

struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}

#Preview {
    SettingsTab()
        .caviraPreviewShell()
}
