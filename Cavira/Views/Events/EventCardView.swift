import SwiftData
import SwiftUI

/// Row card for an occasion in the Calendar tab list.
struct EventCardView: View {
    let event: Event

    private var coverEntry: PhotoEntry? {
        if let cid = event.coverPhotoId {
            return event.photos.first { $0.id == cid }
        }
        return event.photos.max(by: { $0.capturedDate < $1.capturedDate })
    }

    private var dateRangeText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        if let end = event.endDate {
            return "\(df.string(from: event.startDate)) – \(df.string(from: end))"
        }
        return df.string(from: event.startDate)
    }

    var body: some View {
        HStack(alignment: .center, spacing: CaviraTheme.Spacing.md) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let entry = coverEntry {
                        PhotoThumbnailView(entry: entry)
                    } else {
                        RoundedRectangle(cornerRadius: CaviraTheme.Radius.small)
                            .fill(CaviraTheme.surfacePhoto)
                            .overlay {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                            }
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: CaviraTheme.Radius.small))

                if event.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CaviraTheme.pinBadge)
                        .padding(6)
                        .background(CaviraTheme.photoScrim, in: Circle())
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: CaviraTheme.Spacing.xs) {
                Text(event.title)
                    .font(CaviraTheme.Typography.headline)
                    .foregroundStyle(CaviraTheme.textPrimary)
                    .lineLimit(2)
                Text(dateRangeText)
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
                Text("\(event.photos.count) \(event.photos.count == 1 ? "item" : "items")")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(CaviraTheme.Spacing.md)
        .background(CaviraTheme.surfaceCard, in: RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium)
                .stroke(CaviraTheme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(dateRangeText), \(event.photos.count) items")
    }
}
