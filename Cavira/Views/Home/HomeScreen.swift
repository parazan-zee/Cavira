import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct HomeScreen: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true },
        sort: \PhotoEntry.capturedDate,
        order: .reverse
    )
    private var queriedPhotos: [PhotoEntry]

    private var photos: [PhotoEntry] {
        queriedPhotos.sorted(by: photoSort)
    }

    /// Album entries with `mediaKind == .video` (Videos segment only).
    private var videoPhotos: [PhotoEntry] {
        photos.filter { $0.mediaKind == .video }
    }

    @State private var homeViewMode: HomeViewMode = .grid
    fileprivate enum HomeSheet: Identifiable {
        case photoPicker
        case importOptions(id: UUID, results: [PHPickerResult])

        private static let pickerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        var id: UUID {
            switch self {
            case .photoPicker:
                return Self.pickerID
            case .importOptions(let id, _):
                // Stable id keeps the sheet's internal @State from resetting on re-renders.
                return id
            }
        }
    }

    @State private var activeSheet: HomeSheet?
    @State private var showPhotoDeniedAlert = false
    @State private var entryPendingRemoval: PhotoEntry?
    @State private var showRemoveConfirm = false
    @State private var entryPendingEdit: PhotoEntry?
    @State private var showEditTags = false
    @State private var showReorderHome = false

    // Prevent synthesized private memberwise init from `private` stored properties (e.g. `@Query photos`).
    init() {}

    var body: some View {
        HomeScreenScaffold(
            homeViewMode: $homeViewMode,
            activeSheet: $activeSheet,
            showPhotoDeniedAlert: $showPhotoDeniedAlert,
            entryPendingRemoval: $entryPendingRemoval,
            showRemoveConfirm: $showRemoveConfirm,
            entryPendingEdit: $entryPendingEdit,
            showEditTags: $showEditTags,
            showReorderHome: $showReorderHome,
            photos: photos,
            videoPhotos: videoPhotos,
            beginImportFlow: beginImportFlow,
            removeFromAlbum: removeFromAlbum,
            onAppearLoadDefaultViewMode: onAppearLoadDefaultViewMode,
            onChangeHomeViewMode: onChangeHomeViewMode,
            openSettings: openSettings,
            refreshAuthorizationStatus: refreshAuthorizationStatus
        )
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func refreshAuthorizationStatus() {
        appServices?.photoLibrary.refreshAuthorizationStatus()
    }

    private func onAppearLoadDefaultViewMode() {
        let settings = DataService.getOrCreateSettings(context: modelContext)
        let mode: HomeViewMode
        switch settings.defaultHomeView {
        case .events:
            mode = .grid
        case .profile:
            mode = .grid
        default:
            mode = settings.defaultHomeView
        }
        homeViewMode = mode
        if settings.defaultHomeView == .profile || settings.defaultHomeView == .events {
            settings.defaultHomeView = .grid
            try? modelContext.save()
        }
    }

    private func onChangeHomeViewMode(_ newValue: HomeViewMode) {
        let settings = DataService.getOrCreateSettings(context: modelContext)
        let toSave = newValue == .profile ? HomeViewMode.grid : newValue
        settings.defaultHomeView = toSave
        try? modelContext.save()
    }

    @MainActor
    private func removeFromAlbum(_ entry: PhotoEntry) {
        guard let services = appServices else { return }
        showRemoveConfirm = false
        entry.isInHomeAlbum = false
        try? modelContext.save()
        services.photoImageLoader.clearCache()
        entryPendingRemoval = nil
    }

    @MainActor
    private func beginImportFlow() async {
        guard let services = appServices else { return }
        services.photoLibrary.refreshAuthorizationStatus()
        switch services.photoLibrary.authorizationStatus {
        case .authorized, .limited:
            activeSheet = .photoPicker
        case .notDetermined:
            let ok = await services.photoLibrary.requestAuthorisationIfNeeded()
            if ok {
                activeSheet = .photoPicker
            } else {
                showPhotoDeniedAlert = true
            }
        case .denied, .restricted:
            showPhotoDeniedAlert = true
        @unknown default:
            showPhotoDeniedAlert = true
        }
    }
}

private func photoSort(_ lhs: PhotoEntry, _ rhs: PhotoEntry) -> Bool {
    switch (lhs.homeOrderIndex, rhs.homeOrderIndex) {
    case let (l?, r?):
        if l != r { return l < r }
    case (nil, nil):
        break
    case (nil, _?):
        return false
    case (_?, nil):
        return true
    }
    return lhs.capturedDate > rhs.capturedDate
}

private struct HomeScreenScaffold: View {
    @Binding var homeViewMode: HomeViewMode
    @Binding var activeSheet: HomeScreen.HomeSheet?
    @Binding var showPhotoDeniedAlert: Bool
    @Binding var entryPendingRemoval: PhotoEntry?
    @Binding var showRemoveConfirm: Bool
    @Binding var entryPendingEdit: PhotoEntry?
    @Binding var showEditTags: Bool
    @Binding var showReorderHome: Bool

    let photos: [PhotoEntry]
    let videoPhotos: [PhotoEntry]

    let beginImportFlow: @MainActor () async -> Void
    let removeFromAlbum: @MainActor (PhotoEntry) -> Void
    let onAppearLoadDefaultViewMode: () -> Void
    let onChangeHomeViewMode: (HomeViewMode) -> Void
    let openSettings: () -> Void
    let refreshAuthorizationStatus: () -> Void

