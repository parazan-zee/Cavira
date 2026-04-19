import Foundation

/// Disk copy pipeline for `StorageMode.localCopy` is **not used in Cavira v1** (reference-only organiser).
/// Keep the protocol so Phase 4+ can swap in a real implementation without rewriting callers.
protocol PhotoStorageServing: Sendable {
    func totalStorageUsed() -> Int64
    func deleteFile(named filename: String) throws
}

/// No on-disk duplicate library in v1 — avoids double storage; all pixels come from the Photos library.
struct NoOpPhotoStorage: PhotoStorageServing {
    func totalStorageUsed() -> Int64 { 0 }

    func deleteFile(named filename: String) throws {
        _ = filename
    }
}
