import SwiftUI

/// Month-bucketed timeline for the digital album (not SwiftUI’s `TimelineView` schedule API).
struct AlbumTimelineView: View {
    let photos: [PhotoEntry]
    let onRequestRemove: (PhotoEntry) -> Void
    var onEdit: ((PhotoEntry) -> Void)? = nil

    private var sections: [MonthSection] {
        MonthSection.build(from: photos)
    }

    var body: some View {
        Group {
            if photos.isEmpty {
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
                                    ForEach(section.entries, id: \.id) { entry in
                                        NavigationLink(value: entry.id) {
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
                                                onRequestRemove(entry)
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
}

struct MonthSection: Identifiable {
    let id: String
    let title: String
    let entries: [PhotoEntry]

    /// Keys are `yyyy-MM` so lexicographic sort is chronological descending.
    static func build(from photos: [PhotoEntry]) -> [MonthSection] {
        let calendar = Calendar.current
        var buckets: [String: [PhotoEntry]] = [:]
        for photo in photos {
            let comps = calendar.dateComponents([.year, .month], from: photo.capturedDate)
            guard let y = comps.year, let m = comps.month else { continue }
            let key = String(format: "%04d-%02d", y, m)
            buckets[key, default: []].append(photo)
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
            let entries = (buckets[key] ?? []).sorted { $0.capturedDate > $1.capturedDate }
            return MonthSection(id: key, title: title, entries: entries)
        }
    }
}
