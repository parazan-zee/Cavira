import Foundation
import Photos
import PhotosUI
import SwiftData

/// Reference-only import from `PHPickerResult` into SwiftData (`PhotoEntry`).
enum PhotoImportService {
    /// Returns the imported and/or newly-linked entries (skips unresolved picks).
    @MainActor
    static func importPickerResults(
        _ results: [PHPickerResult],
        event: Event?,
        context: ModelContext,
        photoLibrary: PhotoLibraryService
    ) throws -> [PhotoEntry] {
        var touched: [PhotoEntry] = []
        touched.reserveCapacity(results.count)
        for result in results {
            guard let lid = result.assetIdentifier else { continue }
            if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: context) {
                if let event {
                    if existing.event?.id != event.id {
                        existing.event = event
                        touched.append(existing)
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
            touched.append(entry)
        }
        if !touched.isEmpty {
            try context.save()
        }
        return touched
    }
}
