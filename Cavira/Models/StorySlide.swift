import Foundation
import SwiftData

@Model
final class StorySlide {
    var id: UUID
    var order: Int
    var photo: PhotoEntry?
    var backgroundColour: String?
    var textOverlaysData: Data?
    var stickerOverlaysData: Data?
    /// Small on-device preview (JPEG) so Stories can render even if the Photos asset disappears.
    /// This is **not** a full-resolution copy.
    var fallbackPreviewImageData: Data?

    var textOverlays: [TextOverlay] {
        get {
            guard let textOverlaysData else { return [] }
            return (try? JSONDecoder().decode([TextOverlay].self, from: textOverlaysData)) ?? []
        }
        set {
            textOverlaysData = try? JSONEncoder().encode(newValue)
        }
    }

    var stickerOverlays: [StickerOverlay] {
        get {
            guard let stickerOverlaysData else { return [] }
            return (try? JSONDecoder().decode([StickerOverlay].self, from: stickerOverlaysData)) ?? []
        }
        set {
            stickerOverlaysData = try? JSONEncoder().encode(newValue)
        }
    }

    @Relationship(inverse: \Story.slides) var story: Story?

    init(
        id: UUID = UUID(),
        order: Int,
        photo: PhotoEntry? = nil,
        backgroundColour: String? = nil,
        textOverlays: [TextOverlay] = [],
        stickerOverlays: [StickerOverlay] = [],
        fallbackPreviewImageData: Data? = nil,
        story: Story? = nil
    ) {
        self.id = id
        self.order = order
        self.photo = photo
        self.backgroundColour = backgroundColour
        self.textOverlaysData = try? JSONEncoder().encode(textOverlays)
        self.stickerOverlaysData = try? JSONEncoder().encode(stickerOverlays)
        self.fallbackPreviewImageData = fallbackPreviewImageData
        self.story = story
    }
}

