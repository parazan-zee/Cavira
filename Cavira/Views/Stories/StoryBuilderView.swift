import PhotosUI
import SwiftData
import SwiftUI

/// Phase 9 builder entry point (implemented in sub-steps).
struct StoryBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    var prefillAssetLocalIdentifiers: [String] = []
    /// When provided, the slide picker is scoped to assets captured on this day only.
    var sourceDay: Date? = nil

    var body: some View {
        NavigationStack {
            SlidePickerView(
                prefillAssetLocalIdentifiers: prefillAssetLocalIdentifiers,
                sourceDay: sourceDay
            ) { selectedEntries in
                let sorted = selectedEntries.sorted { $0.capturedDate < $1.capturedDate }
                return StoryDraftEditorView(selectedEntries: sorted) { dismiss() }
            }
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    StoryBuilderView()
        .caviraPreviewShell()
}

struct StorySaveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices

    let draftSlides: [StorySlide]
    let onFinish: () -> Void

    @State private var titleText: String = ""
    @State private var storyDescription: String = ""
    @State private var storyDate: Date = .now

    @State private var locationQuery: String = ""
    @State private var appliedLocationTag: LocationTag?

    @State private var peopleQuery = ""
    @State private var contactResults: [ContactResult] = []
    @State private var freeTextPerson = ""
    @State private var appliedPeopleTags: [PersonTag] = []

    @State private var coverPhotoId: UUID?
    @State private var showCoverPicker = false
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: CaviraTheme.Spacing.md) {
            Form {
                Section {
                    TextField("Story title", text: $titleText)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(CaviraTheme.textPrimary)

                    Text("Give this story a short name so you can find it later.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Title")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }

                Section {
                    DatePicker("Date", selection: $storyDate, displayedComponents: [.date])
                        .tint(CaviraTheme.accent)
                } header: {
                    Text("Date")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }

                Section {
                    TextEditor(text: $storyDescription)
                        .frame(minHeight: 90)
                        .foregroundStyle(CaviraTheme.textPrimary)

                    Text("Optional. Add a short note to remember what this story is about.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Description")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }

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
                .task(id: peopleQuery) {
                    await refreshContactResults()
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(draftSlides.compactMap(\.photo), id: \.id) { entry in
                                Button {
                                    coverPhotoId = entry.id
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        PhotoThumbnailView(entry: entry)
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(
                                                        (coverPhotoId ?? defaultCoverID) == entry.id ? CaviraTheme.accent : .clear,
                                                        lineWidth: 2
                                                    )
                                            )

                                        if (coverPhotoId ?? defaultCoverID) == entry.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(CaviraTheme.accent, .black.opacity(0.35))
                                                .padding(6)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Text("Cover defaults to the first slide. Tap to change.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)

                    Button("Choose a different cover from your library") {
                        showCoverPicker = true
                    }
                    .foregroundStyle(CaviraTheme.accent)
                } header: {
                    Text("Cover")
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)

            Spacer(minLength: 0)
        }
        .background(CaviraTheme.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {}
                    .disabled(true)
                    .hidden()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") {
                    saveStory()
                }
                .foregroundStyle(CaviraTheme.accent)
                .disabled(isSaving || trimmedTitle.isEmpty || draftSlides.isEmpty)
            }
        }
        .onAppear {
            coverPhotoId = defaultCoverID
        }
        .sheet(isPresented: $showCoverPicker) {
            PhotoPickerRepresentable(
                isPresented: $showCoverPicker
            ) { results in
                guard let first = results.first, let lid = first.assetIdentifier else { return }
                Task { @MainActor in
                    setCoverFromLibrary(localIdentifier: lid)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var trimmedTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultCoverID: UUID? {
        draftSlides.first?.photo?.id
    }

    @MainActor
    private func saveStory() {
        guard !isSaving else { return }
        let title = trimmedTitle
        guard !title.isEmpty else { return }

        isSaving = true
        let story = Story(
            title: title,
            storyDescription: storyDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : storyDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            storyDate: storyDate,
            locationTag: appliedLocationTag,
            peopleTags: appliedPeopleTags,
            coverPhotoId: coverPhotoId ?? defaultCoverID,
            createdDate: .now,
            lastEditedDate: .now
        )
        modelContext.insert(story)

        for (idx, slide) in draftSlides.enumerated() {
            slide.order = idx
            slide.story = story
            modelContext.insert(slide)
        }

        try? modelContext.save()
        isSaving = false
        onFinish()
    }

    // MARK: - Cover

    @MainActor
    private func setCoverFromLibrary(localIdentifier: String) {
        if let existing = DataService.existingPhotoEntry(localIdentifier: localIdentifier, context: modelContext) {
            coverPhotoId = existing.id
            try? modelContext.save()
            return
        }

        guard let services = appServices else { return }
        guard let asset = services.photoLibrary.asset(for: localIdentifier) else { return }
        let mediaKind: PhotoAssetKind = asset.mediaType == .video ? .video : .image
        let isLive = asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)
        let entry = PhotoEntry(
            localIdentifier: localIdentifier,
            storedFilename: nil,
            storageMode: .reference,
            mediaKind: mediaKind,
            isLivePhoto: isLive,
            isInHomeAlbum: false,
            capturedDate: asset.creationDate ?? .now
        )
        modelContext.insert(entry)
        try? modelContext.save()
        coverPhotoId = entry.id
    }

    // MARK: - Location

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

    // MARK: - People

    @MainActor
    private func refreshContactResults() async {
        guard let contacts = appServices?.contacts else { return }
        guard contacts.authorizationStatus == .authorized else {
            contactResults = []
            return
        }
        contactResults = await contacts.search(query: peopleQuery)
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

