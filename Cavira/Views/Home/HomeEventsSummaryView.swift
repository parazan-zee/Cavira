import SwiftData
import SwiftUI

/// Home **Events** segment: all occasions (same data as Calendar), **pinned first**, then by start date.
struct HomeEventsSummaryView: View {
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    private var sortedEvents: [Event] {
        events.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.startDate > b.startDate
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaviraTheme.Spacing.lg) {
                Text("Occasions")
                    .font(CaviraTheme.Typography.headline)
                    .foregroundStyle(CaviraTheme.textPrimary)

                Text("Your events from Calendar — pinned occasions stay at the top.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if sortedEvents.isEmpty {
                    EmptyStateView(
                        title: "No occasions yet",
                        subtitle: "Create one in the Calendar tab, or tap + to import photos and start a new occasion from the import sheet."
                    )
                    .padding(.vertical, CaviraTheme.Spacing.lg)
                } else {
                    LazyVStack(spacing: CaviraTheme.Spacing.md) {
                        ForEach(sortedEvents, id: \.id) { event in
                            NavigationLink(value: event.id) {
                                EventCardView(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CaviraTheme.Spacing.md)
            .padding(.vertical, CaviraTheme.Spacing.md)
        }
    }
}

#Preview {
    NavigationStack {
        HomeEventsSummaryView()
    }
    .caviraPreviewShell()
}
