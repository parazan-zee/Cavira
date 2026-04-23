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
        try importLocalIdentifiers(
            localIdentifiers,
            context: context,
            photoLibrary: photoLibrary,
            onProgress: nil
        )
    }

    /// Returns new entries created for these local identifiers (existing rows are skipped).
    /// Reports progress as `(current, total)` on the main actor.
    @MainActor
    static func importLocalIdentifiers(
        _ localIdentifiers: [String],
        context: ModelContext,
        photoLibrary: PhotoLibraryService,
        onProgress: ((Int, Int) -> Void)?
    ) throws -> [PhotoEntry] {
        var touched: [PhotoEntry] = []
        touched.reserveCapacity(localIdentifiers.count)

        let total = localIdentifiers.count
        for (idx, lid) in localIdentifiers.enumerated() {
            onProgress?(idx, total)
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
        onProgress?(total, total)

        if !touched.isEmpty {
            try context.save()
        }
        return touched
    }
}
