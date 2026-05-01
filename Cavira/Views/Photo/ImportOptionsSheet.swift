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
    @State private var importProgressCurrent: Int = 0
    @State private var importProgressTotal: Int = 0

    @State private var collectionTitleText: String = ""
    @State private var didAttemptCollectionAdd = false

    private var itemCount: Int {
        localIdentifiers.count
    }

    private var isMultiItemCollectionFlow: Bool {
        itemCount >= 2
    }

    private var titleInvalid: Bool {
        guard itemCount == 1 else { return false }
        return didAttemptAdd && titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var collectionTitleInvalid: Bool {
        guard isMultiItemCollectionFlow else { return false }
        return didAttemptCollectionAdd && collectionTitleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                introSection
                titleOrMetadataSection
                locationAndPeopleSections
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if isMultiItemCollectionFlow {
                            didAttemptCollectionAdd = true
                            runCollectionImport()
                        } else {
                            didAttemptAdd = true
                            runImport()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(CaviraTheme.accent)
                    .disabled(isImporting)
                }
            }
            .overlay {
                if isImporting {
                    importProgressOverlay
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isImporting)
    }

    @ViewBuilder
    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if itemCount == 1 {
                    Text("Add 1 item")
                        .font(CaviraTheme.Typography.title)
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Text("Add a title (required), and optionally tag a location and people.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("New collection · \(itemCount) photos")
                        .font(CaviraTheme.Typography.title)
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Text("Add a collection title (required). Location and people apply to every photo.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(CaviraTheme.backgroundSecondary)
    }

    @ViewBuilder
    private var titleOrMetadataSection: some View {
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
                TextField("Collection title", text: $collectionTitleText)
                    .textInputAutocapitalization(.sentences)
                    .foregroundStyle(CaviraTheme.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium, style: .continuous)
                            .stroke(collectionTitleInvalid ? CaviraTheme.destructive : .clear, lineWidth: 1.5)
                    )

                if collectionTitleInvalid {
                    Text("Collection title is required.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.destructive)
                }
            }
        } header: {
            HStack(spacing: 4) {
                Text(itemCount == 1 ? "Title" : "Collection")
                    .foregroundStyle(CaviraTheme.textSecondary)
                Text("*")
                    .foregroundStyle(CaviraTheme.destructive)
            }
        }
        .listRowBackground(CaviraTheme.surfaceCard)
    }

    @ViewBuilder
    private var locationAndPeopleSections: some View {
        Group {
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
                            .submitLabel(.done)
                            .onSubmit { addFreeTextPerson() }

                        Button {
                            addFreeTextPerson()
                        } label: {
                            Text("Add person")
                        }
                        .buttonStyle(.borderless)
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
    }

    private var importProgressOverlay: some View {
        let total = max(importProgressTotal, 1)
        let current = min(max(importProgressCurrent, 0), total)
        let progress = Double(current) / Double(total)

        return VStack(spacing: 12) {
            Text("Adding…")
                .font(CaviraTheme.Typography.body.weight(.semibold))
                .foregroundStyle(CaviraTheme.textPrimary)

            ProgressView(value: progress)
                .tint(CaviraTheme.accent)
                .animation(.easeInOut(duration: 0.18), value: progress)

            Text("\(current) of \(total)")
                .font(CaviraTheme.Typography.caption)
                .foregroundStyle(CaviraTheme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: 260)
        .background(CaviraTheme.surfaceElevated.opacity(0.96), in: RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium, style: .continuous)
                .stroke(CaviraTheme.border, lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
    }

    private func runImport() {
        guard let services = appServices else { return }
        if itemCount == 1, titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Inline validation handles this state; avoid alerts which can conflict with sheet presentation timing.
            return
        }

        if itemCount == 1,
           let lid = localIdentifiers.first,
           let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext),
           existing.homeCollection != nil {
            importErrorMessage = "This photo is already in a collection."
            dismissAfterAlert = false
            showImportMessageAlert = true
            return
        }

        // Capture duplicate state *before* import runs. Newly inserted entries default to `isInHomeAlbum = true`,
        // so counting duplicates after import can misclassify fresh adds as "already in your album".
        var wasAlreadyInHome: Set<String> = []
        for lid in localIdentifiers {
            if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext),
               existing.isInHomeAlbum || existing.homeCollection != nil {
                wasAlreadyInHome.insert(lid)
            }
        }

        isImporting = true
        importProgressCurrent = 0
        importProgressTotal = localIdentifiers.count
        Task { @MainActor in
            defer { isImporting = false }
            do {
                _ = try PhotoImportService.importLocalIdentifiers(
                    localIdentifiers,
                    context: modelContext,
                    photoLibrary: services.photoLibrary,
                    onProgress: { current, total in
                        importProgressCurrent = current
                        importProgressTotal = total
                    }
                )

                // Resolve the entries that actually exist after import (handles partial failures / missing assets).
                var byId: [UUID: PhotoEntry] = [:]
                for lid in localIdentifiers {
                    if let entry = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext) {
                        byId[entry.id] = entry
                    }
                }
                let affected = Array(byId.values)
                if affected.isEmpty, !localIdentifiers.isEmpty {
                    importErrorMessage = "Nothing new was added. Selected items may already be in your album."
                    dismissAfterAlert = false
                    showImportMessageAlert = true
                    return
                }

                // Determine what was already in Home vs newly added to Home (based on pre-import snapshot).
                let alreadyInHomeCount = affected.compactMap(\.localIdentifier).filter { wasAlreadyInHome.contains($0) }.count
                let willAddToHomeCount = max(affected.count - alreadyInHomeCount, 0)

                if willAddToHomeCount == 0, !affected.isEmpty {
                    importErrorMessage = "Already in your album or a collection. Pick something else to add."
                    dismissAfterAlert = true
                    showImportMessageAlert = true
                    return
                }

                for entry in affected { entry.isInHomeAlbum = true }
                applyMetadata(to: affected)

                // If the user selected some duplicates, confirm what happened.
                if alreadyInHomeCount > 0 {
                    importErrorMessage = "\(alreadyInHomeCount) already in your album. \(willAddToHomeCount) added."
                    dismissAfterAlert = true
                    showImportMessageAlert = true
                } else {
                    dismiss()
                }
            } catch {
                importErrorMessage = error.localizedDescription
                dismissAfterAlert = false
                showImportMessageAlert = true
            }
        }
    }

    private func runCollectionImport() {
        guard let services = appServices else { return }
        let trimmedCollection = collectionTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCollection.isEmpty { return }

        var seenLids = Set<String>()
        var orderedUniqueLids: [String] = []
        orderedUniqueLids.reserveCapacity(localIdentifiers.count)
        for lid in localIdentifiers {
            if seenLids.insert(lid).inserted {
                orderedUniqueLids.append(lid)
            }
        }
        guard orderedUniqueLids.count >= 2 else {
            importErrorMessage = "Select at least two photos for a collection."
            dismissAfterAlert = false
            showImportMessageAlert = true
            return
        }

        for lid in orderedUniqueLids {
            if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext),
               existing.homeCollection != nil {
                importErrorMessage = "One or more photos are already in another collection."
                dismissAfterAlert = false
                showImportMessageAlert = true
                return
            }
        }

        isImporting = true
        importProgressCurrent = 0
        importProgressTotal = orderedUniqueLids.count
        Task { @MainActor in
            defer { isImporting = false }
            do {
                _ = try PhotoImportService.importLocalIdentifiers(
                    orderedUniqueLids,
                    context: modelContext,
                    photoLibrary: services.photoLibrary,
                    onProgress: { current, total in
                        importProgressCurrent = current
                        importProgressTotal = total
                    }
                )

                var imageMembers: [PhotoEntry] = []
                imageMembers.reserveCapacity(orderedUniqueLids.count)
                for lid in orderedUniqueLids {
                    guard let entry = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext) else { continue }
                    guard entry.mediaKind == .image else { continue }
                    if !imageMembers.contains(where: { $0.id == entry.id }) {
                        imageMembers.append(entry)
                    }
                }
                guard imageMembers.count >= 2 else {
                    importErrorMessage = "Collections need at least two photos."
                    dismissAfterAlert = false
                    showImportMessageAlert = true
                    return
                }

                let coll = HomeCollection(
                    title: trimmedCollection,
                    homeOrderIndex: DataService.nextHomeOrderIndex(context: modelContext),
                    createdDate: Date()
                )
                modelContext.insert(coll)

                for (idx, entry) in imageMembers.enumerated() {
                    entry.homeCollection = coll
                    entry.collectionMemberOrder = idx
                    entry.isInHomeAlbum = false
                    entry.homeOrderIndex = nil
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
                coll.entries = imageMembers

                try modelContext.save()
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
