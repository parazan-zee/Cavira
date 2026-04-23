import SwiftUI

struct PhotoThumbnailView: View {
    @Environment(\.appServices) private var appServices

    let entry: PhotoEntry

    @State private var image: UIImage?
    @State private var didAttemptLoad = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Rectangle()
                    .fill(CaviraTheme.surfacePhoto)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipped()
                } else {
                    if didAttemptLoad {
                        missingTile
                    } else {
                        ProgressView()
                            .tint(CaviraTheme.accent)
                            .scaleEffect(0.85)
                    }
                }

                if entry.mediaKind == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.35))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: side, height: side)
            .task(id: "\(entry.id.uuidString)|\(Int(side))") {
                await loadThumbnail(targetSidePoints: side)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var missingTile: some View {
        ZStack {
            CaviraTheme.surfacePhoto
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(CaviraTheme.textTertiary)
                Text("Missing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CaviraTheme.textTertiary)
            }
            .padding(10)
            .background(CaviraTheme.photoScrim, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(CaviraTheme.border, lineWidth: 0.5)
        )
    }

    private var accessibilityLabelText: String {
        switch entry.mediaKind {
        case .video:
            return "Video, \(formattedDate(entry.capturedDate))"
        case .image:
            if entry.isLivePhoto {
                return "Live Photo, \(formattedDate(entry.capturedDate))"
            }
            return "Photo, \(formattedDate(entry.capturedDate))"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    @MainActor
    private func loadThumbnail(targetSidePoints: CGFloat) async {
        guard let loader = appServices?.photoImageLoader else { return }
        let scale = UIScreen.main.scale
        // Request slightly larger than the cell to reduce re-fetching during fast scroll.
        let px = max(Int(targetSidePoints * scale * 1.15), 1)
        let target = CGSize(width: min(px, 600), height: min(px, 600))
        let loaded = await loader.loadImage(for: entry, targetSize: target)
        guard !Task.isCancelled else { return }
        image = loaded
        didAttemptLoad = true
    }
}
