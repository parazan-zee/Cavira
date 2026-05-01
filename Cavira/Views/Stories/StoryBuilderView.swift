import PhotosUI
import SwiftData
import SwiftUI

/// Phase 9 builder entry point (implemented in sub-steps).
struct StoryBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    var prefillAssetLocalIdentifiers: [String] = []
    var editingStory: Story? = nil
    /// When provided, the slide picker is scoped to assets captured on this day only.
    var sourceDay: Date? = nil

    var body: some View {
        NavigationStack {
            SlidePickerView(
                prefillAssetLocalIdentifiers: editingStory?.orderedSlides.compactMap { $0.photo?.localIdentifier }
                    ?? prefillAssetLocalIdentifiers,
                sourceDay: sourceDay,
                onCancel: { dismiss() }
            ) { selectedEntries in
                StoryDraftEditorView(selectedEntries: selectedEntries, editingStory: editingStory) { dismiss() }
            }
            .navigationTitle(editingStory == nil ? "New Story" : "Edit Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
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
    let editingStory: Story?
    let onFinish: () -> Void

    @State private var titleText: String = ""
    @State private var storyDescription: String = ""
    @State private var storyDate: Date = .now
    @State private var didAttemptSave = false

    @State private var locationQuery: String = ""
    @State private var appliedLocationTag: LocationTag?

    @State private var peopleQuery = ""
    @State private var contactResults: [ContactResult] = []
    @State private var freeTextPerson = ""
    @State private var appliedPeopleTags: [PersonTag] = []

    @State private var coverPhotoId: UUID?
    @State private var showCoverPicker = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var showSaveErrorAlert = false

    private var titleInvalid: Bool {
        didAttemptSave && trimmedTitle.isEmpty
    }

    var body: some View {
        VStack(spacing: CaviraTheme.Spacing.md) {
            Form {
                titleSection
                dateSection
                descriptionSection
                locationSection
                peopleSection
                coverSection
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)

            Spacer(minLength: 0)
        }
        .background(CaviraTheme.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") {
                    didAttemptSave = true
                    guard !titleInvalid else { return }
                    saveStory()
                }
                .foregroundStyle(CaviraTheme.accent)
                .disabled(isSaving || draftSlides.isEmpty)
            }
        }
        .onAppear {
            if coverPhotoId == nil {
                coverPhotoId = editingStory?.coverPhotoId ?? defaultCoverID
            }
            if titleText.isEmpty, let s = editingStory {
                titleText = s.title
                storyDescription = s.storyDescription ?? ""
                storyDate = s.storyDate
                appliedLocationTag = s.locationTag
                appliedPeopleTags = s.peopleTags
            }
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
        .alert("Save story", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private var coverEntries: [PhotoEntry] {
        draftSlides.compactMap(\.photo)
    }

    private var titleSection: some View {
        Section {
            TextField("Story title", text: $titleText)
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

            Text("Give this story a short name so you can find it later.")
                .font(CaviraTheme.Typography.caption)
                .foregroundStyle(CaviraTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            HStack(spacing: 4) {
                Text("Title")
                    .foregroundStyle(CaviraTheme.textSecondary)
                Text("*")
                    .foregroundStyle(CaviraTheme.destructive)
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $storyDate, displayedComponents: [.date])
                .tint(CaviraTheme.accent)
        } header: {
            Text("Date")
                .foregroundStyle(CaviraTheme.textSecondary)
        }
    }

    private var descriptionSection: some View {
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
    }

    private var locationSection: some View {
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
    }

    private var peopleSection: some View {
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
    }

    private var coverSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(coverEntries, id: \.id) { entry in
                        coverChip(entry: entry)
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

    private func coverChip(entry: PhotoEntry) -> some View {
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
        let description = storyDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : storyDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            do {
                try await persistStory(
                    title: title,
                    description: description
                )
                isSaving = false
                onFinish()
            } catch {
                isSaving = false
                saveErrorMessage = error.localizedDescription
                showSaveErrorAlert = true
            }
        }
    }

    @MainActor
    private func persistStory(title: String, description: String?) async throws {
        func fallbackJPEGData(for entry: PhotoEntry) async -> Data? {
            guard let loader = appServices?.photoImageLoader else { return nil }
            let img = await loader.loadImage(for: entry, targetSize: CGSize(width: 720, height: 720))
            return img?.jpegData(compressionQuality: 0.72)
        }

        if let existing = editingStory {
            existing.title = title
            existing.storyDescription = description
            existing.storyDate = storyDate
            existing.locationTag = appliedLocationTag
            existing.peopleTags = appliedPeopleTags
            existing.coverPhotoId = coverPhotoId ?? defaultCoverID
            existing.lastEditedDate = .now

            for slide in existing.slides {
                modelContext.delete(slide)
            }
            existing.slides = []

            for (idx, draft) in draftSlides.enumerated() {
                let preview: Data?
                if let photo = draft.photo {
                    preview = await fallbackJPEGData(for: photo)
                } else {
                    preview = nil
                }
                let slide = StorySlide(
                    order: idx,
                    photo: draft.photo,
                    backgroundColour: draft.backgroundColour,
                    textOverlays: draft.textOverlays,
                    stickerOverlays: draft.stickerOverlays,
                    fallbackPreviewImageData: preview,
                    story: existing
                )
                modelContext.insert(slide)
            }
        } else {
            let story = Story(
                title: title,
                storyDescription: description,
                storyDate: storyDate,
                locationTag: appliedLocationTag,
                peopleTags: appliedPeopleTags,
                coverPhotoId: coverPhotoId ?? defaultCoverID,
                createdDate: .now,
                lastEditedDate: .now
            )
            modelContext.insert(story)

            for (idx, draft) in draftSlides.enumerated() {
                let preview: Data?
                if let photo = draft.photo {
                    preview = await fallbackJPEGData(for: photo)
                } else {
                    preview = nil
                }
                let slide = StorySlide(
                    order: idx,
                    photo: draft.photo,
                    backgroundColour: draft.backgroundColour,
                    textOverlays: draft.textOverlays,
                    stickerOverlays: draft.stickerOverlays,
                    fallbackPreviewImageData: preview,
                    story: story
                )
                modelContext.insert(slide)
            }
        }

        try modelContext.save()
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

