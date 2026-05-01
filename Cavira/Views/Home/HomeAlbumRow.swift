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

    // MARK: - Home grid / timeline ordering

    /// Renumbers `homeOrderIndex` for standalone **image** rows and collections (with cover) so the given collection is **last**, preserving current order for everything else.
    @MainActor
    static func renumberGridTimelineAppendingCollection(_ collection: HomeCollection, modelContext: ModelContext) throws {
        // Avoid `#Predicate` here: some Xcode / SwiftData versions still mis-compile filters involving `mediaKind` / enums.
        let allEntries = try modelContext.fetch(FetchDescriptor<PhotoEntry>())
        let standalone = allEntries.filter { entry in
            entry.isInHomeAlbum && entry.homeCollection == nil && entry.mediaKind == .image
        }

        let colsDesc = FetchDescriptor<HomeCollection>()
        let allCollections = try modelContext.fetch(colsDesc)

        let standaloneRows = standalone.map { HomeAlbumRow.standalone($0) }
        let collectionRows = allCollections
            .filter { $0.id != collection.id && $0.coverEntry != nil }
            .map { HomeAlbumRow.collection($0) }
        let others = (standaloneRows + collectionRows).sorted(by: mergedSort)
        let finalOrder = others + [.collection(collection)]

        for (index, row) in finalOrder.enumerated() {
            switch row {
            case .standalone(let e):
                e.homeOrderIndex = index
            case .collection(let c):
                c.homeOrderIndex = index
            }
        }
    }
}
