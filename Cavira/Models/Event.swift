import Foundation
import SwiftData

@Model
final class Event {
    var id: UUID
    var title: String
    var eventDescription: String?
    var coverPhotoId: UUID?
    var startDate: Date
    var endDate: Date?
    @Relationship(deleteRule: .nullify) var photos: [PhotoEntry] = []
    var isPinned: Bool = false
    var createdDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        eventDescription: String? = nil,
        coverPhotoId: UUID? = nil,
        startDate: Date,
        endDate: Date? = nil,
        photos: [PhotoEntry] = [],
        isPinned: Bool = false,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.eventDescription = eventDescription
        self.coverPhotoId = coverPhotoId
        self.startDate = startDate
        self.endDate = endDate
        self.photos = photos
        self.isPinned = isPinned
        self.createdDate = createdDate
    }
}

