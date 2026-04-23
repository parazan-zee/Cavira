import SwiftUI

/// Slide-by-slide editor for a draft story (before saving to SwiftData).
struct StoryDraftEditorView: View {
    let selectedEntries: [PhotoEntry]
    let editingStory: Story?
    let onFinish: () -> Void

    @State private var draftSlides: [StorySlide]
    @State private var currentIndex: Int = 0

    @State private var showStickerPicker = false
    @State private var selectedOverlay: SelectedOverlay?
    @State private var isEditingText = false
    @State private var editingText = ""
    @State private var showReorderSlides = false

    init(selectedEntries: [PhotoEntry], editingStory: Story? = nil, onFinish: @escaping () -> Void) {
        self.selectedEntries = selectedEntries
        self.editingStory = editingStory
        self.onFinish = onFinish
        let slides = selectedEntries.enumerated().map { idx, entry in
            StorySlide(order: idx, photo: entry)
        }
        _draftSlides = State(initialValue: slides)
    }

    init(editingStory: Story, onFinish: @escaping () -> Void) {
        self.selectedEntries = []
        self.editingStory = editingStory
        self.onFinish = onFinish
        let slides = editingStory.orderedSlides.enumerated().map { idx, slide in
            StorySlide(
                order: idx,
                photo: slide.photo,
                backgroundColour: slide.backgroundColour,
                textOverlays: slide.textOverlays,
                stickerOverlays: slide.stickerOverlays
            )
        }
        _draftSlides = State(initialValue: slides)
    }

