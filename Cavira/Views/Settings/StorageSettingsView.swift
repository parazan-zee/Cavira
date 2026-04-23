import SwiftData
import SwiftUI

struct StorageSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                systemImage: "externaldrive",
                title: "No stored copies",
                subtitle: "Cavira is not storing duplicate photo files on this device."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        StorageSettingsView()
    }
    .caviraPreviewShell()
}

