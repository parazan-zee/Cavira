import Foundation
import SwiftData

enum DataService {
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
