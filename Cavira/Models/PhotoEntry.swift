import Foundation
import SwiftData

@Model
final class PhotoEntry {
    var id: UUID
    var localIdentifier: String?
    var storedFilename: String?
    var storageMode: StorageMode
    /// `.image` or `.video` from `PHAsset.mediaType` at import.
    var mediaKind: PhotoAssetKind
    /// Live Photo motion stays in the library; grid uses still only (see architecture doc).
    var isLivePhoto: Bool
    var capturedDate: Date
    var loggedDate: Date
    var notes: String?
    var locationTag: LocationTag?
    @Relationship(deleteRule: .nullify) var peopleTags: [PersonTag] = []
    var customTags: [String] = []
    @Relationship(inverse: \Event.photos) var event: Event?

    var textOverlaysData: Data?
    var stickerOverlaysData: Data?

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

    init(
        id: UUID = UUID(),
        localIdentifier: String? = nil,
        storedFilename: String? = nil,
        storageMode: StorageMode,
        mediaKind: PhotoAssetKind = .image,
        isLivePhoto: Bool = false,
        capturedDate: Date,
        loggedDate: Date = Date(),
        notes: String? = nil,
        locationTag: LocationTag? = nil,
        peopleTags: [PersonTag] = [],
        customTags: [String] = [],
        event: Event? = nil,
        textOverlays: [TextOverlay] = [],
        stickerOverlays: [StickerOverlay] = []
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.storedFilename = storedFilename
        self.storageMode = storageMode
        self.mediaKind = mediaKind
        self.isLivePhoto = isLivePhoto
        self.capturedDate = capturedDate
        self.loggedDate = loggedDate
        self.notes = notes
        self.locationTag = locationTag
        self.peopleTags = peopleTags
        self.customTags = customTags
        self.event = event
        self.textOverlaysData = try? JSONEncoder().encode(textOverlays)
        self.stickerOverlaysData = try? JSONEncoder().encode(stickerOverlays)
    }
}
