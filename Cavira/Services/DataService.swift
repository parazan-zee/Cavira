import Foundation
import SwiftData

enum DataService {
    /// Marks missing Photos-backed album items as not in the Home album.
    /// Returns the number of entries removed from Home.
    @MainActor
    static func removeMissingFromHomeAlbumIfNeeded(
        context: ModelContext,
        photoLibrary: PhotoLibraryService
    ) -> Int {
        let predicate = #Predicate<PhotoEntry> { entry in
            entry.isInHomeAlbum == true && entry.localIdentifier != nil
        }
        let descriptor = FetchDescriptor<PhotoEntry>(predicate: predicate)
        let rows = (try? context.fetch(descriptor)) ?? []

        var removed = 0
        for entry in rows {
            guard let lid = entry.localIdentifier else { continue }
            if photoLibrary.asset(for: lid) == nil {
                entry.isInHomeAlbum = false
                removed += 1
            }
        }
        if removed > 0 {
            try? context.save()
        }
        return removed
    }
    /// Returns an existing album row for this Photos `localIdentifier`, if any.
    static func existingPhotoEntry(localIdentifier: String, context: ModelContext) -> PhotoEntry? {
        let descriptor = FetchDescriptor<PhotoEntry>()
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.first { $0.localIdentifier == localIdentifier }
    }

    static func allPhotos(context: ModelContext) -> [PhotoEntry] {
        let descriptor = FetchDescriptor<PhotoEntry>(
            sortBy: [SortDescriptor(\.capturedDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func photos(in event: Event, context: ModelContext) -> [PhotoEntry] {
        _ = context
        return event.photos.sorted { $0.capturedDate > $1.capturedDate }
    }

    static func photos(taggedWith locationTag: LocationTag, context: ModelContext) -> [PhotoEntry] {
        let tagID = locationTag.id
        return allPhotos(context: context).filter { $0.locationTag?.id == tagID }
    }

    static func photos(taggedWith person: PersonTag, context: ModelContext) -> [PhotoEntry] {
        let pid = person.id
        return allPhotos(context: context).filter { entry in
            entry.peopleTags.contains { $0.id == pid }
        }
    }

    static func photos(withCustomTag tag: String, context: ModelContext) -> [PhotoEntry] {
        allPhotos(context: context).filter { $0.customTags.contains(tag) }
    }

    static func photos(from startDate: Date, to endDate: Date, context: ModelContext) -> [PhotoEntry] {
        let start = startDate
        let end = endDate
        let predicate = #Predicate<PhotoEntry> { entry in
            entry.capturedDate >= start && entry.capturedDate <= end
        }
        let descriptor = FetchDescriptor<PhotoEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.capturedDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func getOrCreateSettings(context: ModelContext) -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        // Explicit `save()` so first-run defaults hit disk promptly; `ModelContext.save()` is the documented SwiftData API to commit pending changes.
        try? context.save()
        return settings
    }

    /// One-time migration: convert legacy `Event` rows into `Story` rows, then delete the legacy rows.
    ///
    /// This removes the old tab concept while preserving user history.
    @MainActor
    static func migrateEventsToStoriesIfNeeded(context: ModelContext) {
        let settings = getOrCreateSettings(context: context)
        guard settings.didMigrateEventsToStories == false else { return }

        let eventDescriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let events = (try? context.fetch(eventDescriptor)) ?? []
        guard !events.isEmpty else {
            settings.didMigrateEventsToStories = true
            try? context.save()
            return
        }

        for event in events {
            // Build slides from the event's photos (sorted oldest → newest for story playback).
            let orderedPhotos = event.photos.sorted { $0.capturedDate < $1.capturedDate }
            var slides: [StorySlide] = []
            slides.reserveCapacity(orderedPhotos.count)
            for (idx, entry) in orderedPhotos.enumerated() {
                let slide = StorySlide(order: idx, photo: entry)
                context.insert(slide)
                slides.append(slide)
            }

            let coverId: UUID? = {
                if let cover = event.coverPhotoId { return cover }
                return slides.first?.photo?.id
            }()

            let story = Story(
                title: event.title,
                storyDescription: event.eventDescription,
                storyDate: event.startDate,
                locationTag: event.locationTag,
                peopleTags: event.peopleTags,
                coverPhotoId: coverId,
                slides: slides,
                isPinned: event.isPinned,
                createdDate: event.createdDate,
                lastEditedDate: Date()
            )
            context.insert(story)

            // Unlink old relationships to avoid dangling "event" UI/data paths.
            for entry in event.photos {
                entry.event = nil
            }

            context.delete(event)
        }

        settings.didMigrateEventsToStories = true
        try? context.save()
    }

    /// Deletes the SwiftData row; for `localCopy` also asks `photoStorage` to remove the file (no-op in Cavira v1).
    static func deletePhotoEntry(
        _ entry: PhotoEntry,
        context: ModelContext,
        photoStorage: any PhotoStorageServing
    ) throws {
        if entry.storageMode == .localCopy, let name = entry.storedFilename {
            try? photoStorage.deleteFile(named: name)
        }
        context.delete(entry)
        try context.save()
    }
}
