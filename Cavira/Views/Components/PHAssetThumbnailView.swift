import Photos
import SwiftUI
import UIKit

/// Square thumbnail for a Photos library `PHAsset` (photos + videos).
struct PHAssetThumbnailView: View {
    let asset: PHAsset
    var showsVideoBadge: Bool = true

    @State private var image: UIImage?

    var body: some View {
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
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
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
        .task(id: asset.localIdentifier) {
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
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                self.image = img
                cont.resume()
            }
        }
    }
}

