import SwiftUI

/// Month-bucketed timeline for the digital album (not SwiftUI’s `TimelineView` schedule API).
struct AlbumTimelineView: View {
    let rows: [HomeAlbumRow]
    let onRequestRemoveRow: (HomeAlbumRow) -> Void
    var onEdit: ((PhotoEntry) -> Void)? = nil

    private var sections: [MonthSection] {
        MonthSection.build(from: rows)
    }

    var body: some View {
        Group {
            if rows.isEmpty {
                EmptyStateView(
                    title: "Import your media to start",
                    subtitle: "Build a timeline from photos and videos in your album."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(CaviraTheme.Typography.title)
                                    .foregroundStyle(CaviraTheme.textPrimary)
                                    .padding(.horizontal, 4)

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 2),
                                        GridItem(.flexible(), spacing: 2),
                                    ],
                                    spacing: 2
                                ) {
                                    ForEach(section.rows) { row in
                                        switch row {
                                        case .standalone(let entry):
                                            NavigationLink(value: HomeDestination.photo(entry.id)) {
                                                PhotoThumbnailView(entry: entry)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                if let onEdit {
                                                    Button("Edit", systemImage: "pencil") {
                                                        onEdit(entry)
                                                    }
                                                }
                                                Button("Remove from album", systemImage: "rectangle.badge.minus", role: .destructive) {
                                                    onRequestRemoveRow(row)
                                                }
                                            }
                                        case .collection(let collection):
                                            NavigationLink(value: HomeDestination.collection(collection.id)) {
                                                collectionCell(collection)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button("Remove from album", systemImage: "rectangle.badge.minus", role: .destructive) {
                                                    onRequestRemoveRow(row)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(CaviraTheme.backgroundPrimary)
            }
        }
    }

    private func collectionCell(_ collection: HomeCollection) -> some View {
        ZStack(alignment: .topTrailing) {
            if let cover = collection.coverEntry {
                PhotoThumbnailView(entry: cover)
            } else {
                Rectangle()
                    .fill(CaviraTheme.surfacePhoto)
                    .aspectRatio(1, contentMode: .fit)
            }

            Image(systemName: "square.stack.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .padding(4)
        }
    }
}

struct MonthSection: Identifiable {
    let id: String
    let title: String
    let rows: [HomeAlbumRow]

    private static func rowDate(_ row: HomeAlbumRow) -> Date {
        switch row {
        case .standalone(let e):
            return e.capturedDate
        case .collection(let c):
            return c.coverEntry?.capturedDate ?? c.createdDate
        }
    }

    /// Keys are `yyyy-MM` so lexicographic sort is chronological descending.
    static func build(from rows: [HomeAlbumRow]) -> [MonthSection] {
        let calendar = Calendar.current
        var buckets: [String: [HomeAlbumRow]] = [:]
        for row in rows {
            let date = rowDate(row)
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let y = comps.year, let m = comps.month else { continue }
            let key = String(format: "%04d-%02d", y, m)
            buckets[key, default: []].append(row)
        }

        let sortedKeys = buckets.keys.sorted(by: >)
        let titleFormatter = DateFormatter()
        titleFormatter.dateFormat = "LLLL yyyy"

        return sortedKeys.compactMap { key -> MonthSection? in
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let y = Int(parts[0]),
                  let m = Int(parts[1]),
                  let date = calendar.date(from: DateComponents(year: y, month: m, day: 1))
            else { return nil }
            let title = titleFormatter.string(from: date)
            let sectionRows = (buckets[key] ?? []).sorted(by: HomeAlbumRow.mergedSort)
            return MonthSection(id: key, title: title, rows: sectionRows)
        }
    }
}
