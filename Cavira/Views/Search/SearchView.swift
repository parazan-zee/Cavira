import SwiftData
import SwiftUI

struct SearchView: View {
    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]
    @Query(sort: \LocationTag.name, order: .forward) private var locations: [LocationTag]
    @Query(sort: \PersonTag.displayName, order: .forward) private var people: [PersonTag]
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    @State private var query = ""
    @State private var isSearchPresented = true

    @State private var selectedLocationID: UUID?
    @State private var selectedPersonID: UUID?
    @State private var selectedEventID: UUID?

    @State private var dateStart: Date?
    @State private var dateEnd: Date?

    @State private var showLocationPicker = false
    @State private var showPeoplePicker = false
    @State private var showEventPicker = false
    @State private var showDatePicker = false

    private enum SortOrder: String, CaseIterable {
        case newestFirst
        case oldestFirst

        var label: String { self == .newestFirst ? "Newest" : "Oldest" }
    }

    @State private var sortOrder: SortOrder = .newestFirst

    private var filtered: [PhotoEntry] {
        var rows = photos

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let needle = trimmed.lowercased()
            rows = rows.filter { entry in
                let haystacks: [String] = [
                    entry.title ?? "",
                    entry.notes ?? "",
                    entry.locationTag?.name ?? "",
                    entry.event?.title ?? "",
                    entry.peopleTags.map(\.displayName).joined(separator: " "),
                ]
                return haystacks.joined(separator: "\n").lowercased().contains(needle)
            }
        }

        if let selectedLocationID {
            rows = rows.filter { $0.locationTag?.id == selectedLocationID }
        }
        if let selectedPersonID {
            rows = rows.filter { entry in
                entry.peopleTags.contains(where: { $0.id == selectedPersonID })
            }
        }
        if let selectedEventID {
            rows = rows.filter { $0.event?.id == selectedEventID }
        }

        if let dateStart {
            rows = rows.filter { $0.capturedDate >= dateStart }
        }
        if let dateEnd {
            rows = rows.filter { $0.capturedDate <= dateEnd }
        }

        switch sortOrder {
        case .newestFirst:
            return rows.sorted { $0.capturedDate > $1.capturedDate }
        case .oldestFirst:
            return rows.sorted { $0.capturedDate < $1.capturedDate }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaviraTheme.Spacing.md) {
            filterRow
                .padding(.horizontal, CaviraTheme.Spacing.md)
                .padding(.top, CaviraTheme.Spacing.sm)

            HStack {
                Text("\(filtered.count) \(filtered.count == 1 ? "result" : "results")")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
                Spacer()
                Menu {
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.rawValue) { order in
                            Text(order.label).tag(order)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOrder.label)
                    }
                    .font(CaviraTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(CaviraTheme.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(CaviraTheme.surfaceCard.opacity(0.6), in: Capsule())
                }
            }
            .padding(.horizontal, CaviraTheme.Spacing.md)

            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: photos.isEmpty ? "Nothing to search yet" : "No results",
                    subtitle: photos.isEmpty ? "Add photos to your Cavira album, then search by title, location, people, or event." : "Try a different search or clear filters."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(filtered, id: \.id) { entry in
                            NavigationLink(value: entry.id) {
                                PhotoThumbnailView(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, CaviraTheme.Spacing.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(
            text: $query,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search title, people, places…"
        )
        .onAppear {
            // Keep the search bar visible by default, without forcing keyboard focus (avoids title/toolbar animation).
            isSearchPresented = true
        }
        .onChange(of: query) { _, newValue in
            // Treat the built-in clear (X) as “reset search”.
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearFilters()
            }
        }
        .sheet(isPresented: $showLocationPicker) { locationPickerSheet }
        .sheet(isPresented: $showPeoplePicker) { peoplePickerSheet }
        .sheet(isPresented: $showEventPicker) { eventPickerSheet }
        .sheet(isPresented: $showDatePicker) { dateRangeSheet }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
        ]
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CaviraTheme.Spacing.sm) {
                filterChip(
                    label: selectedLocationID.flatMap { id in locations.first(where: { $0.id == id })?.name } ?? "Location",
                    systemImage: "mappin.and.ellipse",
                    isActive: selectedLocationID != nil
                ) { showLocationPicker = true }

                filterChip(
                    label: selectedPersonID.flatMap { id in people.first(where: { $0.id == id })?.displayName } ?? "People",
                    systemImage: "person.fill",
                    isActive: selectedPersonID != nil
                ) { showPeoplePicker = true }

                filterChip(
                    label: dateLabel ?? "Date",
                    systemImage: "calendar",
                    isActive: dateStart != nil || dateEnd != nil
                ) { showDatePicker = true }

                filterChip(
                    label: selectedEventID.flatMap { id in events.first(where: { $0.id == id })?.title } ?? "Event",
                    systemImage: "sparkles",
                    isActive: selectedEventID != nil
                ) { showEventPicker = true }
            }
        }
    }

    private func clearFilters() {
        selectedLocationID = nil
        selectedPersonID = nil
        selectedEventID = nil
        dateStart = nil
        dateEnd = nil
    }

    private func filterChip(label: String, systemImage: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(label)
                    .lineLimit(1)
            }
            .font(CaviraTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(isActive ? CaviraTheme.textOnAccent : CaviraTheme.textSecondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isActive ? CaviraTheme.accent : CaviraTheme.surfaceCard.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var dateLabel: String? {
        guard dateStart != nil || dateEnd != nil else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let start = dateStart.map(df.string) ?? "Any"
        let end = dateEnd.map(df.string) ?? "Any"
        if start == "Any" { return "… \(end)" }
        if end == "Any" { return "\(start) …" }
        return "\(start) – \(end)"
    }

    private var locationPickerSheet: some View {
        NavigationStack {
            List {
                Button("Any location") {
                    selectedLocationID = nil
                    showLocationPicker = false
                }
                .foregroundStyle(CaviraTheme.textSecondary)

                ForEach(locations, id: \.id) { loc in
                    Button {
                        selectedLocationID = loc.id
                        showLocationPicker = false
                    } label: {
                        HStack {
                            Text(loc.name)
                                .foregroundStyle(CaviraTheme.textPrimary)
                            Spacer()
                            if selectedLocationID == loc.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CaviraTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showLocationPicker = false }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var peoplePickerSheet: some View {
        NavigationStack {
            List {
                Button("Anyone") {
                    selectedPersonID = nil
                    showPeoplePicker = false
                }
                .foregroundStyle(CaviraTheme.textSecondary)

                ForEach(people, id: \.id) { person in
                    Button {
                        selectedPersonID = person.id
                        showPeoplePicker = false
                    } label: {
                        HStack {
                            Text(person.displayName)
                                .foregroundStyle(CaviraTheme.textPrimary)
                            Spacer()
                            if selectedPersonID == person.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CaviraTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showPeoplePicker = false }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var eventPickerSheet: some View {
        NavigationStack {
            List {
                Button("Any event") {
                    selectedEventID = nil
                    showEventPicker = false
                }
                .foregroundStyle(CaviraTheme.textSecondary)

                ForEach(events, id: \.id) { ev in
                    Button {
                        selectedEventID = ev.id
                        showEventPicker = false
                    } label: {
                        HStack {
                            Text(ev.title)
                                .foregroundStyle(CaviraTheme.textPrimary)
                            Spacer()
                            if selectedEventID == ev.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CaviraTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showEventPicker = false }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var dateRangeSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { dateStart ?? Date() },
                            set: { dateStart = $0 }
                        ),
                        displayedComponents: [.date]
                    )
                    Toggle("Set start date", isOn: Binding(
                        get: { dateStart != nil },
                        set: { isOn in if !isOn { dateStart = nil } else { dateStart = Date() } }
                    ))
                    .tint(CaviraTheme.accent)
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                Section {
                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { dateEnd ?? Date() },
                            set: { dateEnd = $0 }
                        ),
                        displayedComponents: [.date]
                    )
                    Toggle("Set end date", isOn: Binding(
                        get: { dateEnd != nil },
                        set: { isOn in if !isOn { dateEnd = nil } else { dateEnd = Date() } }
                    ))
                    .tint(CaviraTheme.accent)
                }
                .listRowBackground(CaviraTheme.surfaceCard)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showDatePicker = false }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .caviraPreviewShell()
}
