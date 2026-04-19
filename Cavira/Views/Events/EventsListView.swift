import SwiftData
import SwiftUI

/// **Calendar** tab: read-only **Photos library** month counts + user **occasions** list.
struct EventsListView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    @State private var displayedMonth = Date()
    @State private var dayCounts: [Int: Int] = [:]
    @State private var showNewEvent = false

    private var sortedEvents: [Event] {
        events.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.startDate > b.startDate
        }
    }

    private var libraryBlocked: Bool {
        guard let s = appServices else { return true }
        switch s.photoLibrary.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var calendarFooterNote: String? {
        guard let s = appServices else { return nil }
        switch s.photoLibrary.authorizationStatus {
        case .limited:
            return "Counts reflect your selected library only. For every day, set Photos access to All Photos for Cavira in Settings."
        case .notDetermined:
            return "When Cavira asks for photo access, choose Allow so this grid can count your library by day."
        default:
            return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaviraTheme.Spacing.xl) {
                Text("Library activity")
                    .font(CaviraTheme.Typography.headline)
                    .foregroundStyle(CaviraTheme.textPrimary)

                LibraryMonthCalendarView(
                    displayedMonth: $displayedMonth,
                    dayCounts: dayCounts,
                    libraryBlocked: libraryBlocked,
                    footerNote: calendarFooterNote
                )

                Text("Occasions")
                    .font(CaviraTheme.Typography.headline)
                    .foregroundStyle(CaviraTheme.textPrimary)

                if sortedEvents.isEmpty {
                    EmptyStateView(
                        title: "Create your first event",
                        subtitle: "Group holidays, trips, or moments — then add photos from + on Home or here after opening an event."
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
            .padding(.horizontal, CaviraTheme.Spacing.md)
            .padding(.vertical, CaviraTheme.Spacing.md)
        }
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AlbumImportToolbarButton(accessibilityLabel: "New event") {
                    showNewEvent = true
                }
            }
        }
        .sheet(isPresented: $showNewEvent) {
            CreateEditEventView(existing: nil)
        }
        .task(id: displayedMonth) {
            await refreshCounts()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshCounts() }
        }
    }

    @MainActor
    private func refreshCounts() async {
        guard let services = appServices else {
            dayCounts = [:]
            return
        }
        services.photoLibrary.refreshAuthorizationStatus()
        switch services.photoLibrary.authorizationStatus {
        case .authorized, .limited:
            dayCounts = services.photoLibrary.assetCountsByDayInMonth(containing: displayedMonth)
        default:
            dayCounts = [:]
        }
    }
}

#Preview {
    NavigationStack {
        EventsListView()
    }
    .caviraPreviewShell()
}
