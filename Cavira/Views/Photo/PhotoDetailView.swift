import AVKit
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Full-screen detail: Instagram-style push from grid/timeline; **Back** returns to the album (no swipe-dismiss requirement).
struct PhotoDetailView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: PhotoEntry

    @State private var stillImage: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var videoPlayer: AVPlayer?
    @State private var loadFailed = false
    @State private var showRemoveConfirm = false
    @State private var showEditTags = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareErrorMessage: String?
    @State private var showShareErrorAlert = false

    @State private var showPeopleOverlays = false
    @State private var isPlacingPeopleTag = false
    @State private var pendingPlacementPoint: CGPoint?
    @State private var showPlacePersonDialog = false
    @State private var mediaContainerSize: CGSize = .zero

    private static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    private var dateTitle: String {
        Self.detailDateFormatter.string(from: entry.capturedDate)
    }

    private var locationSubtitle: String? {
        entry.locationTag?.name
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if entry.mediaKind == .video {
                    if let videoPlayer {
                        VideoPlayer(player: videoPlayer)
                            .ignoresSafeArea()
                    } else if loadFailed {
                        missingAssetView
                    } else {
                        ProgressView()
                            .tint(CaviraTheme.accent)
                    }
                } else if entry.isLivePhoto, let livePhoto {
                    LivePhotoDetailRepresentable(livePhoto: livePhoto)
                        .ignoresSafeArea()
                } else if let stillImage {
                    Image(uiImage: stillImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadFailed {
                    missingAssetView
                } else {
                    ProgressView()
                        .tint(CaviraTheme.accent)
                }
            }
            .contentShape(Rectangle())
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { mediaContainerSize = proxy.size }
                        .onChange(of: proxy.size) { _, newValue in mediaContainerSize = newValue }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if isPlacingPeopleTag {
                            pendingPlacementPoint = value.location
                            showPlacePersonDialog = true
                            return
                        }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showPeopleOverlays.toggle()
                        }
                    }
            )
            .overlay {
                if showPeopleOverlays && !entry.peopleTags.isEmpty {
                    Group {
                        if isPlacingPeopleTag {
                            peopleTagsOverlayPositioned
                        } else {
                            peopleTagsOverlayStacked
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(dateTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    if let locationSubtitle, !locationSubtitle.isEmpty {
                        Text(locationSubtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        showEditTags = true
                    }
                    if !entry.peopleTags.isEmpty {
                        Button(isPlacingPeopleTag ? "Done placing people tags" : "Place people tags", systemImage: "person.crop.rectangle.badge.plus") {
                            isPlacingPeopleTag.toggle()
                            if isPlacingPeopleTag {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    showPeopleOverlays = true
                                }
                            }
                        }
                    }
                    Button("Share", systemImage: "square.and.arrow.up") {
                        beginShare()
                    }
                    .disabled(appServices == nil)
                    Divider()
                    Button("Remove from album", systemImage: "rectangle.badge.minus", role: .destructive) {
                        showRemoveConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .confirmationDialog("Place tag", isPresented: $showPlacePersonDialog, titleVisibility: .visible) {
            ForEach(entry.peopleTags, id: \.id) { p in
                Button(p.displayName) {
                    place(person: p)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingPlacementPoint = nil
            }
        } message: {
            Text("Tap a name to place it here.")
        }
        .task {
            await loadMedia()
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Share", isPresented: $showShareErrorAlert) {
            Button("OK", role: .cancel) {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "Unable to share this item.")
        }
        .sheet(isPresented: $showEditTags) {
            EditTagsSheet(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Remove from Cavira?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove from album", role: .destructive) {
                removeFromAlbum()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes the item from your Cavira album. Nothing is deleted from Apple Photos.")
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let ev = entry.event {
                    NavigationLink(value: ev.id) {
                        Text(ev.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.black.opacity(0.35))
                }
            }
        }
    }

    @MainActor
    private func beginShare() {
        Task { @MainActor in
            do {
                let items = try await buildShareItems()
                if items.isEmpty {
                    shareErrorMessage = "Unable to share this item."
                    showShareErrorAlert = true
                    return
                }
                shareItems = items
                showShareSheet = true
            } catch {
                shareErrorMessage = error.localizedDescription
                showShareErrorAlert = true
            }
        }
    }

    private enum ShareError: LocalizedError {
        case assetUnavailable
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .assetUnavailable:
                return "This item is no longer available in your Photos library."
            case .exportFailed:
                return "We couldn’t prepare this item for sharing."
            }
        }
    }

    @MainActor
    private func buildShareItems() async throws -> [Any] {
        guard let services = appServices,
              let lid = entry.localIdentifier,
              let asset = services.photoLibrary.asset(for: lid)
        else {
            throw ShareError.assetUnavailable
        }

        if let url = try await exportPrimaryResourceToTempURL(asset: asset) {
            return [url]
        }

        // Fallback: share the currently loaded still image (JPEG) if available.
        if let stillImage {
            if let url = try writeJPEGToTempURL(image: stillImage, baseName: "cavira") {
                return [url]
            }
            return [stillImage]
        }

        throw ShareError.exportFailed
    }

    /// Exports the primary Photos resource (image/video) to a temp file for sharing.
    @MainActor
    private func exportPrimaryResourceToTempURL(asset: PHAsset) async throws -> URL? {
        let resources = PHAssetResource.assetResources(for: asset)
        let primary: PHAssetResource? = {
            // Prefer a video resource for videos; otherwise the best photo resource.
            if asset.mediaType == .video {
                return resources.first(where: { $0.type == .video }) ?? resources.first
            } else {
                return resources.first(where: { $0.type == .photo }) ?? resources.first
            }
        }()

        guard let resource = primary else { return nil }

        let ext: String = {
            let orig = (resource.originalFilename as NSString).pathExtension
            return orig.isEmpty ? (asset.mediaType == .video ? "mov" : "jpg") : orig
        }()

        let fileName = "cavira-share-\(UUID().uuidString).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Ensure no stale file exists.
        try? FileManager.default.removeItem(at: url)

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                DispatchQueue.main.async {
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: url)
                    }
                }
            }
        }
    }

    private func writeJPEGToTempURL(image: UIImage, baseName: String) throws -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName)-\(UUID().uuidString).jpg")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private var peopleTagsOverlayPositioned: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(entry.peopleTags, id: \.id) { person in
                    let point = overlayPoint(for: person.id, in: proxy.size)
                    Text(person.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.black.opacity(0.55), in: Capsule())
                        .overlay(
                            Capsule().stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                        .position(point)
                        .accessibilityLabel("Tagged \(person.displayName)")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private var peopleTagsOverlayStacked: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.peopleTags, id: \.id) { person in
                Text(person.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.black.opacity(0.55), in: Capsule())
                    .overlay(
                        Capsule().stroke(.white.opacity(0.15), lineWidth: 1)
                    )
                    .accessibilityLabel("Tagged \(person.displayName)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 14)
        .padding(.leading, 14)
        .allowsHitTesting(false)
    }

    private func overlayPoint(for personID: UUID, in size: CGSize) -> CGPoint {
        let placements = entry.peopleTagPlacements
        if let p = placements.first(where: { $0.personTagId == personID }) {
            return CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
        }
        return CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    }

    private func place(person: PersonTag) {
        guard let point = pendingPlacementPoint else { return }
        pendingPlacementPoint = nil

        let size = mediaContainerSize
        let nx = size.width > 0 ? max(0, min(1, point.x / size.width)) : 0.5
        let ny = size.height > 0 ? max(0, min(1, point.y / size.height)) : 0.5

        var placements = entry.peopleTagPlacements
        if let idx = placements.firstIndex(where: { $0.personTagId == person.id }) {
            placements[idx].x = nx
            placements[idx].y = ny
        } else {
            placements.append(PersonTagPlacement(personTagId: person.id, x: nx, y: ny))
        }
        entry.peopleTagPlacements = placements
        try? modelContext.save()
    }

    private var missingAssetView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
            Text("This media isn’t available in your Photos library.")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @MainActor
    private func loadMedia() async {
        guard let services = appServices,
              let id = entry.localIdentifier,
              let asset = services.photoLibrary.asset(for: id)
        else {
            loadFailed = true
            return
        }

        switch entry.mediaKind {
        case .video:
            let item = await requestPlayerItem(for: asset)
            if let item {
                videoPlayer = AVPlayer(playerItem: item)
            } else {
                loadFailed = true
            }
        case .image:
            if entry.isLivePhoto {
                let live = await requestLivePhoto(for: asset)
                livePhoto = live
                if live == nil {
                    stillImage = await services.photoImageLoader.loadFullLibraryImage(for: entry)
                    if stillImage == nil { loadFailed = true }
                }
            } else {
                stillImage = await services.photoImageLoader.loadFullLibraryImage(for: entry)
                if stillImage == nil { loadFailed = true }
            }
        }
    }

    private func requestPlayerItem(for asset: PHAsset) async -> AVPlayerItem? {
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: nil) { item, _ in
                DispatchQueue.main.async {
                    continuation.resume(returning: item)
                }
            }
        }
    }

    private func requestLivePhoto(for asset: PHAsset) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            let box = ContinuationResumeOncePHLivePhoto(continuation)
            let scale = UIScreen.main.scale
            let bounds = UIScreen.main.bounds
            let target = CGSize(width: min(bounds.width * scale, 1_440), height: min(bounds.height * scale, 1_440))
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: target,
                contentMode: .aspectFit,
                options: options
            ) { live, info in
                DispatchQueue.main.async {
                    if info?[PHImageCancelledKey] as? Bool == true {
                        box.resume(returning: nil)
                        return
                    }
                    if let live {
                        box.resume(returning: live)
                    } else if info?[PHImageErrorKey] != nil {
                        box.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func removeFromAlbum() {
        guard let services = appServices else { return }
        // Important: removing from the Home album must not delete the SwiftData row,
        // because Stories can reference the same `PhotoEntry`.
        entry.isInHomeAlbum = false
        try? modelContext.save()
        services.photoImageLoader.clearCache()
        dismiss()
    }
}

// MARK: - Live Photo (UIKit)

private struct LivePhotoDetailRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.livePhoto = livePhoto
        view.isMuted = false
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        if uiView.livePhoto != livePhoto {
            uiView.livePhoto = livePhoto
        }
    }

}

/// `PHImageManager` may invoke the live-photo handler more than once; resume the continuation only once.
private final class ContinuationResumeOncePHLivePhoto: @unchecked Sendable {
    private var continuation: CheckedContinuation<PHLivePhoto?, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<PHLivePhoto?, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: PHLivePhoto?) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(returning: value)
        continuation = nil
    }
}
