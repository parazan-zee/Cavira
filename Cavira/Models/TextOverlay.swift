import Foundation
import SwiftUI

struct TextOverlay: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var fontName: String = "System"
    var fontSize: CGFloat = 24
    var colour: String = "#FFFFFF"
    var positionX: CGFloat = 0.5
    var positionY: CGFloat = 0.5
    var rotation: CGFloat = 0
    var isBold: Bool = false
}

