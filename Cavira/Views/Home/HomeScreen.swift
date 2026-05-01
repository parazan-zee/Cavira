import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct HomeScreen: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query(
        filter: #Predicate<PhotoEntry> { $0.isInHomeAlbum == true && $0.homeCollection == nil },
        sort: \PhotoEntry.capturedDate,
        order: .reverse
    )
    private var queriedStandalone: [PhotoEntry]

    @Query(sort: \HomeCollection.createdDate, order: .reverse)
    private var allHomeCollections: [HomeCollection]

    /// Standalone entries in the curated Home album (photos + videos), excluding collection members.
    private var albumEntries: [PhotoEntry] {
        queriedStandalone.sorted(by: albumSort)
    }

    /// Grid + timeline rows (standalone image tiles + collections).
    private var gridTimelineRows: [HomeAlbumRow] {
        let standaloneImages = albumEntries
            .filter { $0.mediaKind == .image }
            .map { HomeAlbumRow.standalone($0) }
        let cols = allHomeCollections
            .filter { $0.coverEntry != nil }
            .map { HomeAlbumRow.collection($0) }
        return (standaloneImages + cols).sorted(by: HomeAlbumRow.mergedSort)
    }

    private var photos: [PhotoEntry] {
        albumEntries.filter { $0.mediaKind == .image }
    }

    /// Album entries with `mediaKind == .video` (Videos segment only).
    private var videoPhotos: [PhotoEntry] {
        albumEntries
            .filter { $0.mediaKind == .video }
            .sorted(by: videoSort)
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
    @State private var rowPendingRemoval: HomeAlbumRow?
    @State private var showRemoveConfirm = false
    @State private var entryPendingEdit: PhotoEntry?
    @State private var showEditTags = false
    @State private var showReorderPhotos = false
    @State private var showReorderVideos = false

    // Prevent synthesized private memberwise init from `private` stored properties (e.g. `@Query photos`).
    init() {}

    var body: some View {
        HomeScreenScaffold(
            homeViewMode: $homeViewMode,
            activeSheet: $activeSheet,
            showPhotoDeniedAlert: $showPhotoDeniedAlert,
            rowPendingRemoval: $rowPendingRemoval,
            showRemoveConfirm: $showRemoveConfirm,
            entryPendingEdit: $entryPendingEdit,
            showEditTags: $showEditTags,
            showReorderPhotos: $showReorderPhotos,
            showReorderVideos: $showReorderVideos,
            gridTimelineRows: gridTimelineRows,
            photos: photos,
            videoPhotos: videoPhotos,
            albumEntries: albumEntries,
            allHomeCollections: allHomeCollections,
            beginImportFlow: beginImportFlow,
            removeRowFromHome: removeRowFromHome,
            onAppearLoadDefaultViewMode: onAppearLoadDefaultViewMode,
            onChangeHomeViewMode: onChangeHomeViewMode,
            onTapReorder: onTapReorder,
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
    private func removeRowFromHome(_ row: HomeAlbumRow) {
        guard let services = appServices else { return }
        showRemoveConfirm = false
        switch row {
        case .standalone(let entry):
            entry.isInHomeAlbum = false
        case .collection(let collection):
            let members = collection.entries
            for entry in members {
                entry.homeCollection = nil
                entry.collectionMemberOrder = nil
                entry.isInHomeAlbum = false
            }
            modelContext.delete(collection)
        }
        try? modelContext.save()
        services.photoImageLoader.clearCache()
        rowPendingRemoval = nil
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

    private func onTapReorder() {
        if homeViewMode == .videos {
            showReorderVideos = true
        } else {
            showReorderPhotos = true
        }
    }
}

private func albumSort(_ lhs: PhotoEntry, _ rhs: PhotoEntry) -> Bool {
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

private func videoSort(_ lhs: PhotoEntry, _ rhs: PhotoEntry) -> Bool {
    switch (lhs.videoOrderIndex, rhs.videoOrderIndex) {
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
    @Binding var rowPendingRemoval: HomeAlbumRow?
    @Binding var showRemoveConfirm: Bool
    @Binding var entryPendingEdit: PhotoEntry?
    @Binding var showEditTags: Bool
    @Binding var showReorderPhotos: Bool
    @Binding var showReorderVideos: Bool

    let gridTimelineRows: [HomeAlbumRow]
    let photos: [PhotoEntry]
    let videoPhotos: [PhotoEntry]
    let albumEntries: [PhotoEntry]
    let allHomeCollections: [HomeCollection]

    let beginImportFlow: @MainActor () async -> Void
    let removeRowFromHome: @MainActor (HomeAlbumRow) -> Void
    let onAppearLoadDefaultViewMode: () -> Void
    let onChangeHomeViewMode: (HomeViewMode) -> Void
    let onTapReorder: () -> Void
    let openSettings: () -> Void
    let refreshAuthorizationStatus: () -> Void

    var body: some View {
        baseContent
            .navigationDestination(for: HomeDestination.self) { dest in
                destinationView(for: dest)
            }
            .onAppear { onAppearLoadDefaultViewMode() }
            .onChange(of: homeViewMode) { _, newValue in onChangeHomeViewMode(newValue) }
            .sheet(item: $activeSheet) { sheet in activeSheetView(sheet) }
            .sheet(isPresented: $showReorderPhotos) { reorderPhotosSheet }
            .sheet(isPresented: $showReorderVideos) { reorderVideosSheet }
            .alert("Photos access needed", isPresented: $showPhotoDeniedAlert) { photosDeniedAlertActions } message: {
                Text("Allow Photos access in Settings to add items from your library to Cavira.")
            }
            .confirmationDialog(
                "Remove from Cavira?",
                isPresented: $showRemoveConfirm,
                titleVisibility: .visible,
                presenting: rowPendingRemoval
            ) { row in
                Button("Remove from album", role: .destructive) { removeRowFromHome(row) }
                Button("Cancel", role: .cancel) { rowPendingRemoval = nil }
            } message: { row in
                switch row {
                case .standalone:
                    Text("This only removes the item from your Cavira album. Nothing is deleted from Apple Photos.")
                case .collection:
                    Text("This removes the collection from Home. Photos stay in Cavira for Stories and elsewhere. Nothing is deleted from Apple Photos.")
                }
            }
            .sheet(isPresented: $showEditTags) { editTagsSheet }
            .onChange(of: showRemoveConfirm) { _, isShowing in if !isShowing { rowPendingRemoval = nil } }
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
            Button { onTapReorder() } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(CaviraTheme.accent, CaviraTheme.textTertiary)
            }
            .accessibilityLabel("Reorder album")
            .disabled((homeViewMode == .videos ? videoPhotos.count : gridTimelineRows.count) < 2)
        }
        ToolbarItem(placement: .topBarTrailing) {
            AlbumImportToolbarButton(accessibilityLabel: "Add to album") {
                Task { await beginImportFlow() }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for dest: HomeDestination) -> some View {
        switch dest {
        case .photo(let id):
            if let entry = albumEntries.first(where: { $0.id == id }) {
                PhotoDetailView(entry: entry)
            } else {
                ContentUnavailableView(
                    "Unavailable",
                    systemImage: "photo",
                    description: Text("This item is no longer in your album.")
                )
                .foregroundStyle(CaviraTheme.textSecondary)
            }
        case .collection(let id):
            if let collection = allHomeCollections.first(where: { $0.id == id }) {
                HomeCollectionViewer(collection: collection)
            } else {
                ContentUnavailableView(
                    "Unavailable",
                    systemImage: "square.stack",
                    description: Text("This collection is no longer on Home.")
                )
                .foregroundStyle(CaviraTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        switch homeViewMode {
        case .timeline:
            AlbumTimelineView(
                rows: gridTimelineRows,
                onRequestRemoveRow: { row in
                    rowPendingRemoval = row
                    showRemoveConfirm = true
                },
                onEdit: { entry in
                    entryPendingEdit = entry
                    showEditTags = true
                }
            )
        case .videos:
            GridView(
                rows: videoPhotos.map { HomeAlbumRow.standalone($0) },
                emptyTitle: videosOnlyEmptyTitle,
                emptySubtitle: videosOnlyEmptySubtitle,
                onRequestRemoveRow: { row in
                    if case .standalone(let entry) = row {
                        rowPendingRemoval = .standalone(entry)
                        showRemoveConfirm = true
                    }
                },
                onEdit: { entry in
                    entryPendingEdit = entry
                    showEditTags = true
                }
            )
        case .grid, .profile, .events:
            GridView(
                rows: gridTimelineRows,
                onRequestRemoveRow: { row in
                    rowPendingRemoval = row
                    showRemoveConfirm = true
                },
                onEdit: { entry in
                    entryPendingEdit = entry
                    showEditTags = true
                }
            )
        }
    }

    private var reorderPhotosSheet: some View {
        HomeReorderView()
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
    }

    private var reorderVideosSheet: some View {
        VideoReorderView()
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
        if gridTimelineRows.isEmpty && videoPhotos.isEmpty {
            "Import your media to start"
        } else {
            "No videos yet"
        }
    }

    /// Empty-state subtitle for the Videos segment when the filtered list is empty.
    private var videosOnlyEmptySubtitle: String? {
        if gridTimelineRows.isEmpty && videoPhotos.isEmpty {
            "Your album stays in Apple Photos; Cavira is where you curate what appears here."
        } else {
            "Use + to add videos from your library, or open Grid or Timeline to browse your photos."
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
                    ,
                    mediaMode: homeViewMode == .videos ? .videosOnly : .photosOnly
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
