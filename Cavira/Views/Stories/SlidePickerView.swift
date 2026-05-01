import Photos
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Select photos/videos from Photos library for a new Story.
/// Keeps existing behavior: items are Photos-backed, and selected entries are materialized into SwiftData on Next.
struct SlidePickerView<Next: View>: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext

    var prefillAssetLocalIdentifiers: [String] = []
    var sourceDay: Date? = nil
    var onCancel: () -> Void = {}

    @State private var assets: [PHAsset] = []
    @State private var selectedOrderedLocalIdentifiers: [String] = []
    @State private var selectedLocalIdentifiers: Set<String> = []
    @State private var draggingLocalIdentifier: String?
    @State private var showCamera = false
    @State private var sortOrder: SlideSortOrder = .dateTakenDescending

    let next: ([PhotoEntry]) -> Next

    enum SlideSortOrder: String, CaseIterable, Identifiable {
        case dateTakenDescending = "Date taken"
        case dateTakenAscending = "Date taken ↑"

        var id: String { rawValue }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            selectionBar

            if !selectedOrderedLocalIdentifiers.isEmpty {
                selectedStrip
                Divider().background(CaviraTheme.border)
            }

            albumHeader

            if assets.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "Nothing to add yet",
                    subtitle: sourceDay == nil
                        ? "Allow Photos access and start building a story from your gallery."
                        : "No photos were captured on this day."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CaviraTheme.backgroundPrimary)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(sortedAssets, id: \.localIdentifier) { asset in
                            photoCell(asset: asset)
                                .aspectRatio(1, contentMode: .fit)
                                .contentShape(Rectangle())
                                .onTapGesture { toggle(asset.localIdentifier) }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 80)
                }
            }
        }
        .background(CaviraTheme.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .task {
            await loadAssets()
            if !prefillAssetLocalIdentifiers.isEmpty {
                for lid in prefillAssetLocalIdentifiers {
                    if !selectedLocalIdentifiers.contains(lid) {
                        selectedLocalIdentifiers.insert(lid)
                        selectedOrderedLocalIdentifiers.append(lid)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { result in
                switch result {
                case .cancelled:
                    showCamera = false
                case let .savedAsset(localIdentifier):
                    showCamera = false
                    Task { @MainActor in
                        await ensureEntryAndSelect(localIdentifier: localIdentifier)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
                    .foregroundStyle(CaviraTheme.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                NavigationLink {
                    next(materializeSelectedEntries())
                } label: {
                    Text("Next")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CaviraTheme.textOnAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(CaviraTheme.accent)
                        .clipShape(Capsule())
                }
                .disabled(selectedOrderedLocalIdentifiers.isEmpty)
                .opacity(selectedOrderedLocalIdentifiers.isEmpty ? 0.5 : 1)
            }
        }
    }

    // MARK: - Sorting

    private var sortedAssets: [PHAsset] {
        switch sortOrder {
        case .dateTakenDescending:
            return assets.sorted {
                ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
        case .dateTakenAscending:
            return assets.sorted {
                ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
        }
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        HStack {
            if selectedOrderedLocalIdentifiers.isEmpty {
                Text("Tap items to select")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            } else {
                let count = selectedOrderedLocalIdentifiers.count
                Text("\(count) item\(count == 1 ? "" : "s") selected")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textSecondary)
            }

            Spacer()

            Menu {
                ForEach(SlideSortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        if sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOrder.rawValue)
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CaviraTheme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CaviraTheme.surfaceCard)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, CaviraTheme.Spacing.lg)
        .padding(.vertical, CaviraTheme.Spacing.sm)
        .background(CaviraTheme.backgroundSecondary)
    }

    // MARK: - Selected strip

    private var selectedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(selectedOrderedLocalIdentifiers.enumerated()), id: \.element) { index, lid in
                    if let asset = assetForLocalIdentifier(lid) {
                        ZStack(alignment: .topTrailing) {
                            PHAssetThumbnailView(asset: asset)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: CaviraTheme.Radius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CaviraTheme.Radius.small)
                                        .stroke(CaviraTheme.accent, lineWidth: 2)
                                )

                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CaviraTheme.textOnAccent)
                                .frame(width: 18, height: 18)
                                .background(CaviraTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .offset(x: -4, y: -4)

                            Button {
                                removeFromSelection(lid)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.black.opacity(0.65))
                                    .clipShape(Circle())
                            }
                            .offset(x: 4, y: -4)
                        }
                        .frame(width: 56, height: 56)
                        .onDrag {
                            draggingLocalIdentifier = lid
                            return NSItemProvider(object: lid as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: StripReorderDropDelegate(
                                targetLocalIdentifier: lid,
                                ordered: $selectedOrderedLocalIdentifiers,
                                draggingLocalIdentifier: $draggingLocalIdentifier
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, CaviraTheme.Spacing.lg)
            .padding(.vertical, CaviraTheme.Spacing.sm)
        }
        .background(CaviraTheme.backgroundSecondary)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: selectedOrderedLocalIdentifiers.isEmpty)
    }

    // MARK: - Album header

    private var albumHeader: some View {
        HStack {
            Text("All Photos")
                .font(CaviraTheme.Typography.headline)
                .foregroundStyle(CaviraTheme.textPrimary)

            Spacer()

            Button {
                // Album switching is a later pass (needed for videos and future organization).
            } label: {
                HStack(spacing: 4) {
                    Text("Albums")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CaviraTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, CaviraTheme.Spacing.lg)
        .padding(.vertical, CaviraTheme.Spacing.sm)
    }

    // MARK: - Photo cell

    private func photoCell(asset: PHAsset) -> some View {
        let selectionIndex = selectedOrderedLocalIdentifiers.firstIndex(of: asset.localIdentifier)
        let isSelected = selectionIndex != nil

        return GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                PHAssetThumbnailView(asset: asset)
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()
                    .overlay(isSelected ? CaviraTheme.accentSubtle : Color.clear)

                Group {
                    if let index = selectionIndex {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(CaviraTheme.textOnAccent)
                            .frame(width: 24, height: 24)
                            .background(CaviraTheme.accent)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .stroke(CaviraTheme.textPrimary.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Text("Tap to select · drag strip to reorder")
                .font(CaviraTheme.Typography.micro)
                .foregroundStyle(CaviraTheme.textTertiary)

            Spacer()

            Button {
                showCamera = true
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CaviraTheme.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(CaviraTheme.surfaceCard)
                    .overlay(
                        Circle()
                            .stroke(CaviraTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel("Capture photo or video")
        }
        .padding(.horizontal, CaviraTheme.Spacing.lg)
        .padding(.vertical, CaviraTheme.Spacing.md)
        .background(
            CaviraTheme.barBackground
                .overlay(alignment: .top) {
                    Divider().background(CaviraTheme.border)
                }
        )
    }

    // MARK: - Actions

    private func toggle(_ localIdentifier: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedLocalIdentifiers.contains(localIdentifier) {
                selectedLocalIdentifiers.remove(localIdentifier)
                selectedOrderedLocalIdentifiers.removeAll(where: { $0 == localIdentifier })
            } else {
                selectedLocalIdentifiers.insert(localIdentifier)
                selectedOrderedLocalIdentifiers.append(localIdentifier)
            }
        }
    }

    private func removeFromSelection(_ localIdentifier: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedLocalIdentifiers.remove(localIdentifier)
            selectedOrderedLocalIdentifiers.removeAll(where: { $0 == localIdentifier })
        }
    }

    private func assetForLocalIdentifier(_ localIdentifier: String) -> PHAsset? {
        if let match = assets.first(where: { $0.localIdentifier == localIdentifier }) {
            return match
        }
        return appServices?.photoLibrary.asset(for: localIdentifier)
    }

    private struct StripReorderDropDelegate: DropDelegate {
        let targetLocalIdentifier: String
        @Binding var ordered: [String]
        @Binding var draggingLocalIdentifier: String?

        func dropEntered(info: DropInfo) {
            guard let dragging = draggingLocalIdentifier else { return }
            guard dragging != targetLocalIdentifier else { return }
            guard let from = ordered.firstIndex(of: dragging),
                  let to = ordered.firstIndex(of: targetLocalIdentifier)
            else { return }

            withAnimation(.easeInOut(duration: 0.15)) {
                ordered.move(
                    fromOffsets: IndexSet(integer: from),
                    toOffset: to > from ? to + 1 : to
                )
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggingLocalIdentifier = nil
            return true
        }
    }

    @MainActor
    private func ensureEntryAndSelect(localIdentifier: String) async {
        guard let services = appServices else { return }
        services.photoLibrary.refreshAuthorizationStatus()

        withAnimation(.easeInOut(duration: 0.15)) {
            if !selectedLocalIdentifiers.contains(localIdentifier) {
                selectedLocalIdentifiers.insert(localIdentifier)
                selectedOrderedLocalIdentifiers.append(localIdentifier)
            }
        }

        if let asset = services.photoLibrary.asset(for: localIdentifier) {
            assets.removeAll(where: { $0.localIdentifier == localIdentifier })
            assets.insert(asset, at: 0)
        }
    }

    @MainActor
    private func loadAssets() async {
        guard let services = appServices else { return }
        services.photoLibrary.refreshAuthorizationStatus()
        switch services.photoLibrary.authorizationStatus {
        case .authorized, .limited:
            if let sourceDay {
                assets = services.photoLibrary.assets(onDay: sourceDay)
            } else {
                let result = services.photoLibrary.fetchAllAssetsForStories()
                var items: [PHAsset] = []
                items.reserveCapacity(min(result.count, 2000))
                result.enumerateObjects { asset, idx, stop in
                    items.append(asset)
                    if idx >= 1999 { stop.pointee = true }
                }
                assets = items
            }
        default:
            assets = []
        }
    }

    /// Creates/updates SwiftData `PhotoEntry` rows for the selected library assets, without adding them to Home.
    @MainActor
    private func materializeSelectedEntries() -> [PhotoEntry] {
        guard let services = appServices else { return [] }

        // Keep selection-strip order (chronological re-sort moved videos after photos).
        let selectedAssets: [PHAsset] = selectedOrderedLocalIdentifiers.compactMap { lid in
            assets.first(where: { $0.localIdentifier == lid }) ?? services.photoLibrary.asset(for: lid)
        }

        var entries: [PhotoEntry] = []
        entries.reserveCapacity(selectedAssets.count)

        for asset in selectedAssets {
            let lid = asset.localIdentifier
            if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext) {
                entries.append(existing)
                continue
            }

            let mediaKind: PhotoAssetKind = asset.mediaType == .video ? .video : .image
            let isLive = asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)
            let entry = PhotoEntry(
                localIdentifier: lid,
                storedFilename: nil,
                storageMode: .reference,
                mediaKind: mediaKind,
                isLivePhoto: isLive,
                isInHomeAlbum: false,
                capturedDate: asset.creationDate ?? .now
            )
            modelContext.insert(entry)
            entries.append(entry)
        }

        try? modelContext.save()
        return entries
    }
}

#Preview {
    NavigationStack {
        SlidePickerView(onCancel: {}) { entries in
            Text("Picked \(entries.count)")
        }
        .navigationTitle("New Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    .caviraPreviewShell()
}

