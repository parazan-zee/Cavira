import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Confirmation step after picking library assets; performs reference-only import.
struct ImportOptionsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss

    private let localIdentifiers: [String]

    init(pickerResults: [PHPickerResult]) {
        self.localIdentifiers = pickerResults.compactMap(\.assetIdentifier)
    }

    init(localIdentifiers: [String]) {
        self.localIdentifiers = localIdentifiers
    }

    // Add-time metadata (Title → Location → People)
    @State private var titleText: String = ""
    @State private var didAttemptAdd = false

    @State private var locationQuery = ""
    @State private var appliedLocationTag: LocationTag?

    @State private var peopleQuery = ""
    @State private var contactResults: [ContactResult] = []
    @State private var freeTextPerson = ""
    @State private var appliedPeopleTags: [PersonTag] = []

    @State private var importErrorMessage: String?
    @State private var showImportMessageAlert = false
    @State private var dismissAfterAlert = false
    @State private var isImporting = false

    private var itemCount: Int {
        localIdentifiers.count
    }

    private var titleInvalid: Bool {
        guard itemCount == 1 else { return false }
        return didAttemptAdd && titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle(itemCount == 1 ? "Add 1 item" : "Add \(itemCount) items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        didAttemptAdd = true
                        runImport()
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(CaviraTheme.accent)
                        .disabled(isImporting)
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
                    if dismissAfterAlert {
                        dismissAfterAlert = false
                        dismiss()
                    }
                }
            } message: {
                Text(importErrorMessage ?? "")
            }
        }
    }

    private func runImport() {
        guard let services = appServices else { return }
        if itemCount == 1, titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Inline validation handles this state; avoid alerts which can conflict with sheet presentation timing.
            return
        }

        isImporting = true
        Task { @MainActor in
            defer { isImporting = false }
            do {
                let touched = try PhotoImportService.importLocalIdentifiers(
                    localIdentifiers,
                    context: modelContext,
                    photoLibrary: services.photoLibrary
                )
                // Importing via this sheet always adds items to the Home album, even if the entries
                // already exist in SwiftData (e.g. created from Stories first).
                var affectedById: [UUID: PhotoEntry] = [:]
                for entry in touched {
                    affectedById[entry.id] = entry
                }
                for lid in localIdentifiers {
                    if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext) {
                        affectedById[existing.id] = existing
                    }
                }

                let affected = Array(affectedById.values)
                if affected.isEmpty, !localIdentifiers.isEmpty {
                    importErrorMessage = "Nothing new was added. Selected items may already be in your album."
                    dismissAfterAlert = false
                    showImportMessageAlert = true
                    return
                }

                // Only show a message if *everything* selected is already in the Home album.
                let alreadyInHomeCount = affected.filter { $0.isInHomeAlbum }.count
                if alreadyInHomeCount == affected.count, !affected.isEmpty {
                    importErrorMessage = "Already in your album. Pick something else to add."
                    dismissAfterAlert = true
                    showImportMessageAlert = true
                    return
                }

                for entry in affected { entry.isInHomeAlbum = true }
                applyMetadata(to: affected)
                dismiss()
            } catch {
                importErrorMessage = error.localizedDescription
                dismissAfterAlert = false
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
