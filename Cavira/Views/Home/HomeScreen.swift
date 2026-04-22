import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct HomeScreen: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \PhotoEntry.capturedDate, order: .reverse) private var photos: [PhotoEntry]
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    /// Album entries with `mediaKind == .video` (Videos segment only).
    private var videoPhotos: [PhotoEntry] {
        photos.filter { $0.mediaKind == .video }
    }

    @State private var homeViewMode: HomeViewMode = .grid
    private enum HomeSheet: Identifiable {
        case photoPicker
        case importOptions(results: [PHPickerResult])

        private static let pickerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        var id: UUID {
            switch self {
            case .photoPicker:
                return Self.pickerID
            case .importOptions:
                // New id each time ensures a fresh sheet instance.
                return UUID()
            }
        }
    }

    @State private var activeSheet: HomeSheet?
    @State private var showPhotoDeniedAlert = false
    @State private var entryPendingRemoval: PhotoEntry?
    @State private var showRemoveConfirm = false

    var body: some View {
        Group {
            switch homeViewMode {
            case .timeline:
                AlbumTimelineView(photos: photos) { entry in
                    entryPendingRemoval = entry
                    showRemoveConfirm = true
                }
            case .videos:
                GridView(
                    photos: videoPhotos,
                    emptyTitle: videosOnlyEmptyTitle,
                    emptySubtitle: videosOnlyEmptySubtitle,
                    onRequestRemove: { entry in
                        entryPendingRemoval = entry
                        showRemoveConfirm = true
                    }
                )
            case .events:
                HomeEventsSummaryView()
            case .grid, .profile:
                GridView(photos: photos) { entry in
                    entryPendingRemoval = entry
                    showRemoveConfirm = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Cavira")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Home layout", selection: $homeViewMode) {
                    Text("Grid").tag(HomeViewMode.grid)
                    Text("Timeline").tag(HomeViewMode.timeline)
                    Text("Videos").tag(HomeViewMode.videos)
                    Text("Events").tag(HomeViewMode.events)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Home layout")
            }
            ToolbarItem(placement: .topBarTrailing) {
                AlbumImportToolbarButton(accessibilityLabel: "Add to album") {
                    Task { await beginImportFlow() }
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        // Resolve `UUID` as **photo** (`PhotoEntry`) first, then **event** (`Event`) — avoids a second route type in `EventDetailView`.
        .navigationDestination(for: UUID.self) { id in
            if let entry = photos.first(where: { $0.id == id }) {
                PhotoDetailView(entry: entry)
            } else if let event = events.first(where: { $0.id == id }) {
                EventDetailView(event: event)
            } else {
                ContentUnavailableView(
                    "Unavailable",
                    systemImage: "photo",
                    description: Text("This item is no longer in your album.")
                )
                .foregroundStyle(CaviraTheme.textSecondary)
            }
        }
        .onAppear {
            let settings = DataService.getOrCreateSettings(context: modelContext)
            let mode = settings.defaultHomeView == .profile ? HomeViewMode.grid : settings.defaultHomeView
            homeViewMode = mode
            if settings.defaultHomeView == .profile {
                settings.defaultHomeView = .grid
                try? modelContext.save()
            }
        }
        .onChange(of: homeViewMode) { _, newValue in
            let settings = DataService.getOrCreateSettings(context: modelContext)
            let toSave = newValue == .profile ? HomeViewMode.grid : newValue
            settings.defaultHomeView = toSave
            try? modelContext.save()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .photoPicker:
                PhotoPickerRepresentable(
                    isPresented: Binding(
                        get: { activeSheet != nil },
                        set: { if !$0 { activeSheet = nil } }
                    )
                ) { results in
                    guard !results.isEmpty else { return }
                    // Present options only after the picker has fully dismissed.
                    activeSheet = .importOptions(results: results)
                }
                .ignoresSafeArea()
            case .importOptions(let results):
                ImportOptionsSheet(pickerResults: results)
            }
        }
        .alert("Photos access needed", isPresented: $showPhotoDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow Photos access in Settings to add items from your library to Cavira.")
        }
        .confirmationDialog(
            "Remove from Cavira?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible,
            presenting: entryPendingRemoval
        ) { entry in
            Button("Remove from album", role: .destructive) {
                removeFromAlbum(entry)
            }
            Button("Cancel", role: .cancel) {
                entryPendingRemoval = nil
            }
        } message: { _ in
            Text("This only removes the item from your Cavira album. Nothing is deleted from Apple Photos.")
        }
        .onChange(of: showRemoveConfirm) { _, isShowing in
            if !isShowing { entryPendingRemoval = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appServices?.photoLibrary.refreshAuthorizationStatus()
        }
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

    @MainActor
    private func removeFromAlbum(_ entry: PhotoEntry) {
        guard let services = appServices else { return }
        showRemoveConfirm = false
        do {
            try DataService.deletePhotoEntry(entry, context: modelContext, photoStorage: services.photoStorage)
            services.photoImageLoader.clearCache()
        } catch {
            // Phase 12: surface errors.
        }
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

#Preview {
    NavigationStack {
        HomeScreen()
    }
    .caviraPreviewShell()
}
