import SwiftData
import SwiftUI

struct StoryCardView: View {
    let story: Story
    var onTap: () -> Void
    var onEdit: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void

    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @State private var cover: UIImage?

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left — cover
            ZStack(alignment: .bottom) {
                coverPhoto
                    .frame(width: 110, height: 110)
                    .clipped()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.3), radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 3) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Text("\(story.slides.count)")
                        .font(CaviraTheme.Typography.micro)
                        .foregroundStyle(CaviraTheme.textPrimary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(CaviraTheme.photoScrim)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                if story.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(CaviraTheme.textOnAccent)
                        .frame(width: 20, height: 20)
                        .background(CaviraTheme.pinBadge)
                        .clipShape(Circle())
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: CaviraTheme.Radius.large,
                bottomLeadingRadius: CaviraTheme.Radius.large,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            ))

            // MARK: Right — metadata
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(story.title)
                        .font(CaviraTheme.Typography.headline)
                        .foregroundStyle(CaviraTheme.textPrimary)
                        .lineLimit(1)

                    if let event = story.event {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(CaviraTheme.accent)
                            Text(event.title)
                                .font(CaviraTheme.Typography.caption)
                                .foregroundStyle(CaviraTheme.accent)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 4) {
                    if let location = story.locationTag?.name {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                                .foregroundStyle(CaviraTheme.textTertiary)
                            Text(location)
                                .font(CaviraTheme.Typography.micro)
                                .foregroundStyle(CaviraTheme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    if !peopleNames.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                                .foregroundStyle(CaviraTheme.textTertiary)
                            Text(peopleNames)
                                .font(CaviraTheme.Typography.micro)
                                .foregroundStyle(CaviraTheme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    if story.orderedSlides.count > 1 {
                        miniThumbnailStrip
                    }
                }

                Spacer(minLength: 6)

                HStack {
                    Text(story.createdDate.formatted(date: .abbreviated, time: .omitted))
                        .font(CaviraTheme.Typography.micro)
                        .foregroundStyle(CaviraTheme.textTertiary)

                    Spacer()

                    Menu {
                        Button {
                            // Presenting a sheet while a Menu is dismissing can cause the label to "flicker"
                            // due to overlapping transitions. Deferring to the next runloop (or a tiny delay)
                            // lets the Menu fully dismiss first.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                onEdit()
                            }
                        } label: {
                            Label("Edit story", systemImage: "pencil")
                        }

                        Button {
                            onTogglePin()
                        } label: {
                            Label(
                                story.isPinned ? "Unpin from profile" : "Pin to profile",
                                systemImage: story.isPinned ? "pin.slash" : "pin"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete story", systemImage: "trash")
                        }
                    } label: {
                        // Match PhotoDetailView's iOS-style trailing menu affordance,
                        // but keep a generous hit target for reliability.
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(CaviraTheme.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    // Prevent a tiny "pop" animation when the menu dismisses and a sheet
                    // presents (SwiftUI sometimes applies an implicit toolbar/menu transaction).
                    .transaction { t in
                        t.animation = nil
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Story actions")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 110)
        .background(CaviraTheme.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: CaviraTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CaviraTheme.Radius.large, style: .continuous)
                .stroke(CaviraTheme.border, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .task(id: story.id) {
            await loadCover()
        }
    }

    // MARK: - Cover photo

    @ViewBuilder
    private var coverPhoto: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .scaledToFill()
        } else if let first = story.orderedSlides.first?.photo {
            // Fallback while async cover loads.
            PhotoThumbnailView(entry: first)
                .scaledToFill()
        } else {
            CaviraTheme.surfacePhoto
                .overlay(
                    Image(systemName: "film")
                        .font(.system(size: 24))
                        .foregroundStyle(CaviraTheme.textTertiary)
                )
        }
    }

    @MainActor
    private func loadCover() async {
        guard let loader = appServices?.photoImageLoader else { return }
        let entry = coverEntryFromStore() ?? fallbackCoverEntry
        guard let entry else {
            cover = nil
            return
        }

        cover = await loader.loadImage(for: entry, targetSize: CGSize(width: 420, height: 420))
    }

    private func coverEntryFromStore() -> PhotoEntry? {
        guard let coverID = story.coverPhotoId else { return nil }
        let descriptor = FetchDescriptor<PhotoEntry>(
            predicate: #Predicate { $0.id == coverID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private var fallbackCoverEntry: PhotoEntry? {
        story.orderedSlides.first?.photo
    }

    // MARK: - Mini strip

    private var miniThumbnailStrip: some View {
        let maxVisible = 4
        let visibleSlides = Array(story.orderedSlides.prefix(maxVisible))
        let remaining = max(0, story.slides.count - maxVisible)

        return HStack(spacing: 2) {
            ForEach(visibleSlides, id: \.id) { slide in
                if let photo = slide.photo {
                    PhotoThumbnailView(entry: photo)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
            }
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(CaviraTheme.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(CaviraTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
    }

    // MARK: - People helper

    private var peopleNames: String {
        let uniqueNames = Array(Set(story.peopleTags.map(\.displayName))).sorted()
        guard !uniqueNames.isEmpty else { return "" }
        let capped = Array(uniqueNames.prefix(3))
        let joined = capped.joined(separator: ", ")
        return uniqueNames.count > 3 ? "\(joined) +\(uniqueNames.count - 3)" : joined
    }
}

