import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var defaultStorageMode: StorageMode
    var defaultHomeView: HomeViewMode
    var appearanceMode: AppearanceMode
    /// Optional for SwiftData schema evolution; defaults to `.ranger` when nil.
    var themePalette: ThemePalette?
    /// One-time migration: convert legacy items into Stories.
    var didMigrateEventsToStories: Bool

    init() {
        id = UUID()
        defaultStorageMode = .reference
        defaultHomeView = .grid
        appearanceMode = .system
        themePalette = .ranger
        didMigrateEventsToStories = false
    }
}

