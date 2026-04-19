import SwiftUI

struct EmptyStateView: View {
    var systemImage: String = "photo.on.rectangle"
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: CaviraTheme.Spacing.sm + CaviraTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(CaviraTheme.textTertiary)
            Text(title)
                .font(CaviraTheme.Typography.headline)
                .foregroundStyle(CaviraTheme.textSecondary)
                .multilineTextAlignment(.center)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(CaviraTheme.Typography.body)
                    .foregroundStyle(CaviraTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(
        title: "Import your media to start",
        subtitle: "Items stay in Apple Photos; Cavira is your curated album."
    )
}
