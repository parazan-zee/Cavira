import SwiftData
import SwiftUI

/// Select photos/videos (no reorder; order is date-taken).
struct SlidePickerView<Next: View>: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]

    @State private var selectedIDs: Set<UUID> = []
    @State private var showCamera = false

    let next: ([PhotoEntry]) -> Next

    private var selectedEntries: [PhotoEntry] {
        photos.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if photos.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "Nothing to add yet",
                    subtitle: "Add photos or videos to your Cavira album, then build a story from them."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CaviraTheme.backgroundPrimary)
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(photos, id: \.id) { entry in
                            Button {
                                toggle(entry.id)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    PhotoThumbnailView(entry: entry)

                                    if selectedIDs.contains(entry.id) {
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
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { result in
                switch result {
                case .cancelled:
                    showCamera = false
                case let .savedAsset(localIdentifier):
                    showCamera = false
                    Task { @MainActor in
                        await importAndSelectCapturedAsset(localIdentifier: localIdentifier)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Text("\(selectedIDs.count) selected")
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
                    next(selectedEntries)
                } label: {
                    Text("Next")
                        .font(CaviraTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(CaviraTheme.textOnAccent)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(CaviraTheme.accent, in: Capsule())
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, CaviraTheme.Spacing.md)
            .padding(.bottom, CaviraTheme.Spacing.md)
        }
        .background(CaviraTheme.barBackground)
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    @MainActor
    private func importAndSelectCapturedAsset(localIdentifier: String) async {
        guard let services = appServices else { return }
        if let existing = DataService.existingPhotoEntry(localIdentifier: localIdentifier, context: modelContext) {
            selectedIDs.insert(existing.id)
            return
        }

        // Best effort: query Photos for accurate metadata.
        let asset = services.photoLibrary.asset(for: localIdentifier)
        let mediaKind: PhotoAssetKind
        let isLive: Bool
        let capturedDate: Date
        if let asset {
            mediaKind = asset.mediaType == .video ? .video : .image
            isLive = asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)
            capturedDate = asset.creationDate ?? .now
        } else {
            mediaKind = .image
            isLive = false
            capturedDate = .now
        }

        let entry = PhotoEntry(
            localIdentifier: localIdentifier,
            storedFilename: nil,
            storageMode: .reference,
            mediaKind: mediaKind,
            isLivePhoto: isLive,
            capturedDate: capturedDate
        )
        modelContext.insert(entry)
        try? modelContext.save()
        selectedIDs.insert(entry.id)
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

