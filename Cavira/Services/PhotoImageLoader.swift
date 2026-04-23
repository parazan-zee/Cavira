import Foundation
import Observation
import Photos
import SwiftData
import UIKit

/// Loads pixels for a `PhotoEntry`. **v1:** reference mode only — full-quality image via Photos (HEIF/JPEG as stored in the library).
/// `localCopy` is not supported in this version (returns `nil` without duplicating storage).
@MainActor
@Observable
final class PhotoImageLoader {
    private let imageManager = PHImageManager.default()
    private let photoLibrary: PhotoLibraryService
    private let cache = NSCache<NSString, UIImage>()
    private let cacheQueue = DispatchQueue(label: "cavira.photoimageloader.cache", qos: .userInitiated)

    init(photoLibrary: PhotoLibraryService) {
        self.photoLibrary = photoLibrary
        cache.countLimit = 220
        // Keep memory bounded: ~96MB decoded-image cache (thumbnails + a few larger frames).
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    /// Full-resolution decode from the Photos library (HEIF/JPEG/PNG as captured — no Cavira disk copy).
    func loadFullLibraryImage(for entry: PhotoEntry) async -> UIImage? {
        guard entry.storageMode == .reference,
              let id = entry.localIdentifier,
              let asset = photoLibrary.asset(for: id)
        else { return nil }

        let key = "\(entry.id.uuidString)|full" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        let image: UIImage?
        if asset.mediaType == .video {
            let w = max(CGFloat(asset.pixelWidth), 1)
            let h = max(CGFloat(asset.pixelHeight), 1)
            image = await requestScaledImage(for: asset, targetSize: CGSize(width: w, height: h))
        } else {
            image = await requestFullLibraryImage(for: asset)
        }
        if let image {
            cache.setObject(image, forKey: key, cost: estimatedCostBytes(for: image))
        }
        return image
    }

    func loadThumbnail(for entry: PhotoEntry) async -> UIImage? {
        await loadImage(for: entry, targetSize: CGSize(width: 200, height: 200))
    }

    func loadImage(for entry: PhotoEntry, targetSize: CGSize) async -> UIImage? {
        switch entry.storageMode {
        case .localCopy:
            return nil
        case .reference:
            break
        }

        guard let id = entry.localIdentifier,
              let asset = photoLibrary.asset(for: id)
        else { return nil }

        let key = cacheKey(entryID: entry.id, targetSize: targetSize)
        if let hit = cache.object(forKey: key as NSString) {
            return hit
        }

        let image: UIImage?
        if isFullPixelSizeRequest(targetSize, asset: asset) {
            image = await requestFullLibraryImage(for: asset)
        } else {
            image = await requestScaledImage(for: asset, targetSize: targetSize)
        }

        if let image {
            cache.setObject(image, forKey: key as NSString, cost: estimatedCostBytes(for: image))
        }
        return image
    }

    private func isFullPixelSizeRequest(_ size: CGSize, asset: PHAsset) -> Bool {
        let pw = max(CGFloat(asset.pixelWidth), 1)
        let ph = max(CGFloat(asset.pixelHeight), 1)
        return size.width >= pw * 0.95 && size.height >= ph * 0.95
    }

    /// Decodes the asset’s current image data (typically HEIF on modern iPhones, else JPEG/PNG).
    private func requestFullLibraryImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let resumeOnce = ContinuationResumeOnce(continuation)
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                DispatchQueue.main.async {
                    if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                        resumeOnce.resume(returning: nil)
                        return
                    }
                    guard let data, let image = UIImage(data: data) else {
                        resumeOnce.resume(returning: nil)
                        return
                    }
                    resumeOnce.resume(returning: image)
                }
            }
        }
    }

    private func requestScaledImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let resumeOnce = ContinuationResumeOnce(continuation)
            let degradedHolder = ThumbnailDegradedHolder()
            var timeoutTask: Task<Void, Never>?

            timeoutTask = Task { @Sendable in
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }
                DispatchQueue.main.async {
                    resumeOnce.resume(returning: degradedHolder.image)
                }
            }

            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                DispatchQueue.main.async {
                    if info?[PHImageCancelledKey] as? Bool == true {
                        timeoutTask?.cancel()
                        resumeOnce.resume(returning: nil)
                        return
                    }
                    if info?[PHImageErrorKey] != nil {
                        timeoutTask?.cancel()
                        resumeOnce.resume(returning: image ?? degradedHolder.image)
                        return
                    }
                    guard let image else { return }
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if degraded {
                        degradedHolder.image = image
                        return
                    }
                    timeoutTask?.cancel()
                    resumeOnce.resume(returning: image)
                }
            }
        }
    }

    private func cacheKey(entryID: UUID, targetSize: CGSize) -> String {
        "\(entryID.uuidString)|\(Int(targetSize.width))x\(Int(targetSize.height))"
    }

    private func estimatedCostBytes(for image: UIImage) -> Int {
        if let cg = image.cgImage {
            return cg.bytesPerRow * cg.height
        }
        let pxW = max(Int(image.size.width * image.scale), 1)
        let pxH = max(Int(image.size.height * image.scale), 1)
        return pxW * pxH * 4
    }
}

/// Holds the latest degraded preview frame while waiting for a non-degraded `requestImage` callback.
private final class ThumbnailDegradedHolder: @unchecked Sendable {
    var image: UIImage?
}

/// `PHImageManager` may invoke result handlers more than once; `CheckedContinuation` must resume exactly once.
private final class ContinuationResumeOnce: @unchecked Sendable {
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<UIImage?, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: UIImage?) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(returning: value)
        continuation = nil
    }
}
