import SwiftData
import SwiftUI

/// Stories shelf: horizontal row of story cards + toolbar `+`.
struct StoriesListView: View {
    @Query(sort: \Story.lastEditedDate, order: .reverse) private var stories: [Story]
    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]

    @State private var showBuilder = false

    var body: some View {
        VStack(alignment: .leading, spacing: CaviraTheme.Spacing.md) {
            if stories.isEmpty {
                EmptyStateView(
                    systemImage: "film",
                    title: "No stories yet",
                    subtitle: "Create your first story from photos and videos in your Cavira album."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CaviraTheme.Spacing.md) {
                        ForEach(stories, id: \.id) { story in
                            NavigationLink(value: story.id) {
                                StoryCardView(story: story, allPhotos: photos)
                            }
                            .buttonStyle(.plain)

                            if story.id != stories.last?.id {
                                Rectangle()
                                    .fill(CaviraTheme.border.opacity(0.6))
                                    .frame(width: 1, height: 260)
                                    .padding(.vertical, 28)
                            }
                        }
                    }
                    .padding(.horizontal, CaviraTheme.Spacing.md)
                    .padding(.vertical, CaviraTheme.Spacing.md)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Stories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBuilder = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(CaviraTheme.accent, CaviraTheme.surfaceCard.opacity(0.35))
                }
                .accessibilityLabel("New story")
            }
        }
        .sheet(isPresented: $showBuilder) {
            StoryBuilderView()
        }
    }
}

#Preview {
    NavigationStack {
        StoriesListView()
    }
    .caviraPreviewShell()
}

private struct StoryCardView: View {
    let story: Story
    let allPhotos: [PhotoEntry]

    @Environment(\.appServices) private var appServices
    @State private var cover: UIImage?

    private var coverEntry: PhotoEntry? {
        if let coverID = story.coverPhotoId,
           let match = allPhotos.first(where: { $0.id == coverID }) {
            return match
        }
        return story.orderedSlides.first?.photo
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CaviraTheme.surfaceCard)

            Group {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            CaviraTheme.surfacePhoto,
                            CaviraTheme.surfaceCard,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            LinearGradient(
                colors: [
                    .black.opacity(0.55),
                    .black.opacity(0.2),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(14)
        }
        .frame(width: 220, height: 320)
        .clipped()
        .task(id: story.id) {
            await loadCover()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Story, \(story.title)")
    }

    private var subtitleText: String {
        let count = story.slides.count
        if count == 1 { return "1 slide" }
        return "\(count) slides"
    }

    @MainActor
    private func loadCover() async {
        guard let entry = coverEntry else {
            cover = nil
            return
        }
        guard let loader = appServices?.photoImageLoader else { return }
        cover = await loader.loadImage(for: entry, targetSize: CGSize(width: 680, height: 980))
    }
}
