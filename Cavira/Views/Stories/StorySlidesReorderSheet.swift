import SwiftUI

struct StorySlidesReorderSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var slides: [StorySlide]
    @Binding var currentIndex: Int

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(slides.enumerated()), id: \.element.id) { idx, slide in
                    HStack(spacing: 12) {
                        if let entry = slide.photo {
                            PhotoThumbnailView(entry: entry)
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(CaviraTheme.surfacePhoto)
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(CaviraTheme.textTertiary)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Slide \(idx + 1)")
                                .font(CaviraTheme.Typography.body.weight(.semibold))
                                .foregroundStyle(CaviraTheme.textPrimary)
                            if let entry = slide.photo {
                                Text(entry.capturedDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(CaviraTheme.Typography.caption)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(CaviraTheme.surfaceCard)
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Reorder slides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaviraTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        let selectedSlide = slides[safe: currentIndex]
        slides.move(fromOffsets: source, toOffset: destination)
        for (idx, slide) in slides.enumerated() {
            slide.order = idx
        }
        if let selectedSlide, let newIdx = slides.firstIndex(where: { $0.id == selectedSlide.id }) {
            currentIndex = newIdx
        } else {
            currentIndex = min(currentIndex, max(slides.count - 1, 0))
        }
    }
}

private extension Array {
    subscript(safe idx: Int) -> Element? {
        guard idx >= 0, idx < count else { return nil }
        return self[idx]
    }
}

#Preview {
    NavigationStack {
        StorySlidesReorderSheet(slides: .constant([]), currentIndex: .constant(0))
    }
    .caviraPreviewShell()
}

