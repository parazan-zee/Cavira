import Foundation
import SwiftData

/// Placement of a person tag on a specific photo (Instagram-style).
struct PersonTagPlacement: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var personTagId: UUID
    /// Normalized 0–1 coordinates within the displayed image container.
    var x: Double
    var y: Double
}

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
    /// If true, this entry appears in the Home album (Grid/Timeline/Videos). Story-only items can keep this false.
    var isInHomeAlbum: Bool
    /// Manual ordering for Home album (optional for migration safety). When nil, Home falls back to capturedDate order.
    var homeOrderIndex: Int?
    /// Manual ordering for the Videos segment (optional). Kept separate from `homeOrderIndex` so photos and videos can be reordered independently.
    var videoOrderIndex: Int?
    /// Order inside `homeCollection` (0-based). Nil when not in a collection.
    var collectionMemberOrder: Int?
    var capturedDate: Date
    var loggedDate: Date
    /// User-facing title for this photo/video (optional, set during import or later in Edit).
    var title: String?
    var notes: String?
    var locationTag: LocationTag?
    @Relationship(deleteRule: .nullify) var peopleTags: [PersonTag] = []
    /// Stored separately from the relationship so we can position each tag on the image.
    var peopleTagPlacementsData: Data?
    var customTags: [String] = []
    @Relationship(inverse: \Event.photos) var event: Event?
    @Relationship(inverse: \HomeCollection.entries) var homeCollection: HomeCollection?

    var textOverlaysData: Data?
    var stickerOverlaysData: Data?

    var peopleTagPlacements: [PersonTagPlacement] {
        get {
            guard let peopleTagPlacementsData else { return [] }
            return (try? JSONDecoder().decode([PersonTagPlacement].self, from: peopleTagPlacementsData)) ?? []
        }
        set {
            peopleTagPlacementsData = try? JSONEncoder().encode(newValue)
        }
    }

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
        isInHomeAlbum: Bool = true,
        homeOrderIndex: Int? = nil,
        videoOrderIndex: Int? = nil,
        collectionMemberOrder: Int? = nil,
        capturedDate: Date,
        loggedDate: Date = Date(),
        title: String? = nil,
        notes: String? = nil,
        locationTag: LocationTag? = nil,
        peopleTags: [PersonTag] = [],
        peopleTagPlacements: [PersonTagPlacement] = [],
        customTags: [String] = [],
        event: Event? = nil,
        homeCollection: HomeCollection? = nil,
        textOverlays: [TextOverlay] = [],
        stickerOverlays: [StickerOverlay] = []
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.storedFilename = storedFilename
        self.storageMode = storageMode
        self.mediaKind = mediaKind
        self.isLivePhoto = isLivePhoto
        self.isInHomeAlbum = isInHomeAlbum
        self.homeOrderIndex = homeOrderIndex
        self.videoOrderIndex = videoOrderIndex
        self.collectionMemberOrder = collectionMemberOrder
        self.capturedDate = capturedDate
        self.loggedDate = loggedDate
        self.title = title
        self.notes = notes
        self.locationTag = locationTag
        self.peopleTags = peopleTags
        self.peopleTagPlacementsData = try? JSONEncoder().encode(peopleTagPlacements)
        self.customTags = customTags
        self.event = event
        self.homeCollection = homeCollection
        self.textOverlaysData = try? JSONEncoder().encode(textOverlays)
        self.stickerOverlaysData = try? JSONEncoder().encode(stickerOverlays)
    }
}
