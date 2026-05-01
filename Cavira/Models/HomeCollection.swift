import Foundation
import SwiftData

@Model
final class HomeCollection {
    var id: UUID
    var title: String
    var homeOrderIndex: Int?
    var createdDate: Date

    @Relationship(deleteRule: .nullify)
    var entries: [PhotoEntry] = []

    init(id: UUID = UUID(), title: String, homeOrderIndex: Int? = nil, createdDate: Date = Date()) {
        self.id = id
        self.title = title
        self.homeOrderIndex = homeOrderIndex
        self.createdDate = createdDate
    }

    /// First image member by `collectionMemberOrder`, then `capturedDate` (cover is fixed to this in v1).
    var coverEntry: PhotoEntry? {
        let images = entries.filter { $0.mediaKind == .image }
        guard !images.isEmpty else { return nil }
        return images.sorted { lhs, rhs in
            switch (lhs.collectionMemberOrder, rhs.collectionMemberOrder) {
            case let (l?, r?):
                if l != r { return l < r }
            case (nil, nil):
                break
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
            return lhs.capturedDate < rhs.capturedDate
        }.first
    }

    /// Members in stable collection order for paging.
    var orderedEntries: [PhotoEntry] {
        entries.sorted { lhs, rhs in
            switch (lhs.collectionMemberOrder, rhs.collectionMemberOrder) {
            case let (l?, r?):
                if l != r { return l < r }
            case (nil, nil):
                break
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
            return lhs.capturedDate < rhs.capturedDate
        }
    }
}
