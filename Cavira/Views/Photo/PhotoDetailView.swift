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

    private static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

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
        .navigationTitle(Self.detailDateFormatter.string(from: entry.capturedDate))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") {}
                        .disabled(true)
                    Button("Share", systemImage: "square.and.arrow.up") {}
                        .disabled(true)
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
        .task {
            await loadMedia()
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
        do {
            try DataService.deletePhotoEntry(entry, context: modelContext, photoStorage: services.photoStorage)
            services.photoImageLoader.clearCache()
            dismiss()
        } catch {
            // Silent fail acceptable for v1; Phase 12 can surface errors.
        }
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
