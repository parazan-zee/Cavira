import Foundation

enum StorageMode: String, Codable { case reference, localCopy }
/// Home header layout. **`.profile`** is kept for SwiftData / migration only.
enum HomeViewMode: String, Codable {
    case grid
    case timeline
    case videos
    /// Legacy value kept for SwiftData migration; not shown in the UI.
    case events
    case profile
}
enum AppearanceMode: String, Codable { case system, light, dark }

/// Library asset kind for a `PhotoEntry`. Live Photos use `.image` with `isLivePhoto == true`.
enum PhotoAssetKind: String, Codable {
    case image
    case video
}
