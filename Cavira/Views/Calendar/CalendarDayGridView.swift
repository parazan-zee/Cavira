import Photos
import PhotosUI
import SwiftData
import SwiftUI

struct CalendarDayGridView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let day: Date

    @State private var assets: [PHAsset] = []
    @State private var selectedAssetLocalIdentifier: String?

    private var titleText: String {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df.string(from: day)
    }

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    EmptyStateView(
                        title: "Nothing captured",
                        subtitle: "No photos or videos were captured on this date."
                    )
                    .padding(.horizontal, CaviraTheme.Spacing.md)
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 4) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                Button {
                                    selectedAssetLocalIdentifier = asset.localIdentifier
                                } label: {
                                    PHAssetThumbnailView(asset: asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, CaviraTheme.Spacing.xl)
                    }
                }
            }
            .background(CaviraTheme.backgroundPrimary)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
            .task {
                await loadAssets()
            }
            .sheet(item: Binding(
                get: { selectedAssetLocalIdentifier.map { AssetSheetItem(day: day, localIdentifier: $0) } },
                set: { newValue in if newValue == nil { selectedAssetLocalIdentifier = nil } }
            )) { item in
                CalendarAssetActionsSheet(day: item.day, localIdentifier: item.localIdentifier)
            }
        }
        .presentationDetents([.large])
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
        ]
    }

    @MainActor
    private func loadAssets() async {
        guard let services = appServices else { return }
        services.photoLibrary.refreshAuthorizationStatus()
        switch services.photoLibrary.authorizationStatus {
        case .authorized, .limited:
            assets = services.photoLibrary.assets(onDay: day)
        default:
            assets = []
        }
    }
}

private struct AssetSheetItem: Identifiable, Equatable {
    let id: String
    let day: Date
    let localIdentifier: String

    init(day: Date, localIdentifier: String) {
        self.id = localIdentifier
        self.day = day
        self.localIdentifier = localIdentifier
    }
}

private struct CalendarAssetActionsSheet: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let localIdentifier: String

    @State private var isSavingToHome = false
    @State private var didSaveToHome = false
    @State private var showAddToHomeDetails = false
    @State private var showAddToStory = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showAddToHomeDetails = true
                    } label: {
                        HStack {
                            Label("Add to Home album", systemImage: "plus.circle.fill")
                                .foregroundStyle(CaviraTheme.accent)
                            Spacer()
                            if didSaveToHome {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CaviraTheme.accent)
                            }
                        }
                    }
                    .disabled(isSavingToHome)

                    Button {
                        showAddToStory = true
                    } label: {
                        Label("Add to Story", systemImage: "film")
                            .foregroundStyle(CaviraTheme.textPrimary)
                    }
                }
                .listRowBackground(CaviraTheme.surfaceCard)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CaviraTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showAddToHomeDetails) {
            ImportOptionsSheet(localIdentifiers: [localIdentifier])
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddToStory) {
            StoryBuilderView(
                prefillAssetLocalIdentifiers: [localIdentifier],
                sourceDay: day
            )
        }
    }

}