    var body: some View {
        VStack(spacing: 0) {
            if draftSlides.isEmpty {
                EmptyStateView(systemImage: "film", title: "No slides", subtitle: "Pick at least one photo or video.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CaviraTheme.backgroundPrimary)
            } else {
                SlideEditorView(
                    slide: bindingForCurrentSlide(),
                    selectedOverlay: $selectedOverlay,
                    isEditingText: $isEditingText,
                    editingText: $editingText
                )
                .ignoresSafeArea()

                editorToolbar
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    StorySaveView(draftSlides: draftSlides, editingStory: editingStory) { onFinish() }
                } label: {
                    Text("Save")
                        .font(CaviraTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    StoryPreviewHostView(draftSlides: draftSlides)
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .accessibilityLabel("Preview story")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showReorderSlides = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .accessibilityLabel("Reorder slides")
                .disabled(draftSlides.count < 2)
            }
        }
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerSheet { symbolName in
                addSticker(symbolName)
                showStickerPicker = false
            }
        }
        .sheet(isPresented: $showReorderSlides) {
            StorySlidesReorderSheet(
                slides: $draftSlides,
                currentIndex: $currentIndex
            )
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
            if isEditingText {
                inlineTextEditor
            }
        }
        .onChange(of: isEditingText) { _, newValue in
            if !newValue {
                commitEditingTextIfNeeded()
            }
        }
    }

    private var editorToolbar: some View {
        VStack(spacing: 10) {
            Divider().overlay(.white.opacity(0.12))

            HStack(spacing: 14) {
                Button {
                    addText()
                } label: {
                    toolButtonLabel("Text", systemImage: "textformat")
                }

                Button {
                    showStickerPicker = true
                } label: {
                    toolButtonLabel("Sticker", systemImage: "face.smiling")
                }

                Spacer(minLength: 0)

                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .disabled(currentIndex == 0)

                Text("\(currentIndex + 1) / \(max(draftSlides.count, 1))")
                    .font(CaviraTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Button {
                    goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .disabled(currentIndex >= draftSlides.count - 1)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(.black.opacity(0.55))
    }

    private func toolButtonLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(CaviraTheme.Typography.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.10), in: Capsule())
    }

    private var inlineTextEditor: some View {
        VStack(spacing: 10) {
            Divider().overlay(.white.opacity(0.12))
            HStack(spacing: 10) {
                TextField("Text", text: $editingText)
                    .textInputAutocapitalization(.sentences)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Done") {
                    isEditingText = false
                }
                .font(CaviraTheme.Typography.body.weight(.semibold))
                .foregroundStyle(CaviraTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(.black.opacity(0.72))
    }

    private func bindingForCurrentSlide() -> Binding<StorySlide> {
        Binding(
            get: { draftSlides[currentIndex] },
            set: { draftSlides[currentIndex] = $0 }
        )
    }

    private func addText() {
        let slide = draftSlides[currentIndex]
        var overlays = slide.textOverlays
        let new = TextOverlay(text: "Text")
        overlays.append(new)
        slide.textOverlays = overlays
        selectedOverlay = .text(id: new.id)
        editingText = new.text
        isEditingText = true
    }

    private func addSticker(_ symbolName: String) {
        let slide = draftSlides[currentIndex]
        var overlays = slide.stickerOverlays
        let new = StickerOverlay(stickerName: symbolName)
        overlays.append(new)
        slide.stickerOverlays = overlays
        selectedOverlay = .sticker(id: new.id)
    }

    private func commitEditingTextIfNeeded() {
        guard case let .text(id) = selectedOverlay else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let slide = draftSlides[currentIndex]
        var overlays = slide.textOverlays
        guard let idx = overlays.firstIndex(where: { $0.id == id }) else { return }
        overlays[idx].text = trimmed
        slide.textOverlays = overlays
    }

    private func goForward() {
        selectedOverlay = nil
        isEditingText = false
        if currentIndex < draftSlides.count - 1 {
            currentIndex += 1
        }
    }

    private func goBack() {
        selectedOverlay = nil
        isEditingText = false
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
}

// MARK: - Editor canvas

enum SelectedOverlay: Equatable {
    case text(id: UUID)
    case sticker(id: UUID)
}

private struct SlideEditorView: View {
    @Binding var slide: StorySlide

    @Binding var selectedOverlay: SelectedOverlay?
    @Binding var isEditingText: Bool
    @Binding var editingText: String

    var body: some View {
        ZStack {
            SlideRenderView(slide: slide, isEditing: false, renderOverlays: false)

            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    stickersLayer(containerSize: size)
                    textsLayer(containerSize: size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Deselect on tap empty space.
            selectedOverlay = nil
            isEditingText = false
        }
    }

    private func textsLayer(containerSize: CGSize) -> some View {
        ForEach(slide.textOverlays, id: \.id) { overlay in
            let isSelected = selectedOverlay == .text(id: overlay.id)
            EditableTextOverlayView(
                overlay: overlay,
                isSelected: isSelected,
                containerSize: containerSize,
                onSelect: {
                    selectedOverlay = .text(id: overlay.id)
                },
                onDoubleTap: {
                    selectedOverlay = .text(id: overlay.id)
                    editingText = overlay.text
                    isEditingText = true
                },
                onUpdate: { updated in
                    updateTextOverlay(updated)
                },
                onDelete: {
                    deleteTextOverlay(id: overlay.id)
                }
            )
        }
    }

    private func stickersLayer(containerSize: CGSize) -> some View {
        ForEach(slide.stickerOverlays, id: \.id) { overlay in
            let isSelected = selectedOverlay == .sticker(id: overlay.id)
            EditableStickerOverlayView(
                overlay: overlay,
                isSelected: isSelected,
                containerSize: containerSize,
                onSelect: {
                    selectedOverlay = .sticker(id: overlay.id)
                },
                onUpdate: { updated in
                    updateStickerOverlay(updated)
                },
                onDelete: {
                    deleteStickerOverlay(id: overlay.id)
                }
            )
        }
    }

    private func updateTextOverlay(_ updated: TextOverlay) {
        var overlays = slide.textOverlays
        guard let idx = overlays.firstIndex(where: { $0.id == updated.id }) else { return }
        overlays[idx] = updated
        slide.textOverlays = overlays
    }

    private func deleteTextOverlay(id: UUID) {
        slide.textOverlays = slide.textOverlays.filter { $0.id != id }
        if selectedOverlay == .text(id: id) { selectedOverlay = nil }
        isEditingText = false
    }

    private func updateStickerOverlay(_ updated: StickerOverlay) {
        var overlays = slide.stickerOverlays
        guard let idx = overlays.firstIndex(where: { $0.id == updated.id }) else { return }
        overlays[idx] = updated
        slide.stickerOverlays = overlays
    }

    private func deleteStickerOverlay(id: UUID) {
        slide.stickerOverlays = slide.stickerOverlays.filter { $0.id != id }
        if selectedOverlay == .sticker(id: id) { selectedOverlay = nil }
    }
}

private struct EditableTextOverlayView: View {
    let overlay: TextOverlay
    let isSelected: Bool
    let containerSize: CGSize
    let onSelect: () -> Void
    let onDoubleTap: () -> Void
    let onUpdate: (TextOverlay) -> Void
    let onDelete: () -> Void

    @State private var dragStart: CGPoint?

    var body: some View {
        let point = CGPoint(
            x: CGFloat(overlay.positionX) * containerSize.width,
            y: CGFloat(overlay.positionY) * containerSize.height
        )

        Text(overlay.text)
            .font(.system(size: overlay.fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.black.opacity(isSelected ? 0.55 : 0.35), in: Capsule())
            .overlay(
                Capsule().stroke(isSelected ? CaviraTheme.accent : .white.opacity(0.12), lineWidth: 1)
            )
            .rotationEffect(.degrees(overlay.rotation))
            .position(point)
            .gesture(dragGesture(startAt: point))
            .simultaneousGesture(rotationGesture)
            .simultaneousGesture(magnificationGesture)
            .onTapGesture {
                onSelect()
            }
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.35))
                            .font(.title3)
                    }
                    .offset(x: 16, y: -16)
                }
            }
    }

    private func dragGesture(startAt point: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onSelect()
                if dragStart == nil {
                    dragStart = point
                }
                guard let dragStart else { return }
                let newPoint = CGPoint(x: dragStart.x + value.translation.width, y: dragStart.y + value.translation.height)
                let nx = containerSize.width > 0 ? max(0, min(1, newPoint.x / containerSize.width)) : 0.5
                let ny = containerSize.height > 0 ? max(0, min(1, newPoint.y / containerSize.height)) : 0.5
                var updated = overlay
                updated.positionX = nx
                updated.positionY = ny
                onUpdate(updated)
            }
            .onEnded { _ in
                dragStart = nil
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                guard isSelected else { return }
                var updated = overlay
                updated.rotation = angle.degrees
                onUpdate(updated)
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard isSelected else { return }
                var updated = overlay
                updated.fontSize = max(14, min(120, overlay.fontSize * scale))
                onUpdate(updated)
            }
    }
}

private struct EditableStickerOverlayView: View {
    let overlay: StickerOverlay
    let isSelected: Bool
    let containerSize: CGSize
    let onSelect: () -> Void
    let onUpdate: (StickerOverlay) -> Void
    let onDelete: () -> Void

    @State private var dragStart: CGPoint?

    var body: some View {
        let point = CGPoint(
            x: overlay.positionX * containerSize.width,
            y: overlay.positionY * containerSize.height
        )

        Image(systemName: overlay.stickerName)
            .font(.system(size: 54))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .rotationEffect(.degrees(overlay.rotation))
            .scaleEffect(overlay.scale)
            .position(point)
            .gesture(dragGesture(startAt: point))
            .simultaneousGesture(rotationGesture)
            .simultaneousGesture(magnificationGesture)
            .onTapGesture { onSelect() }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.35))
                            .font(.title3)
                    }
                    .offset(x: 16, y: -16)
                }
            }
    }

    private func dragGesture(startAt point: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onSelect()
                if dragStart == nil {
                    dragStart = point
                }
                guard let dragStart else { return }
                let newPoint = CGPoint(x: dragStart.x + value.translation.width, y: dragStart.y + value.translation.height)
                let nx = containerSize.width > 0 ? max(0, min(1, newPoint.x / containerSize.width)) : 0.5
                let ny = containerSize.height > 0 ? max(0, min(1, newPoint.y / containerSize.height)) : 0.5
                var updated = overlay
                updated.positionX = nx
                updated.positionY = ny
                onUpdate(updated)
            }
            .onEnded { _ in
                dragStart = nil
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                guard isSelected else { return }
                var updated = overlay
                updated.rotation = angle.degrees
                onUpdate(updated)
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard isSelected else { return }
                var updated = overlay
                updated.scale = max(0.3, min(4.0, overlay.scale * scale))
                onUpdate(updated)
            }
    }
}

// MARK: - Preview host

private struct StoryPreviewHostView: View {
    let draftSlides: [StorySlide]

    var body: some View {
        let story = Story(title: "Preview", slides: draftSlides, lastEditedDate: .now)
        StoryViewerView(story: story, autoAdvance: false)
    }
}

