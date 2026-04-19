import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var defaultStorageMode: StorageMode
    var defaultHomeView: HomeViewMode
    var appearanceMode: AppearanceMode

    init() {
        id = UUID()
        defaultStorageMode = .reference
        defaultHomeView = .grid
        appearanceMode = .system
    }
}

