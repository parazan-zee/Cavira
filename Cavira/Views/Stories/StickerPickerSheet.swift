import SwiftUI

struct StickerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onPick: (String) -> Void

    private let stickers: [String] = [
        "sun.max.fill",
        "heart.fill",
        "star.fill",
        "camera.fill",
        "map.fill",
        "airplane",
        "fork.knife",
        "figure.walk",
        "moonphase.full.moon",
        "cloud.sun.fill",
        "music.note",
        "flame.fill",
        "leaf.fill",
        "snowflake",
        "sparkles",
        "gift.fill",
        "graduationcap.fill",
        "party.popper.fill",
        "balloon.2.fill",
        "trophy.fill",
        "beach.umbrella.fill",
        "tram.fill",
        "mountain.2.fill",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(stickers, id: \.self) { name in
                        Button {
                            onPick(name)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(CaviraTheme.surfaceCard.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(CaviraTheme.border.opacity(0.7), lineWidth: 1)
                                    )
                                Image(systemName: name)
                                    .font(.system(size: 28))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(height: 68)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CaviraTheme.Spacing.md)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundPrimary)
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
    }
}

#Preview {
    StickerPickerSheet { _ in }
        .caviraPreviewShell()
}

