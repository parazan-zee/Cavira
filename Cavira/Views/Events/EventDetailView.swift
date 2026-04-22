import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Occasion detail: grid of linked **`PhotoEntry`** rows + **top-trailing `+`** import (not in the nav bar).
struct EventDetailView: View {
    @Bindable var event: Event
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private enum EventSheet: Identifiable {
        case photoPicker
        case importOptions(results: [PHPickerResult])

        private static let pickerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        var id: UUID {
            switch self {
            case .photoPicker:
                return Self.pickerID
            case .importOptions:
                return UUID()
            }
        }
    }

    @State private var activeSheet: EventSheet?
    @State private var showPhotoDeniedAlert = false
    @State private var showEditEvent = false

    private var sortedPhotos: [PhotoEntry] {
        event.photos.sorted { $0.capturedDate > $1.capturedDate }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: CaviraTheme.Spacing.lg) {
                    headerBlock

                    if sortedPhotos.isEmpty {
                        EmptyStateView(
                            title: "No media in this event",
                            subtitle: "Tap + to add photos and videos from your library. They stay in Apple Photos; Cavira only links them here."
                        )
                        .padding(.top, CaviraTheme.Spacing.xl)
                    } else {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(sortedPhotos, id: \.id) { entry in
                                NavigationLink(value: entry.id) {
                                    PhotoThumbnailView(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Remove from event", systemImage: "rectangle.badge.minus") {
                                        removeFromEvent(entry)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, CaviraTheme.Spacing.sm)
                .padding(.bottom, 100)
            }
            .background(CaviraTheme.backgroundPrimary)

            Button {
                Task { await beginImportFlow() }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CaviraTheme.textOnAccent)
                    .frame(width: 56, height: 56)
                    .background(CaviraTheme.accent, in: Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to this event")
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: CaviraTheme.Spacing.md) {
                    Button {
                        event.isPinned.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: event.isPinned ? "pin.fill" : "pin")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(event.isPinned ? CaviraTheme.accent : CaviraTheme.textSecondary)
                    .accessibilityLabel(event.isPinned ? "Unpin from profile" : "Pin to profile")

                    Button("Edit") {
                        showEditEvent = true
                    }
                    .foregroundStyle(CaviraTheme.accent)
                }
            }
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
                    activeSheet = .importOptions(results: results)
                }
                .ignoresSafeArea()
            case .importOptions(let results):
                ImportOptionsSheet(pickerResults: results, presetEvent: event)
            }
        }
        .sheet(isPresented: $showEditEvent) {
            CreateEditEventView(existing: event, onEventDeleted: {
                dismiss()
            })
        }
        .alert("Photos access needed", isPresented: $showPhotoDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow Photos access in Settings to add items from your library.")
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: CaviraTheme.Spacing.sm) {
            Text(eventDateRangeLine)
                .font(CaviraTheme.Typography.body)
                .foregroundStyle(CaviraTheme.textSecondary)
            if let desc = event.eventDescription, !desc.isEmpty {
                Text(desc)
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CaviraTheme.Spacing.sm)
    }

    private var eventDateRangeLine: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        if let end = event.endDate {
            return "\(df.string(from: event.startDate)) – \(df.string(from: end))"
        }
        return df.string(from: event.startDate)
    }

    private func removeFromEvent(_ entry: PhotoEntry) {
        entry.event = nil
        try? modelContext.save()
        appServices?.photoImageLoader.clearCache()
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
        Text("Wire an Event from SwiftData preview container")
    }
    .caviraPreviewShell()
}
