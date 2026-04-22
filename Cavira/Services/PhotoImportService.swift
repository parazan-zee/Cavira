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
        context: ModelContext,
        photoLibrary: PhotoLibraryService
    ) throws -> [PhotoEntry] {
        let localIdentifiers = results.compactMap(\.assetIdentifier)
        return try importLocalIdentifiers(localIdentifiers, context: context, photoLibrary: photoLibrary)
    }

    /// Returns new entries created for these local identifiers (existing rows are skipped).
    @MainActor
    static func importLocalIdentifiers(
        _ localIdentifiers: [String],
        context: ModelContext,
        photoLibrary: PhotoLibraryService
    ) throws -> [PhotoEntry] {
        var touched: [PhotoEntry] = []
        touched.reserveCapacity(localIdentifiers.count)

        for lid in localIdentifiers {
            if DataService.existingPhotoEntry(localIdentifier: lid, context: context) != nil {
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
                capturedDate: asset.creationDate ?? .now
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
