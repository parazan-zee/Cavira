import AVKit
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

// MARK: - Share & home removal (shared by detail + collection pager chrome)

private enum PhotoDetailShareError: LocalizedError {
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

private enum PhotoDetailCommandHelpers {
    @MainActor
    static func buildShareItems(entry: PhotoEntry, stillImage: UIImage?, appServices: AppServices?) async throws -> [Any] {
        guard let services = appServices,
              let lid = entry.localIdentifier,
              let asset = services.photoLibrary.asset(for: lid)
        else {
            throw PhotoDetailShareError.assetUnavailable
        }

        if let url = try await exportPrimaryResourceToTempURL(asset: asset) {
            return [url]
        }

        if let stillImage {
            if let url = try writeJPEGToTempURL(image: stillImage, baseName: "cavira") {
                return [url]
            }
            return [stillImage]
        }

        throw PhotoDetailShareError.exportFailed
    }

    @MainActor
    static func exportPrimaryResourceToTempURL(asset: PHAsset) async throws -> URL? {
        let resources = PHAssetResource.assetResources(for: asset)
        let primary: PHAssetResource? = {
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

    static func writeJPEGToTempURL(image: UIImage, baseName: String) throws -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName)-\(UUID().uuidString).jpg")
        try data.write(to: url, options: [.atomic])
        return url
    }

    @MainActor
    static func deleteHomeCollection(for entry: PhotoEntry, modelContext: ModelContext, services: AppServices, dismiss: DismissAction) {
        guard let coll = entry.homeCollection else { return }
        let members = coll.entries
        for m in members {
            m.homeCollection = nil
            m.collectionMemberOrder = nil
            m.isInHomeAlbum = false
        }
        modelContext.delete(coll)
        try? modelContext.save()
        services.photoImageLoader.clearCache()
        dismiss()
    }

    @MainActor
    static func removeStandaloneFromHomeAlbum(entry: PhotoEntry, modelContext: ModelContext, services: AppServices, dismiss: DismissAction) {
        entry.isInHomeAlbum = false
        try? modelContext.save()
        services.photoImageLoader.clearCache()
        dismiss()
    }
}

/// Full-screen detail: Instagram-style push from grid/timeline; **Back** returns to the album (no swipe-dismiss requirement).
struct PhotoDetailView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: PhotoEntry
    /// When true (Home collection pager), page index / ⋯ are on `HomeCollectionViewer` (not duplicated per tab).
    var isEmbeddedInCollectionPager: Bool = false

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

    @ViewBuilder
    private var peopleTagsTopInset: some View {
        if !entry.peopleTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.52))
        }
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
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            peopleTagsTopInset
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !isEmbeddedInCollectionPager {
                ToolbarItem(placement: .principal) {
                    PhotoDetailNavChrome.principalToolbarContent(for: entry)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            showEditTags = true
                        }
                        Button("Share", systemImage: "square.and.arrow.up") {
                            beginShare()
                        }
                        .disabled(appServices == nil)
                        Divider()
                        Button(
                            entry.homeCollection != nil ? "Delete collection" : "Remove from album",
                            systemImage: "rectangle.badge.minus",
                            role: .destructive
                        ) {
                            showRemoveConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
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
            entry.homeCollection != nil ? "Delete this collection?" : "Remove from Cavira?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            if entry.homeCollection != nil {
                Button("Delete collection", role: .destructive) {
                    guard let services = appServices else { return }
                    PhotoDetailCommandHelpers.deleteHomeCollection(for: entry, modelContext: modelContext, services: services, dismiss: dismiss)
                }
            } else {
                Button("Remove from album", role: .destructive) {
                    guard let services = appServices else { return }
                    PhotoDetailCommandHelpers.removeStandaloneFromHomeAlbum(entry: entry, modelContext: modelContext, services: services, dismiss: dismiss)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                entry.homeCollection != nil
                    ? "The collection disappears from Home and all its items are removed from your Cavira album. Nothing is deleted from Apple Photos."
                    : "This only removes the item from your Cavira album. Nothing is deleted from Apple Photos."
            )
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
                let items = try await PhotoDetailCommandHelpers.buildShareItems(entry: entry, stillImage: stillImage, appServices: appServices)
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

}

/// Toolbar ⋯ menu for the collection pager only. Lives on `HomeCollectionViewer` so it isn’t inside a `TabView` page (avoids swipe / transition glitches).
struct PhotoDetailPagerOverflowMenu: View {
    let entry: PhotoEntry

    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showRemoveConfirm = false
    @State private var showEditTags = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareErrorMessage: String?
    @State private var showShareErrorAlert = false

    var body: some View {
        Menu {
            Button("Edit", systemImage: "pencil") {
                showEditTags = true
            }
            Button("Share", systemImage: "square.and.arrow.up") {
                beginShare()
            }
            .disabled(appServices == nil)
            Divider()
            Button(
                entry.homeCollection != nil ? "Delete collection" : "Remove from album",
                systemImage: "rectangle.badge.minus",
                role: .destructive
            ) {
                showRemoveConfirm = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More")
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
            entry.homeCollection != nil ? "Delete this collection?" : "Remove from Cavira?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            if entry.homeCollection != nil {
                Button("Delete collection", role: .destructive) {
                    guard let services = appServices else { return }
                    PhotoDetailCommandHelpers.deleteHomeCollection(for: entry, modelContext: modelContext, services: services, dismiss: dismiss)
                }
            } else {
                Button("Remove from album", role: .destructive) {
                    guard let services = appServices else { return }
                    PhotoDetailCommandHelpers.removeStandaloneFromHomeAlbum(entry: entry, modelContext: modelContext, services: services, dismiss: dismiss)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                entry.homeCollection != nil
                    ? "The collection disappears from Home and all its items are removed from your Cavira album. Nothing is deleted from Apple Photos."
                    : "This only removes the item from your Cavira album. Nothing is deleted from Apple Photos."
            )
        }
    }

    @MainActor
    private func beginShare() {
        Task { @MainActor in
            do {
                let items = try await PhotoDetailCommandHelpers.buildShareItems(entry: entry, stillImage: nil, appServices: appServices)
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
}

// MARK: - Shared detail navigation chrome

/// Centered date/location stack for the photo detail bar. **Standalone:** `PhotoDetailView` puts this in `.principal`. **Collection pager:** `HomeCollectionViewer` owns the toolbar so it isn’t inside `TabView` pages.
enum PhotoDetailNavChrome {
    private static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    @ViewBuilder
    static func principalToolbarContent(for entry: PhotoEntry) -> some View {
        VStack(spacing: 2) {
            Text(detailDateFormatter.string(from: entry.capturedDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
            if let locationSubtitle = entry.locationTag?.name, !locationSubtitle.isEmpty {
                Text(locationSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
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
