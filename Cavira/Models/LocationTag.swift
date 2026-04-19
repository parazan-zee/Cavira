import Foundation
import SwiftData

@Model
final class LocationTag {
    var id: UUID
    var name: String
    var latitude: Double?
    var longitude: Double?
    var mapKitPlaceID: String?

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapKitPlaceID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.mapKitPlaceID = mapKitPlaceID
    }
}

