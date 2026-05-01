import SwiftUI

struct ThemePickerSheet: View {
    let selected: ThemePalette
    let onSelect: (ThemePalette) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(ThemePalette.allCases) { palette in
                    Button {
                        onSelect(palette)
                    } label: {
                        HStack(spacing: 12) {
                            themeSwatch(palette.themePickerSwatchColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(palette.displayName)
                                    .foregroundStyle(CaviraTheme.textPrimary)
                                Text(paletteSubtitle(palette))
                                    .font(CaviraTheme.Typography.caption)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                            }
                            Spacer(minLength: 0)
                            if palette == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CaviraTheme.accent)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(CaviraTheme.surfaceCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
            }
        }
    }

    private func themeSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(CaviraTheme.border, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private func paletteSubtitle(_ palette: ThemePalette) -> String {
        switch palette {
        case .ranger:
            return "Deep olive base, warm gold accents"
        case .cloud:
            return "Pure white base, ink black accent"
        case .midnight:
            return "Pure black base, white accent"
        case .arctic:
            return "Deep navy base, sky blue accent"
        case .ember:
            return "Deep espresso base, vivid orange accent"
        }
    }
}

#Preview {
    ThemePickerSheet(selected: .ranger, onSelect: { _ in }, onCancel: {})
        .caviraPreviewShell()
}