    var body: some View {
        baseContent
            .navigationDestination(for: UUID.self) { id in destinationView(for: id) }
            .onAppear { onAppearLoadDefaultViewMode() }
            .onChange(of: homeViewMode) { _, newValue in onChangeHomeViewMode(newValue) }
            .sheet(item: $activeSheet) { sheet in activeSheetView(sheet) }
            .sheet(isPresented: $showReorderHome) { reorderSheet }
            .alert("Photos access needed", isPresented: $showPhotoDeniedAlert) { photosDeniedAlertActions } message: {
                Text("Allow Photos access in Settings to add items from your library to Cavira.")
            }
            .confirmationDialog(
                "Remove from Cavira?",
                isPresented: $showRemoveConfirm,
                titleVisibility: .visible,
                presenting: entryPendingRemoval
            ) { entry in
                Button("Remove from album", role: .destructive) { removeFromAlbum(entry) }
                Button("Cancel", role: .cancel) { entryPendingRemoval = nil }
            } message: { _ in
                Text("This only removes the item from your Cavira album. Nothing is deleted from Apple Photos.")
            }
            .sheet(isPresented: $showEditTags) { editTagsSheet }
            .onChange(of: showRemoveConfirm) { _, isShowing in if !isShowing { entryPendingRemoval = nil } }
            .onChange(of: showEditTags) { _, isShowing in if !isShowing { entryPendingEdit = nil } }
    }

    private var baseContent: some View {
        ZStack {
            homeContent
                .id(homeViewMode)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.18), value: homeViewMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Cavira")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Home layout", selection: $homeViewMode) {
                Text("Grid").tag(HomeViewMode.grid)
                Text("Timeline").tag(HomeViewMode.timeline)
                Text("Videos").tag(HomeViewMode.videos)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Home layout")
        }
        ToolbarItem(placement: .topBarLeading) {
            Button { showReorderHome = true } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(CaviraTheme.accent, CaviraTheme.textTertiary)
            }
            .accessibilityLabel("Reorder album")
            .disabled(photos.count < 2)
        }
        ToolbarItem(placement: .topBarTrailing) {
            AlbumImportToolbarButton(accessibilityLabel: "Add to album") {
                Task { await beginImportFlow() }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for id: UUID) -> some View {
        if let entry = photos.first(where: { $0.id == id }) {
            PhotoDetailView(entry: entry)
        } else {
            ContentUnavailableView(
                "Unavailable",
                systemImage: "photo",
                description: Text("This item is no longer in your album.")
            )
            .foregroundStyle(CaviraTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        switch homeViewMode {
        case .timeline:
            AlbumTimelineView(
                photos: photos,
                onRequestRemove: { entry in
                    entryPendingRemoval = entry
                    showRemoveConfirm = true
                },
                onEdit: { entry in
                    entryPendingEdit = entry
                    showEditTags = true
                }
            )
        case .videos:
            GridView(
                photos: videoPhotos,
                emptyTitle: videosOnlyEmptyTitle,
                emptySubtitle: videosOnlyEmptySubtitle,
                onRequestRemove: { entry in
                    entryPendingRemoval = entry
                    showRemoveConfirm = true
                },
                onEdit: { entry in
                    entryPendingEdit = entry
                    showEditTags = true
                }
            )
        case .grid, .profile, .events:
            GridView(
                photos: photos,
                onRequestRemove: { entry in
                    entryPendingRemoval = entry
                    showRemoveConfirm = true
                },
                onEdit: { entry in
                    entryPendingEdit = entry
                    showEditTags = true
                }
            )
        }
    }

    private var reorderSheet: some View {
        HomeReorderView()
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
    }

    private var editTagsSheet: some View {
        Group {
            if let entryPendingEdit {
                EditTagsSheet(entry: entryPendingEdit)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var photosDeniedAlertActions: some View {
        Button("Open Settings") { openSettings() }
        Button("Cancel", role: .cancel) {}
    }

    /// Empty-state title for the Videos segment when the filtered list is empty.
    private var videosOnlyEmptyTitle: String {
        if photos.isEmpty {
            "Import your media to start"
        } else {
            "No videos yet"
        }
    }

    /// Empty-state subtitle for the Videos segment when the filtered list is empty.
    private var videosOnlyEmptySubtitle: String? {
        if photos.isEmpty {
            "Your album stays in Apple Photos; Cavira is where you curate what appears here."
        } else {
            "Use + to add videos from your library, or open Grid or Timeline to browse photos and Live Photos."
        }
    }

    private func activeSheetView(_ sheet: HomeScreen.HomeSheet) -> some View {
        // Delegate to the original implementation shape by re-creating the switch here.
        // This reduces the generic depth of `HomeScreen.body` while keeping behavior identical.
        switch sheet {
        case .photoPicker:
            return AnyView(
                PhotoPickerRepresentable(
                    isPresented: Binding(
                        get: { activeSheet != nil },
                        set: { if !$0 { activeSheet = nil } }
                    )
                ) { results in
                    guard !results.isEmpty else { return }
                    activeSheet = .importOptions(id: UUID(), results: results)
                }
                .ignoresSafeArea()
            )
        case .importOptions(_, let results):
            return AnyView(ImportOptionsSheet(pickerResults: results))
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
    .caviraPreviewShell()
}
