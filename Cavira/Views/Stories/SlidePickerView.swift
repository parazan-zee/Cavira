import Photos
import SwiftData
import SwiftUI

/// Select photos/videos (no reorder; order is date-taken).
struct SlidePickerView<Next: View>: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext

    var prefillAssetLocalIdentifiers: [String] = []
    var sourceDay: Date? = nil

    @State private var assets: [PHAsset] = []
    @State private var selectedLocalIdentifiers: Set<String> = []
    @State private var showCamera = false

    let next: ([PhotoEntry]) -> Next

    var body: some View {
        VStack(spacing: 0) {
            if assets.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "Nothing to add yet",
                    subtitle: sourceDay == nil
                        ? "Allow Photos access and start building a story from your gallery."
                        : "No photos or videos were captured on this day."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CaviraTheme.backgroundPrimary)
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            Button {
                                toggle(asset.localIdentifier)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    PHAssetThumbnailView(asset: asset)

                                    if selectedLocalIdentifiers.contains(asset.localIdentifier) {
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
                    .padding(.horizontal, 4)
                    .padding(.bottom, 96)
                }
                .background(CaviraTheme.backgroundPrimary)

                bottomBar
            }
        }
        .task {
            await loadAssets()
            if !prefillAssetLocalIdentifiers.isEmpty {
                selectedLocalIdentifiers.formUnion(prefillAssetLocalIdentifiers)
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
                Text("\(selectedLocalIdentifiers.count) selected")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
        ]
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Divider().overlay(CaviraTheme.border.opacity(0.7))

            HStack(spacing: 12) {
                Text("Slides will play in date taken order.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)

                Spacer(minLength: 0)

                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(.white.opacity(0.10), in: Capsule())
                }
                .accessibilityLabel("Capture photo or video")

                NavigationLink {
                    next(materializeSelectedEntries())
                } label: {
                    Text("Next")
                        .font(CaviraTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.textOnAccent)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(CaviraTheme.accent, in: Capsule())
                }
                .disabled(selectedLocalIdentifiers.isEmpty)
            }
            .padding(.horizontal, CaviraTheme.Spacing.md)
            .padding(.bottom, CaviraTheme.Spacing.md)
        }
        .background(CaviraTheme.barBackground)
    }

    private func toggle(_ localIdentifier: String) {
        if selectedLocalIdentifiers.contains(localIdentifier) {
            selectedLocalIdentifiers.remove(localIdentifier)
        } else {
            selectedLocalIdentifiers.insert(localIdentifier)
        }
    }

    @MainActor
    private func ensureEntryAndSelect(localIdentifier: String) async {
        guard let services = appServices else { return }
        selectedLocalIdentifiers.insert(localIdentifier)

        // Ensure the asset appears near the top of the grid.
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
                let result = services.photoLibrary.fetchAllAssets()
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

        let selectedAssets: [PHAsset] = assets.filter { selectedLocalIdentifiers.contains($0.localIdentifier) }
        let sortedAssets = selectedAssets.sorted { (a, b) in
            (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
        }

        var entries: [PhotoEntry] = []
        entries.reserveCapacity(sortedAssets.count)

        for asset in sortedAssets {
            let lid = asset.localIdentifier
            if let existing = DataService.existingPhotoEntry(localIdentifier: lid, context: modelContext) {
                // Keep it Story-only unless the user explicitly adds it to Home elsewhere.
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
        SlidePickerView { entries in
            Text("Picked \(entries.count)")
        }
    }
    .caviraPreviewShell()
}

