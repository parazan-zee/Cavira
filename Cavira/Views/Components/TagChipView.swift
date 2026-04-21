import SwiftUI

struct TagChipView: View {
    var label: String
    var systemImage: String? = nil
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: CaviraTheme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CaviraTheme.textSecondary)
            }
            Text(label)
                .font(CaviraTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(CaviraTheme.textPrimary)
                .lineLimit(1)

            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(label)")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(CaviraTheme.surfaceCard.opacity(0.65), in: Capsule())
        .overlay(
            Capsule()
                .stroke(CaviraTheme.border, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        TagChipView(label: "London", systemImage: "mappin.and.ellipse")
        TagChipView(label: "Aisha", systemImage: "person.fill") {}
    }
    .padding()
    .background(CaviraTheme.backgroundPrimary)
}

