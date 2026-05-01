import Foundation
import SwiftData

/// One visible tile on Home Grid/Timeline: either a standalone photo or a collection.
enum HomeAlbumRow: Identifiable {
    case standalone(PhotoEntry)
    case collection(HomeCollection)

    var id: UUID {
        switch self {
        case .standalone(let e): e.id
        case .collection(let c): c.id
        }
    }

    static func mergedSort(lhs: HomeAlbumRow, rhs: HomeAlbumRow) -> Bool {
        func orderKey(_ row: HomeAlbumRow) -> (Int?, Date) {
            switch row {
            case .standalone(let e):
                return (e.homeOrderIndex, e.capturedDate)
            case .collection(let c):
                let date = c.coverEntry?.capturedDate ?? c.createdDate
                return (c.homeOrderIndex, date)
            }
        }
        let lk = orderKey(lhs)
        let rk = orderKey(rhs)
        switch (lk.0, rk.0) {
        case let (l?, r?):
            if l != r { return l < r }
        case (nil, nil):
            break
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
        return lk.1 > rk.1
    }
}
