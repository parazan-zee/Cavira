import SwiftData
import SwiftUI

struct SearchView: View {
    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true || $0.homeCollection != nil },
        sort: \PhotoEntry.capturedDate,
        order: .reverse
    )
    private var catalogPhotos: [PhotoEntry]

    @Query(sort: \HomeCollection.createdDate, order: .reverse)
    private var homeCollections: [HomeCollection]

    @Query(sort: \LocationTag.name, order: .forward) private var locations: [LocationTag]
    @Query(sort: \PersonTag.displayName, order: .forward) private var people: [PersonTag]

    private enum SearchResultRow: Identifiable {
        case entry(PhotoEntry)
        case collection(HomeCollection)

        var id: String {
            switch self {
            case .entry(let e): "e:\(e.id.uuidString)"
            case .collection(let c): "c:\(c.id.uuidString)"
            }
        }

        var sortDate: Date {
            switch self {
            case .entry(let e): e.capturedDate
            case .collection(let c): c.coverEntry?.capturedDate ?? c.createdDate
            }
        }
    }

    @State private var query = ""

    @State private var selectedLocationID: UUID?
    @State private var selectedPersonID: UUID?

    @State private var dateStart: Date?
    @State private var dateEnd: Date?

    @State private var showLocationPicker = false
    @State private var showPeoplePicker = false
    @State private var showDatePicker = false

    private enum SortOrder: String, CaseIterable {
        case newestFirst
        case oldestFirst

        var label: String { self == .newestFirst ? "Newest" : "Oldest" }
    }

    @State private var sortOrder: SortOrder = .newestFirst

    private var hasActiveFilters: Bool {
        selectedLocationID != nil
            || selectedPersonID != nil
            || dateStart != nil
            || dateEnd != nil
    }

    private var hasAnySearchState: Bool {
        hasActiveFilters || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sortOrder != .newestFirst
    }

    private var filteredRows: [SearchResultRow] {
        var rows: [SearchResultRow] = []
        var entryRows = catalogPhotos

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let needle = trimmed.lowercased()
            entryRows = entryRows.filter { entry in
                let haystacks: [String] = [
                    entry.title ?? "",
                    entry.notes ?? "",
                    entry.locationTag?.name ?? "",
                    entry.peopleTags.map(\.displayName).joined(separator: " "),
                ]
                return haystacks.joined(separator: "\n").lowercased().contains(needle)
            }
        }

        if let selectedLocationID {
            entryRows = entryRows.filter { $0.locationTag?.id == selectedLocationID }
        }
        if let selectedPersonID {
            entryRows = entryRows.filter { entry in
                entry.peopleTags.contains(where: { $0.id == selectedPersonID })
            }
        }
        if let dateStart {
            entryRows = entryRows.filter { $0.capturedDate >= dateStart }
        }
        if let dateEnd {
            entryRows = entryRows.filter { $0.capturedDate <= dateEnd }
        }

        rows.append(contentsOf: entryRows.map { SearchResultRow.entry($0) })

        let needle = trimmed.lowercased()
        if !needle.isEmpty {
            for collection in homeCollections where collection.coverEntry != nil {
                guard collection.title.lowercased().contains(needle) else { continue }
                guard collectionMatchesFilters(collection) else { continue }
                let cid = collection.id
                if !rows.contains(where: { row in
                    if case .collection(let c) = row { return c.id == cid }
                    return false
                }) {
                    rows.append(.collection(collection))
                }
            }
        }

        switch sortOrder {
        case .newestFirst:
            return rows.sorted { $0.sortDate > $1.sortDate }
        case .oldestFirst:
            return rows.sorted { $0.sortDate < $1.sortDate }
        }
    }

    private func collectionMatchesFilters(_ collection: HomeCollection) -> Bool {
        if let selectedLocationID {
            let ok = collection.entries.contains { $0.locationTag?.id == selectedLocationID }
            if !ok { return false }
        }
        if let selectedPersonID {
            let ok = collection.entries.contains { entry in
                entry.peopleTags.contains { $0.id == selectedPersonID }
            }
            if !ok { return false }
        }
        let anchor = collection.coverEntry?.capturedDate ?? collection.createdDate
        if let dateStart, anchor < dateStart { return false }
        if let dateEnd, anchor > dateEnd { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaviraTheme.Spacing.md) {
            searchHeader
                .padding(.horizontal, CaviraTheme.Spacing.md)

            filterRow
                .padding(.horizontal, CaviraTheme.Spacing.md)

            HStack {
                Text("\(filteredRows.count) \(filteredRows.count == 1 ? "result" : "results")")
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

            if filteredRows.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: catalogPhotos.isEmpty && homeCollections.isEmpty ? "Nothing to search yet" : "Nothing found",
                    subtitle: catalogPhotos.isEmpty && homeCollections.isEmpty
                        ? "Add photos or collections to your Cavira album, then search by title, location, or people."
                        : nil
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(filteredRows) { row in
                            switch row {
                            case .entry(let entry):
                                NavigationLink(value: SearchBrowseDestination.photo(entry.id)) {
                                    PhotoThumbnailView(entry: entry)
                                }
                                .buttonStyle(.plain)
                            case .collection(let collection):
                                NavigationLink(value: SearchBrowseDestination.collection(collection.id)) {
                                    searchCollectionCell(collection)
                                }
                                .buttonStyle(.plain)
                            }
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
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showLocationPicker) { locationPickerSheet }
        .sheet(isPresented: $showPeoplePicker) { peoplePickerSheet }
        .sheet(isPresented: $showDatePicker) { dateRangeSheet }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
        ]
    }

    private func searchCollectionCell(_ collection: HomeCollection) -> some View {
        ZStack(alignment: .topTrailing) {
            if let cover = collection.coverEntry {
                PhotoThumbnailView(entry: cover)
            } else {
                Rectangle()
                    .fill(CaviraTheme.surfacePhoto)
                    .aspectRatio(1, contentMode: .fit)
            }
            Image(systemName: "square.stack.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(5)
                .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(6)
        }
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
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: CaviraTheme.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CaviraTheme.textTertiary)

                TextField("Search title, people, places…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(CaviraTheme.textPrimary)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CaviraTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search text")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(CaviraTheme.surfaceCard.opacity(0.6), in: Capsule())

            Button {
                clearAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CaviraTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(CaviraTheme.surfaceCard.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset search and filters")
            .opacity(hasAnySearchState ? 1 : 0.65)
        }
    }

    private func clearFilters() {
        selectedLocationID = nil
        selectedPersonID = nil
        dateStart = nil
        dateEnd = nil
    }

    private func clearAll() {
        query = ""
        clearFilters()
        sortOrder = .newestFirst
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
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
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
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
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
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
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
