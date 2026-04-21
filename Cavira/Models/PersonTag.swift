import Foundation
import SwiftData

@Model
final class PersonTag {
    var id: UUID
    /// Optional link into iOS Contacts. `nil` = free-text tag created in Cavira (not a real contact).
    var contactIdentifier: String?
    var displayName: String
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        contactIdentifier: String? = nil,
        displayName: String,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.contactIdentifier = contactIdentifier
        self.displayName = displayName
        self.thumbnailData = thumbnailData
    }
}

