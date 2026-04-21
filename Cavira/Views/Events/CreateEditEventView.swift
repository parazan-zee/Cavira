import SwiftData
import SwiftUI
import UIKit

/// Create (`existing == nil`) or edit an **`Event`** occasion.
struct CreateEditEventView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// `nil` = create a new event.
    var existing: Event?
    /// Called after the event row is deleted (e.g. parent **`EventDetailView`** should pop).
    var onEventDeleted: (() -> Void)? = nil

    @State private var title: String = ""
    @State private var eventDescription: String = ""

    @State private var locationQuery: String = ""
    @State private var appliedLocationTag: LocationTag?

    @State private var peopleQuery: String = ""
    @State private var contactResults: [ContactResult] = []
    @State private var freeTextPerson: String = ""
    @State private var appliedPeopleTags: [PersonTag] = []

    @State private var startDate: Date = .now
    @State private var hasEndDate = false
    @State private var endDate: Date = .now
    @State private var showDeleteConfirm = false
    /// `nil` = use automatic cover (**`EventCardView`** picks latest in album).
    @State private var coverPhotoIdPick: UUID?

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var sortedCoverCandidates: [PhotoEntry] {
        guard let e = existing else { return [] }
        return e.photos.sorted { $0.capturedDate > $1.capturedDate }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .foregroundStyle(CaviraTheme.textPrimary)
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
                    TextEditor(text: $eventDescription)
                        .frame(minHeight: 80)
                        .foregroundStyle(CaviraTheme.textPrimary)
                } header: {
                    Text("Description")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                .listRowBackground(CaviraTheme.surfaceCard)

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
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                        .tint(CaviraTheme.accent)
                    Toggle("End date", isOn: $hasEndDate)
                        .tint(CaviraTheme.accent)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .tint(CaviraTheme.accent)
                    }
                } header: {
                    Text("Dates")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                if isEditing, sortedCoverCandidates.count >= 2 {
                    Section {
                        Picker("Card thumbnail", selection: $coverPhotoIdPick) {
                            Text("Automatic (latest)").tag(nil as UUID?)
                            ForEach(sortedCoverCandidates, id: \.id) { p in
                                Text(coverRowLabel(for: p)).tag(Optional(p.id))
                            }
                        }
                        .tint(CaviraTheme.accent)
                    } header: {
                        Text("Cover photo")
                            .foregroundStyle(CaviraTheme.textSecondary)
                    }
                    .listRowBackground(CaviraTheme.surfaceCard)
                }

                if isEditing {
                    Section {
                        Button("Delete event", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                    .listRowBackground(CaviraTheme.surfaceCard)
                }
            }
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle(isEditing ? "Edit event" : "New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(CaviraTheme.accent)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let e = existing {
                    title = e.title
                    eventDescription = e.eventDescription ?? ""
                    startDate = e.startDate
                    coverPhotoIdPick = e.coverPhotoId
                    appliedLocationTag = e.locationTag
                    appliedPeopleTags = e.peopleTags
                    if let ed = e.endDate {
                        hasEndDate = true
                        endDate = ed
                    } else {
                        hasEndDate = false
                        endDate = e.startDate
                    }
                }
            }
            .confirmationDialog(
                "Delete this event?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteExisting()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photos stay in your album; only the occasion and links are removed.")
            }
        }
    }

    private func coverRowLabel(for entry: PhotoEntry) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        switch entry.mediaKind {
        case .video:
            return "Video · \(f.string(from: entry.capturedDate))"
        case .image:
            return entry.isLivePhoto ? "Live Photo · \(f.string(from: entry.capturedDate))" : "Photo · \(f.string(from: entry.capturedDate))"
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let desc = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue: String? = desc.isEmpty ? nil : desc
        let endValue: Date? = hasEndDate ? endDate : nil

        if let e = existing {
            e.title = trimmed
            e.eventDescription = descriptionValue
            e.startDate = startDate
            e.endDate = endValue
            e.locationTag = appliedLocationTag
            e.peopleTags = appliedPeopleTags
            if sortedCoverCandidates.count >= 2 {
                if let pick = coverPhotoIdPick, sortedCoverCandidates.contains(where: { $0.id == pick }) {
                    e.coverPhotoId = pick
                } else {
                    e.coverPhotoId = nil
                }
            }
        } else {
            let e = Event(
                title: trimmed,
                eventDescription: descriptionValue,
                startDate: startDate,
                endDate: endValue,
                locationTag: appliedLocationTag,
                peopleTags: appliedPeopleTags,
                isPinned: false
            )
            modelContext.insert(e)
        }
        try? modelContext.save()
        dismiss()
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

    private func deleteExisting() {
        guard let e = existing else { return }
        for p in e.photos {
            p.event = nil
        }
        modelContext.delete(e)
        try? modelContext.save()
        onEventDeleted?()
        dismiss()
    }
}
