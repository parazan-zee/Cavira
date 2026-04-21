import SwiftData
import SwiftUI
import UIKit

struct EditTagsSheet: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: PhotoEntry

    @State private var titleText: String = ""
    @State private var locationQuery = ""
    @State private var peopleQuery = ""
    @State private var freeTextPerson = ""

    @State private var contactResults: [ContactResult] = []

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                locationSection
                peopleSection
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
            .onAppear {
                titleText = entry.title ?? ""
            }
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Title", text: $titleText)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(CaviraTheme.textPrimary)
                .onChange(of: titleText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry.title = trimmed.isEmpty ? nil : trimmed
                    try? modelContext.save()
                }

            Text("Add a short title so this photo is easier to find later.")
                .font(CaviraTheme.Typography.caption)
                .foregroundStyle(CaviraTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Details")
                .foregroundStyle(CaviraTheme.textSecondary)
        }
    }

    private var locationSection: some View {
        Section {
            if let tag = entry.locationTag {
                TagChipView(label: tag.name, systemImage: "mappin.and.ellipse") {
                    entry.locationTag = nil
                    try? modelContext.save()
                }
            } else {
                Text("No location set.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }

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
        } header: {
            Text("Location")
                .foregroundStyle(CaviraTheme.textSecondary)
        }
        .task(id: locationQuery) {
            guard let s = appServices else { return }
            await s.locationSearch.search(query: locationQuery)
        }
        .onChange(of: entry.locationTag?.name) { _, _ in
            if entry.locationTag != nil {
                locationQuery = ""
                appServices?.locationSearch.clear()
            }
        }
    }

    private var peopleSection: some View {
        Section {
            if !entry.peopleTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CaviraTheme.Spacing.sm) {
                        ForEach(entry.peopleTags, id: \.id) { p in
                            TagChipView(label: p.displayName, systemImage: "person.fill") {
                                removePerson(p)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No people tagged.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: CaviraTheme.Spacing.sm) {
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
            }

            Divider()

            VStack(alignment: .leading, spacing: CaviraTheme.Spacing.sm) {
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
        .task(id: peopleQuery) {
            await refreshContactResults()
        }
    }

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
        entry.locationTag = tag
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
        if let existing = tags.first(where: { $0.contactIdentifier == contact.contactIdentifier }) {
            if entry.peopleTags.contains(where: { $0.id == existing.id }) { return }
            entry.peopleTags.append(existing)
            ensurePlacementExists(for: existing.id)
            try? modelContext.save()
            return
        }

        let person = PersonTag(
            contactIdentifier: contact.contactIdentifier,
            displayName: contact.displayName,
            thumbnailData: contact.thumbnailData
        )
        modelContext.insert(person)

        entry.peopleTags.append(person)
        ensurePlacementExists(for: person.id)
        try? modelContext.save()
    }

    private func addFreeTextPerson() {
        let trimmed = freeTextPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<PersonTag>()
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        if let existing = tags.first(where: { $0.contactIdentifier == nil && $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            if !entry.peopleTags.contains(where: { $0.id == existing.id }) {
                entry.peopleTags.append(existing)
                ensurePlacementExists(for: existing.id)
            }
            freeTextPerson = ""
            try? modelContext.save()
            return
        }

        let person = PersonTag(displayName: trimmed)
        modelContext.insert(person)

        if !entry.peopleTags.contains(where: { $0.id == person.id }) {
            entry.peopleTags.append(person)
            ensurePlacementExists(for: person.id)
        }

        freeTextPerson = ""
        try? modelContext.save()
    }

    private func ensurePlacementExists(for personID: UUID) {
        if entry.peopleTagPlacements.contains(where: { $0.personTagId == personID }) { return }
        var placements = entry.peopleTagPlacements
        // Default placement = top-left stack start (actual display is stacked by default; placement mode can override).
        placements.append(PersonTagPlacement(personTagId: personID, x: 0.12, y: 0.14))
        entry.peopleTagPlacements = placements
    }

    private func removePerson(_ person: PersonTag) {
        entry.peopleTags.removeAll(where: { $0.id == person.id })
        entry.peopleTagPlacements = entry.peopleTagPlacements.filter { $0.personTagId != person.id }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        Text("Preview host")
            .sheet(isPresented: .constant(true)) {
                EditTagsSheet(entry: PhotoEntry(storageMode: .reference, capturedDate: Date()))
                    .appServices(AppServices())
            }
    }
    .caviraPreviewShell()
}

