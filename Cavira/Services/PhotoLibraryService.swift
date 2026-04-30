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

    /// Images only, newest first (creation date descending).
    func fetchAllAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(with: options)
    }

    func asset(for localIdentifier: String) -> PHAsset? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return results.firstObject
    }

    /// Counts of **image** assets grouped by **calendar day of month** (1…31) for the month that contains `monthContaining` (uses `creationDate` in `calendar`’s time zone).
    func assetCountsByDayInMonth(containing monthContaining: Date, calendar: Calendar = .current) -> [Int: Int] {
        guard let interval = calendar.dateInterval(of: .month, for: monthContaining) else { return [:] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaType == %d) AND (creationDate >= %@ AND creationDate < %@)",
            PHAssetMediaType.image.rawValue,
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

    /// All image assets captured on the given calendar day (local time), newest first.
    func assets(onDay day: Date, calendar: Calendar = .current) -> [PHAsset] {
        guard let start = calendar.startOfDay(for: day) as Date?,
              let end = calendar.date(byAdding: .day, value: 1, to: start)
        else { return [] }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "(mediaType == %d) AND (creationDate >= %@ AND creationDate < %@)",
            PHAssetMediaType.image.rawValue,
            start as NSDate,
            end as NSDate
        )
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    /// Best-effort recap: image assets captured on the same **month/day** in previous years (newest first).
    /// `yearsBack` bounds the search to avoid too many fetches.
    func recapAssetsOnThisDate(referenceDay: Date, yearsBack: Int = 10, calendar: Calendar = .current, limit: Int = 25) -> [PHAsset] {
        let comps = calendar.dateComponents([.month, .day, .year], from: referenceDay)
        guard let month = comps.month, let day = comps.day, let year = comps.year else { return [] }

        var collected: [PHAsset] = []
        for y in stride(from: year - 1, through: max(0, year - yearsBack), by: -1) {
            guard let start = calendar.date(from: DateComponents(year: y, month: month, day: day)),
                  let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))
            else { continue }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = max(0, limit - collected.count)
            options.predicate = NSPredicate(
                format: "(mediaType == %d) AND (creationDate >= %@ AND creationDate < %@)",
                PHAssetMediaType.image.rawValue,
                calendar.startOfDay(for: start) as NSDate,
                end as NSDate
            )
            let result = PHAsset.fetchAssets(with: options)
            result.enumerateObjects { asset, _, stop in
                collected.append(asset)
                if collected.count >= limit { stop.pointee = true }
            }
            if collected.count >= limit { break }
        }
        return collected
    }

    /// Best-effort recap fallback: image assets captured in the same **month** across previous years.
    func recapAssetsThisMonth(referenceDay: Date, yearsBack: Int = 10, calendar: Calendar = .current, limit: Int = 25) -> [PHAsset] {
        let comps = calendar.dateComponents([.month, .year], from: referenceDay)
        guard let month = comps.month, let year = comps.year else { return [] }

        var collected: [PHAsset] = []
        for y in stride(from: year - 1, through: max(0, year - yearsBack), by: -1) {
            guard let monthStart = calendar.date(from: DateComponents(year: y, month: month, day: 1)),
                  let interval = calendar.dateInterval(of: .month, for: monthStart)
            else { continue }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = max(0, limit - collected.count)
            options.predicate = NSPredicate(
                format: "(mediaType == %d) AND (creationDate >= %@ AND creationDate < %@)",
                PHAssetMediaType.image.rawValue,
                interval.start as NSDate,
                interval.end as NSDate
            )
            let result = PHAsset.fetchAssets(with: options)
            result.enumerateObjects { asset, _, stop in
                collected.append(asset)
                if collected.count >= limit { stop.pointee = true }
            }
            if collected.count >= limit { break }
        }
        return collected
    }
}
