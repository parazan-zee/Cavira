import Photos
import SwiftUI
import UIKit

/// Square thumbnail for a Photos library `PHAsset`.
struct PHAssetThumbnailView: View {
    let asset: PHAsset
    var showsVideoBadge: Bool = true

    @State private var image: UIImage?
    @State private var targetSidePoints: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(CaviraTheme.surfaceCard.opacity(0.6))
                            .overlay {
                                ProgressView()
                                    .tint(CaviraTheme.accent)
                            }
                    }
                }
                .frame(width: side, height: side)
                .clipped()

                if showsVideoBadge, asset.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.55), in: Circle())
                        .padding(6)
                }
            }
            .onAppear { targetSidePoints = side }
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: "\(asset.localIdentifier)|\(Int(targetSidePoints))") {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        await withCheckedContinuation { cont in
            manager.requestImage(
                for: asset,
                targetSize: thumbnailTargetSize(),
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                guard !Task.isCancelled else {
                    cont.resume()
                    return
                }
                self.image = img
                cont.resume()
            }
        }
    }

    private func thumbnailTargetSize() -> CGSize {
        let scale = UIScreen.main.scale
        let px = max(Int(targetSidePoints * scale * 1.2), 1)
        let clamped = min(px, 700)
        return CGSize(width: clamped, height: clamped)
    }
}

