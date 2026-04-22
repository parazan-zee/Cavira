import Foundation
import SwiftData

@Model
final class Story {
    var id: UUID
    var title: String
    var storyDescription: String?
    var storyDate: Date
    var locationTag: LocationTag?
    @Relationship(deleteRule: .nullify) var peopleTags: [PersonTag] = []
    var coverPhotoId: UUID?
    @Relationship(deleteRule: .cascade) var slides: [StorySlide] = []
    var event: Event?
    var isPinned: Bool = false
    var createdDate: Date
    var lastEditedDate: Date

    var orderedSlides: [StorySlide] {
        slides.sorted { $0.order < $1.order }
    }

    init(
        id: UUID = UUID(),
        title: String,
        storyDescription: String? = nil,
        storyDate: Date = Date(),
        locationTag: LocationTag? = nil,
        peopleTags: [PersonTag] = [],
        coverPhotoId: UUID? = nil,
        slides: [StorySlide] = [],
        event: Event? = nil,
        isPinned: Bool = false,
        createdDate: Date = Date(),
        lastEditedDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.storyDescription = storyDescription
        self.storyDate = storyDate
        self.locationTag = locationTag
        self.peopleTags = peopleTags
        self.coverPhotoId = coverPhotoId
        self.slides = slides
        self.event = event
        self.isPinned = isPinned
        self.createdDate = createdDate
        self.lastEditedDate = lastEditedDate
    }
}

