import AVKit
import Photos
import SwiftUI

/// Renders a single `StorySlide` in either viewer or editor mode.
struct SlideRenderView: View {
    @Environment(\.appServices) private var appServices

    let slide: StorySlide
    var isEditing: Bool = false
    var renderOverlays: Bool = true

    @State private var stillImage: UIImage?
    @State private var videoPlayer: AVPlayer?
    @State private var loadFailed: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if let entry = slide.photo {
                    if entry.mediaKind == .video {
                        if let videoPlayer {
                            VideoPlayer(player: videoPlayer)
                                .ignoresSafeArea()
                                .onAppear { videoPlayer.play() }
                        } else if loadFailed {
                            missingAssetView
                        } else {
                            ProgressView().tint(CaviraTheme.accent)
                        }
                    } else {
                        if let stillImage {
                            Image(uiImage: stillImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } else if loadFailed {
                            missingAssetView
                        } else {
                            ProgressView().tint(CaviraTheme.accent)
                        }
                    }
                } else {
                    missingAssetView
                }
            }

            if renderOverlays {
                overlaysLayer
            }
        }
        .task {
            await loadMedia()
        }
        .onChange(of: slide.photo?.id) { _, _ in
            stillImage = nil
            videoPlayer = nil
            loadFailed = false
            Task { await loadMedia() }
        }
    }

    private var overlaysLayer: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(slide.stickerOverlays, id: \.id) { s in
                    StickerOverlayView(overlay: s, containerSize: size, isEditing: isEditing)
                }
                ForEach(slide.textOverlays, id: \.id) { t in
                    TextOverlayView(overlay: t, containerSize: size, isEditing: isEditing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(isEditing)
    }

    @MainActor
    private func loadMedia() async {
        guard let entry = slide.photo else {
            loadFailed = true
            return
        }
        guard let services = appServices,
              let lid = entry.localIdentifier,
              let asset = services.photoLibrary.asset(for: lid)
        else {
            // In previews / tests we may not have Photos access.
            if entry.localIdentifier == nil {
                loadFailed = false
                return
            }
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
            stillImage = await services.photoImageLoader.loadFullLibraryImage(for: entry)
            if stillImage == nil {
                loadFailed = true
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

    private var missingAssetView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
            Text("This media isn’t available in your Photos library.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
    }
}

// MARK: - Overlay rendering

private struct TextOverlayView: View {
    let overlay: TextOverlay
    let containerSize: CGSize
    let isEditing: Bool

    var body: some View {
        Text(overlay.text)
            .font(.system(size: overlay.fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .rotationEffect(.degrees(overlay.rotation))
            .position(
                x: CGFloat(overlay.positionX) * containerSize.width,
                y: CGFloat(overlay.positionY) * containerSize.height
            )
    }
}

private struct StickerOverlayView: View {
    let overlay: StickerOverlay
    let containerSize: CGSize
    let isEditing: Bool

    var body: some View {
        Image(systemName: overlay.stickerName)
            .font(.system(size: 44))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .rotationEffect(.degrees(overlay.rotation))
            .scaleEffect(overlay.scale)
            .position(
                x: CGFloat(overlay.positionX) * containerSize.width,
                y: CGFloat(overlay.positionY) * containerSize.height
            )
    }
}

