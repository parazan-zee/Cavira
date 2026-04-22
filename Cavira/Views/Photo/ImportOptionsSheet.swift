import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// How imported items attach to an occasion when **`presetEvent`** is nil.
private enum ImportOccasionTarget: Hashable {
    case newOccasion
    case existing(UUID)
}

/// Confirmation step after picking library assets; performs reference-only import.
struct ImportOptionsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss

    let pickerResults: [PHPickerResult]
    /// When set (e.g. import from **`EventDetailView`**), items are linked to this occasion; the event picker is hidden.
    var presetEvent: Event? = nil

    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    // Add-time metadata (Title → Location → People → Event)
    @State private var titleText: String = ""
    @State private var didAttemptAdd = false

    @State private var locationQuery = ""
    @State private var appliedLocationTag: LocationTag?

    @State private var peopleQuery = ""
    @State private var contactResults: [ContactResult] = []
    @State private var freeTextPerson = ""
    @State private var appliedPeopleTags: [PersonTag] = []

    @State private var addToEvent = false
    @State private var newOccasionTitle: String = ""
    @State private var occasionTarget: ImportOccasionTarget = .newOccasion
    @State private var importErrorMessage: String?
    @State private var showImportMessageAlert = false
    @State private var isImporting = false

    private var itemCount: Int {
        pickerResults.count
    }

    private var titleInvalid: Bool {
        guard itemCount == 1 else { return false }
        return didAttemptAdd && titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `true` when “Add to an event” is on but the user has not satisfied title / picker rules.
    private var occasionAssignmentInvalid: Bool {
        guard presetEvent == nil, addToEvent else { return false }
        if events.isEmpty {
            return newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        switch occasionTarget {
        case .newOccasion:
            return newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .existing:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if itemCount == 1 {
                        TextField("Title", text: $titleText)
                            .textInputAutocapitalization(.sentences)
                            .foregroundStyle(CaviraTheme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium, style: .continuous)
                                    .stroke(titleInvalid ? CaviraTheme.destructive : .clear, lineWidth: 1.5)
                            )

                        if titleInvalid {
                            Text("Title is required.")
                                .font(CaviraTheme.Typography.caption)
                                .foregroundStyle(CaviraTheme.destructive)
                        }
                    } else {
                        Text("Title can be added after saving (Edit).")
                            .font(CaviraTheme.Typography.caption)
                            .foregroundStyle(CaviraTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text("Title")
                            .foregroundStyle(CaviraTheme.textSecondary)
                        if itemCount == 1 {
                            Text("*")
                                .foregroundStyle(CaviraTheme.destructive)
                        }
                    }
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                Section {
                    if let appliedLocationTag {
                        TagChipView(label: appliedLocationTag.name, systemImage: "mappin.and.ellipse") {
                            self.appliedLocationTag = nil
                        }
                    } else {
                        TextField("Search location", text: $locationQuery)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .foregroundStyle(CaviraTheme.textPrimary)

                        if let s = appServices {
                            ForEach(s.locationSearch.results) { r in
                                Button {
                                    Task { await selectLocationSuggestion(r.id) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.name)
                                            .font(CaviraTheme.Typography.body)
                                            .foregroundStyle(CaviraTheme.textPrimary)
                                        if !r.subtitle.isEmpty {
                                            Text(r.subtitle)
                                                .font(CaviraTheme.Typography.caption)
                                                .foregroundStyle(CaviraTheme.textTertiary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }

                            if !s.locationSearch.results.isEmpty {
                                Text("Search powered by Apple Maps")
                                    .font(CaviraTheme.Typography.micro)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, CaviraTheme.Spacing.xs)
                            }
                        }
                    }
                } header: {
                    Text("Location")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                .listRowBackground(CaviraTheme.surfaceCard)
                .task(id: locationQuery) {
                    guard appliedLocationTag == nil else { return }
                    guard let s = appServices else { return }
                    await s.locationSearch.search(query: locationQuery)
                }

                Section {
                    if !appliedPeopleTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: CaviraTheme.Spacing.sm) {
                                ForEach(appliedPeopleTags, id: \.id) { p in
                                    TagChipView(label: p.displayName, systemImage: "person.fill") {
                                        appliedPeopleTags.removeAll(where: { $0.id == p.id })
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    TextField("Search contacts", text: $peopleQuery)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .foregroundStyle(CaviraTheme.textPrimary)

                    if let contacts = appServices?.contacts {
                        switch contacts.authorizationStatus {
                        case .authorized:
                            ForEach(contactResults) { r in
                                Button {
                                    addContactPerson(r)
                                } label: {
                                    HStack(spacing: CaviraTheme.Spacing.md) {
                                        contactAvatar(thumbnailData: r.thumbnailData, name: r.displayName)
                                        Text(r.displayName)
                                            .font(CaviraTheme.Typography.body)
                                            .foregroundStyle(CaviraTheme.textPrimary)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        case .notDetermined:
                            Button("Allow Contacts access") {
                                Task { _ = await contacts.requestAuthorization() }
                            }
                            .foregroundStyle(CaviraTheme.accent)
                        default:
                            Text("Contacts access is off. You can still add free-text tags below.")
                                .font(CaviraTheme.Typography.caption)
                                .foregroundStyle(CaviraTheme.textTertiary)
                        }
                    }

                    Divider()

                    HStack(spacing: CaviraTheme.Spacing.md) {
                        TextField("Add a person (free text)", text: $freeTextPerson)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .foregroundStyle(CaviraTheme.textPrimary)
                        Button("Add") { addFreeTextPerson() }
                            .foregroundStyle(CaviraTheme.accent)
                            .disabled(freeTextPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("People")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                .listRowBackground(CaviraTheme.surfaceCard)
                .task(id: peopleQuery) {
                    await refreshContactResults()
                }

                Section {
                    if let locked = presetEvent {
                        LabeledContent("Occasion") {
                            Text(locked.title)
                                .font(CaviraTheme.Typography.body)
                                .foregroundStyle(CaviraTheme.textSecondary)
                        }
                        Text("New picks are added to your Cavira album and linked to this occasion.")
                            .font(CaviraTheme.Typography.caption)
                            .foregroundStyle(CaviraTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Toggle("Add to an event", isOn: $addToEvent)
                            .tint(CaviraTheme.accent)
                        if addToEvent {
                            if events.isEmpty {
                                Text("New occasion")
                                    .font(CaviraTheme.Typography.caption)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                                TextField("Occasion name", text: $newOccasionTitle)
                                    .foregroundStyle(CaviraTheme.textPrimary)
                                Text("A new occasion is created when you import. You can edit dates in Calendar.")
                                    .font(CaviraTheme.Typography.caption)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Picker("Assign to", selection: $occasionTarget) {
                                    Text("New occasion…").tag(ImportOccasionTarget.newOccasion)
                                    ForEach(events, id: \.id) { ev in
                                        Text(ev.title).tag(ImportOccasionTarget.existing(ev.id))
                                    }
                                }
                                .tint(CaviraTheme.accent)

                                if occasionTarget == .newOccasion {
                                    TextField("New occasion name", text: $newOccasionTitle)
                                        .foregroundStyle(CaviraTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(CaviraTheme.surfaceCard)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle(itemCount == 1 ? "Add 1 item" : "Add \(itemCount) items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { runImport() }
                        .fontWeight(.semibold)
                        .foregroundStyle(CaviraTheme.accent)
                        .disabled(isImporting || occasionAssignmentInvalid)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView()
                        .tint(CaviraTheme.accent)
                        .padding()
                        .background(CaviraTheme.surfaceElevated.opacity(0.95), in: RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium))
                }
            }
            .alert("Add", isPresented: $showImportMessageAlert) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .onAppear {
                guard presetEvent == nil else { return }
                addToEvent = false
                newOccasionTitle = ""
                occasionTarget = events.first.map { .existing($0.id) } ?? .newOccasion
            }
        }
    }

    private func runImport() {
        guard let services = appServices else { return }
        didAttemptAdd = true
        if itemCount == 1, titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            importErrorMessage = "Please enter a title."
            showImportMessageAlert = true
            return
        }

        let event: Event? = {
            if let presetEvent { return presetEvent }
            guard addToEvent else { return nil }

            if events.isEmpty {
                let t = newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let e = Event(title: t, startDate: .now, endDate: nil, isPinned: false)
                modelContext.insert(e)
                try? modelContext.save()
                return e
            }

            switch occasionTarget {
            case .newOccasion:
                let t = newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let e = Event(title: t, startDate: .now, endDate: nil, isPinned: false)
                modelContext.insert(e)
                try? modelContext.save()
                return e
            case .existing(let id):
                return events.first { $0.id == id }
            }
        }()

        if presetEvent == nil, addToEvent, event == nil {
            importErrorMessage = "Enter an occasion name, pick an existing occasion, or turn off “Add to an event”."
            showImportMessageAlert = true
            return
        }

        isImporting = true
        Task { @MainActor in
            defer { isImporting = false }
            do {
                let touched = try PhotoImportService.importPickerResults(
                    pickerResults,
                    event: event,
                    context: modelContext,
                    photoLibrary: services.photoLibrary
                )
                if touched.isEmpty, !pickerResults.isEmpty {
                    importErrorMessage = "Nothing new was added. Selected items may already be in your album."
                    showImportMessageAlert = true
                } else {
                    applyMetadata(to: touched)
                    dismiss()
                }
            } catch {
                importErrorMessage = error.localizedDescription
                showImportMessageAlert = true
            }
        }
    }

    @MainActor
    private func applyMetadata(to entries: [PhotoEntry]) {
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleToApply = trimmedTitle.isEmpty ? nil : trimmedTitle

        for entry in entries {
            if itemCount == 1 {
                entry.title = titleToApply
            }
            if let appliedLocationTag {
                entry.locationTag = appliedLocationTag
            }
            if !appliedPeopleTags.isEmpty {
                for p in appliedPeopleTags where !entry.peopleTags.contains(where: { $0.id == p.id }) {
                    entry.peopleTags.append(p)
                }
                var placements = entry.peopleTagPlacements
                for p in appliedPeopleTags where !placements.contains(where: { $0.personTagId == p.id }) {
                    placements.append(PersonTagPlacement(personTagId: p.id, x: 0.12, y: 0.14))
                }
                entry.peopleTagPlacements = placements
            }
        }
        try? modelContext.save()
    }

    // MARK: - Location selection

    @MainActor
    private func selectLocationSuggestion(_ id: UUID) async {
        guard let s = appServices else { return }
        guard let resolved = await s.locationSearch.resolveSelection(id: id) else { return }

        let existing = findExistingLocationTag(for: resolved)
        let tag: LocationTag
        if let existing {
            tag = existing
        } else {
            tag = LocationTag(
                name: resolved.name,
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                mapKitPlaceID: resolved.mapKitPlaceID
            )
            modelContext.insert(tag)
        }
        appliedLocationTag = tag
        locationQuery = ""
        s.locationSearch.clear()
        try? modelContext.save()
    }

    private func findExistingLocationTag(for resolved: LocationResult) -> LocationTag? {
        let descriptor = FetchDescriptor<LocationTag>()
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        if let placeID = resolved.mapKitPlaceID, !placeID.isEmpty {
            return tags.first { $0.mapKitPlaceID == placeID }
        }
        return tags.first {
            $0.name.caseInsensitiveCompare(resolved.name) == .orderedSame
            && $0.latitude == resolved.latitude
            && $0.longitude == resolved.longitude
        }
    }

    // MARK: - People selection

    @MainActor
    private func refreshContactResults() async {
        guard let contacts = appServices?.contacts else { return }
        guard contacts.authorizationStatus == .authorized else {
            contactResults = []
            return
        }
        contactResults = await contacts.search(query: peopleQuery)
    }

    private func contactAvatar(thumbnailData: Data?, name: String) -> some View {
        Group {
            if let thumbnailData, let img = UIImage(data: thumbnailData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(CaviraTheme.surfaceCard.opacity(0.7))
                    Text(initials(for: name))
                        .font(CaviraTheme.Typography.micro.weight(.semibold))
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + last).uppercased()
        return combined.isEmpty ? "?" : combined
    }

    private func addContactPerson(_ contact: ContactResult) {
        let descriptor = FetchDescriptor<PersonTag>()
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        let person: PersonTag
        if let existing = tags.first(where: { $0.contactIdentifier == contact.contactIdentifier }) {
            person = existing
        } else {
            let created = PersonTag(
                contactIdentifier: contact.contactIdentifier,
                displayName: contact.displayName,
                thumbnailData: contact.thumbnailData
            )
            modelContext.insert(created)
            person = created
        }
        if !appliedPeopleTags.contains(where: { $0.id == person.id }) {
            appliedPeopleTags.append(person)
        }
        try? modelContext.save()
    }

    private func addFreeTextPerson() {
        let trimmed = freeTextPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<PersonTag>()
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        let person: PersonTag
        if let existing = tags.first(where: { $0.contactIdentifier == nil && $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            person = existing
        } else {
            let created = PersonTag(displayName: trimmed)
            modelContext.insert(created)
            person = created
        }
        if !appliedPeopleTags.contains(where: { $0.id == person.id }) {
            appliedPeopleTags.append(person)
        }
        freeTextPerson = ""
        try? modelContext.save()
    }
}
