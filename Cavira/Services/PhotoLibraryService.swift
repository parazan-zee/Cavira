import Foundation
import Observation
import Photos

@MainActor
@Observable
final class PhotoLibraryService {
    private(set) var authorizationStatus: PHAuthorizationStatus

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests read/write access; updates `authorizationStatus` for all outcomes.
    @discardableResult
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }

    /// `true` when the user can read the library (full or limited). Updates status when still `.notDetermined`.
    func requestAuthorisationIfNeeded() async -> Bool {
        if authorizationStatus == .notDetermined {
            await requestAuthorization()
        } else {
            authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
        switch authorizationStatus {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// Images and videos, newest first (creation date descending). Used for Calendar-style tooling.
    func fetchAllAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        return PHAsset.fetchAssets(with: options)
    }

    func asset(for localIdentifier: String) -> PHAsset? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return results.firstObject
    }

    /// Counts of **image + video** assets grouped by **calendar day of month** (1…31) for the month that contains `monthContaining` (uses `creationDate` in `calendar`’s time zone).
    func assetCountsByDayInMonth(containing monthContaining: Date, calendar: Calendar = .current) -> [Int: Int] {
        guard let interval = calendar.dateInterval(of: .month, for: monthContaining) else { return [:] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaType == %d OR mediaType == %d) AND (creationDate >= %@ AND creationDate < %@)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue,
            interval.start as NSDate,
            interval.end as NSDate
        )
        let result = PHAsset.fetchAssets(with: options)
        var counts: [Int: Int] = [:]
        result.enumerateObjects { asset, _, _ in
            guard let created = asset.creationDate else { return }
            let day = calendar.component(.day, from: created)
            counts[day, default: 0] += 1
        }
        return counts
    }
}
