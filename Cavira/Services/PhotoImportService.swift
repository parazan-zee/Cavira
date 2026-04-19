import Foundation
import Photos
import PhotosUI
import SwiftData

/// Reference-only import from `PHPickerResult` into SwiftData (`PhotoEntry`).
enum PhotoImportService {
    /// Returns the number of **new** rows inserted (skips duplicates and unresolved picks).
    @MainActor
    static func importPickerResults(
        _ results: [PHPickerResult],
        event: Event?,
        context: ModelContext,
        photoLibrary: PhotoLibraryService
    ) throws -> Int {
        var inserted = 0
        var linked = 0
        for result in results {
            guard let lid = result.assetIdentifier else { continue }
            if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: context) {
                if let event {
                    if existing.event?.id != event.id {
                        existing.event = event
                        linked += 1
                    }
                }
                continue
            }
            guard let asset = photoLibrary.asset(for: lid) else { continue }

            let mediaKind: PhotoAssetKind = asset.mediaType == .video ? .video : .image
            let isLive = asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)

            let entry = PhotoEntry(
                localIdentifier: lid,
                storedFilename: nil,
                storageMode: .reference,
                mediaKind: mediaKind,
                isLivePhoto: isLive,
                capturedDate: asset.creationDate ?? .now,
                event: event
            )
            context.insert(entry)
            inserted += 1
        }
        if inserted > 0 || linked > 0 {
            try context.save()
        }
        return inserted + linked
    }
}
