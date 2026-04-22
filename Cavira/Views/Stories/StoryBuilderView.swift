import SwiftData
import SwiftUI

/// Phase 9 builder entry point (implemented in sub-steps).
struct StoryBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SlidePickerView { selectedEntries in
                let sorted = selectedEntries.sorted { $0.capturedDate < $1.capturedDate }
                return StoryDraftEditorView(selectedEntries: sorted) { dismiss() }
            }
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    StoryBuilderView()
        .caviraPreviewShell()
}

struct StorySaveView: View {
    @Environment(\.modelContext) private var modelContext

    let draftSlides: [StorySlide]
    let onFinish: () -> Void

    @State private var titleText: String = ""
    @State private var coverPhotoId: UUID?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: CaviraTheme.Spacing.md) {
            Form {
                Section {
                    TextField("Story title", text: $titleText)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(CaviraTheme.textPrimary)

                    Text("Give this story a short name so you can find it later.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Title")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(draftSlides.compactMap(\.photo), id: \.id) { entry in
                                Button {
                                    coverPhotoId = entry.id
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        PhotoThumbnailView(entry: entry)
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(
                                                        (coverPhotoId ?? defaultCoverID) == entry.id ? CaviraTheme.accent : .clear,
                                                        lineWidth: 2
                                                    )
                                            )

                                        if (coverPhotoId ?? defaultCoverID) == entry.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(CaviraTheme.accent, .black.opacity(0.35))
                                                .padding(6)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Text("Cover defaults to the first slide. Tap to change.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                } header: {
                    Text("Cover")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)

            Spacer(minLength: 0)
        }
        .background(CaviraTheme.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {}
                    .disabled(true)
                    .hidden()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") {
                    saveStory()
                }
                .foregroundStyle(CaviraTheme.accent)
                .disabled(isSaving || trimmedTitle.isEmpty || draftSlides.isEmpty)
            }
        }
        .onAppear {
            coverPhotoId = defaultCoverID
        }
    }

    private var trimmedTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultCoverID: UUID? {
        draftSlides.first?.photo?.id
    }

    @MainActor
    private func saveStory() {
        guard !isSaving else { return }
        let title = trimmedTitle
        guard !title.isEmpty else { return }

        isSaving = true
        let story = Story(
            title: title,
            coverPhotoId: coverPhotoId ?? defaultCoverID,
            createdDate: .now,
            lastEditedDate: .now
        )
        modelContext.insert(story)

        for (idx, slide) in draftSlides.enumerated() {
            slide.order = idx
            slide.story = story
            modelContext.insert(slide)
        }

        try? modelContext.save()
        isSaving = false
        onFinish()
    }
}

