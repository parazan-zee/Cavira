import Foundation
import SwiftData

@Model
final class PersonTag {
    var id: UUID
    var contactIdentifier: String
    var displayName: String
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        contactIdentifier: String,
        displayName: String,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.contactIdentifier = contactIdentifier
        self.displayName = displayName
        self.thumbnailData = thumbnailData
    }
}

