import Photos
import SwiftUI

struct CalendarView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.scenePhase) private var scenePhase

    @State private var displayedMonth = Date()
    @State private var dayCounts: [Int: Int] = [:]

    @State private var selectedDay: Date?

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
                    footerNote: calendarFooterNote,
                    onSelectDay: { date in
                        selectedDay = date
                    }
                )

                RecapCarouselView(referenceDay: Date())
            }
            .padding(.horizontal, CaviraTheme.Spacing.md)
            .padding(.vertical, CaviraTheme.Spacing.md)
        }
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: displayedMonth) {
            await refreshCounts()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshCounts() }
        }
        .sheet(item: Binding(
            get: { selectedDay.map(CalendarDaySheetItem.init(date:)) },
            set: { newValue in if newValue == nil { selectedDay = nil } }
        )) { item in
            CalendarDayGridView(day: item.date)
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

private struct CalendarDaySheetItem: Identifiable, Equatable {
    let id: UUID
    let date: Date

    init(date: Date) {
        self.id = UUID()
        self.date = date
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .caviraPreviewShell()
}

