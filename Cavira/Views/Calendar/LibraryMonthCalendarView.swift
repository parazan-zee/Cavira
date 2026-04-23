import SwiftUI

/// Read-only month grid: **Apple Photos** asset counts per day (images + videos), not Cavira’s album.
struct LibraryMonthCalendarView: View {
    @Binding var displayedMonth: Date
    let dayCounts: [Int: Int]
    /// When **true**, library counts are unavailable (denied / restricted); show guidance only.
    let libraryBlocked: Bool
    /// Optional footnote (e.g. limited library or access not yet granted).
    let footerNote: String?
    /// Called when the user taps a day cell.
    var onSelectDay: ((Date) -> Void)? = nil
    /// Optional Settings deep link action for denied/restricted permissions.
    var onOpenSettings: (() -> Void)? = nil

    @State private var showMonthYearJump = false
    @State private var jumpSelection: Date = .now

    private var calendar: Calendar { .current }

    private var weekdaySymbols: [String] {
        let s = calendar.shortStandaloneWeekdaySymbols
        let fw = max(0, calendar.firstWeekday - 1)
        return Array(s[fw...]) + Array(s[..<fw])
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: displayedMonth)
    }

    private var gridCells: [LibraryCalendarCell] {
        LibraryCalendarCell.buildGrid(for: displayedMonth, dayCounts: dayCounts, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaviraTheme.Spacing.md) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.accent)
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Button {
                    jumpSelection = startOfMonth(for: displayedMonth)
                    showMonthYearJump = true
                } label: {
                    HStack(spacing: CaviraTheme.Spacing.xs) {
                        Text(monthTitle)
                            .font(CaviraTheme.Typography.title)
                            .foregroundStyle(CaviraTheme.textPrimary)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.body)
                            .foregroundStyle(CaviraTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose month and year, \(monthTitle)")

                Spacer()

                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.accent)
                }
                .accessibilityLabel("Next month")
            }

            if libraryBlocked {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Allow Photos access in Settings to see library activity counts for each day.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)

                    if let onOpenSettings {
                        Button("Open Settings") {
                            onOpenSettings()
                        }
                        .font(CaviraTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(CaviraTheme.accent)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(CaviraTheme.surfaceElevated, in: Capsule())
                        .overlay(
                            Capsule().stroke(CaviraTheme.border, lineWidth: 1)
                        )
                        .accessibilityLabel("Open Settings")
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { sym in
                        Text(sym)
                            .font(CaviraTheme.Typography.micro)
                            .foregroundStyle(CaviraTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(gridCells) { cell in
                        if let day = cell.day {
                            Button {
                                guard let onSelectDay else { return }
                                if let date = calendar.date(from: DateComponents(
                                    year: calendar.component(.year, from: displayedMonth),
                                    month: calendar.component(.month, from: displayedMonth),
                                    day: day
                                )) {
                                    onSelectDay(date)
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(day)")
                                        .font(CaviraTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(CaviraTheme.textPrimary)
                                    if cell.count > 0 {
                                        Text("\(cell.count)")
                                            .font(CaviraTheme.Typography.micro)
                                            .foregroundStyle(CaviraTheme.accent)
                                    } else {
                                        Text(" ")
                                            .font(CaviraTheme.Typography.micro)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: CaviraTheme.Radius.small)
                                        .fill(CaviraTheme.surfaceCard.opacity(0.65))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Day \(day), \(cell.count) library items")
                        } else {
                            Color.clear
                                .frame(height: 40)
                        }
                    }
                }
                if let footerNote, !footerNote.isEmpty {
                    Text(footerNote)
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, CaviraTheme.Spacing.xs)
                }
            }
        }
        .padding(CaviraTheme.Spacing.md)
        .background(CaviraTheme.surfaceCard.opacity(0.4), in: RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium))
        .sheet(isPresented: $showMonthYearJump) {
            NavigationStack {
                VStack(spacing: CaviraTheme.Spacing.lg) {
                    DatePicker(
                        "",
                        selection: $jumpSelection,
                        in: jumpDateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(CaviraTheme.accent)

                    Button {
                        jumpSelection = startOfMonth(for: Date())
                    } label: {
                        Text("Jump to today’s month")
                            .font(CaviraTheme.Typography.body)
                    }
                    .foregroundStyle(CaviraTheme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(CaviraTheme.Spacing.lg)
                .background(CaviraTheme.backgroundSecondary)
                .navigationTitle("Go to month")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showMonthYearJump = false
                        }
                        .foregroundStyle(CaviraTheme.textSecondary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            displayedMonth = startOfMonth(for: jumpSelection)
                            showMonthYearJump = false
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(CaviraTheme.accent)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var jumpDateRange: ClosedRange<Date> {
        let now = Date()
        let past = calendar.date(byAdding: .year, value: -120, to: now) ?? now
        let future = calendar.date(byAdding: .year, value: 5, to: now) ?? now
        return past...future
    }

    /// First moment of the **calendar month** containing `date` (local time zone).
    private func startOfMonth(for date: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)) ?? date
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = d
        }
    }
}

private struct LibraryCalendarCell: Identifiable, Hashable {
    let id: Int
    let day: Int?
    let count: Int

    static func buildGrid(for month: Date, dayCounts: [Int: Int], calendar: Calendar) -> [LibraryCalendarCell] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month)
        else { return [] }

        let monthStart = interval.start
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [LibraryCalendarCell] = []
        var idCounter = 0
        for _ in 0 ..< leading {
            cells.append(LibraryCalendarCell(id: idCounter, day: nil, count: 0))
            idCounter += 1
        }
        for day in dayRange {
            let c = dayCounts[day] ?? 0
            cells.append(LibraryCalendarCell(id: idCounter, day: day, count: c))
            idCounter += 1
        }
        while cells.count % 7 != 0 {
            cells.append(LibraryCalendarCell(id: idCounter, day: nil, count: 0))
            idCounter += 1
        }
        return cells
    }
}

