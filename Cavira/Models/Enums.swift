import Foundation

enum StorageMode: String, Codable { case reference, localCopy }
/// Home header layout. **`.profile`** is kept for SwiftData / migration only — UI is **Grid \| Timeline \| Videos \| Events** (see `archeticturedoc.md`).
enum HomeViewMode: String, Codable {
    case grid
    case timeline
    case videos
    case events
    case profile
}
enum AppearanceMode: String, Codable { case system, light, dark }

/// Library asset kind for a `PhotoEntry`. Live Photos use `.image` with `isLivePhoto == true`.
enum PhotoAssetKind: String, Codable {
    case image
    case video
}
