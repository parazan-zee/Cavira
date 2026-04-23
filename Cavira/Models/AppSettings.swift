import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var defaultStorageMode: StorageMode
    var defaultHomeView: HomeViewMode
    var appearanceMode: AppearanceMode
    /// One-time migration: convert legacy items into Stories.
    var didMigrateEventsToStories: Bool

    init() {
        id = UUID()
        defaultStorageMode = .reference
        defaultHomeView = .grid
        appearanceMode = .system
        didMigrateEventsToStories = false
    }
}

