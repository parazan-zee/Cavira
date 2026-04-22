import Photos
import SwiftUI
import UIKit

struct RecapCarouselView: View {
    @Environment(\.appServices) private var appServices

    let referenceDay: Date

    @State private var assets: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var modeLabel: String = "Recap"

    // Simple timer-driven flip (about every 5 seconds).
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: CaviraTheme.Spacing.md) {
            Text(modeLabel)
                .font(CaviraTheme.Typography.headline)
                .foregroundStyle(CaviraTheme.textPrimary)

            if assets.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "No recap yet",
                    subtitle: "When you have photos from past years, they’ll appear here."
                )
                .padding(.vertical, CaviraTheme.Spacing.md)
            } else {
                ZStack {
                    RecapAssetView(asset: assets[currentIndex])
                        .transition(.opacity)
                        .id(assets[currentIndex].localIdentifier)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16/10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium, style: .continuous)
                        .stroke(CaviraTheme.surfaceCard.opacity(0.35), lineWidth: 1)
                )
                .onReceive(timer) { _ in
                    withAnimation(.easeInOut(duration: 0.6)) {
                        advance()
                    }
                }
            }
        }
        .padding(CaviraTheme.Spacing.md)
        .background(CaviraTheme.surfaceCard.opacity(0.4), in: RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium))
        .task {
            await loadRecap()
        }
    }

    @MainActor
    private func loadRecap() async {
        guard let services = appServices else { return }
        services.photoLibrary.refreshAuthorizationStatus()
        guard services.photoLibrary.authorizationStatus == .authorized || services.photoLibrary.authorizationStatus == .limited else {
            assets = []
            return
        }

        let onThisDate = services.photoLibrary.recapAssetsOnThisDate(referenceDay: referenceDay)
        if !onThisDate.isEmpty {
            modeLabel = "On this date"
            assets = onThisDate
            currentIndex = 0
            return
        }

        let thisMonth = services.photoLibrary.recapAssetsThisMonth(referenceDay: referenceDay)
        modeLabel = "This month"
        assets = thisMonth
        currentIndex = 0
    }

    private func advance() {
        guard !assets.isEmpty else { return }
        currentIndex = (currentIndex + 1) % assets.count
    }
}

private struct RecapAssetView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(CaviraTheme.surfaceElevated.opacity(0.7))
                    .overlay {
                        ProgressView()
                            .tint(CaviraTheme.accent)
                    }
            }
        }
        .task(id: asset.localIdentifier) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        await withCheckedContinuation { cont in
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 1200, height: 1200),
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                self.image = img
                cont.resume()
            }
        }
    }
}

