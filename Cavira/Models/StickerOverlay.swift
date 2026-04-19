import Foundation
import SwiftUI

struct StickerOverlay: Codable, Identifiable {
    var id: UUID = UUID()
    var stickerName: String
    var positionX: CGFloat = 0.5
    var positionY: CGFloat = 0.5
    var scale: CGFloat = 1.0
    var rotation: CGFloat = 0
}

