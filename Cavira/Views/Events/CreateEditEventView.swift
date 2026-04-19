import SwiftData
import SwiftUI

/// Create (`existing == nil`) or edit an **`Event`** occasion.
struct CreateEditEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// `nil` = create a new event.
    var existing: Event?
    /// Called after the event row is deleted (e.g. parent **`EventDetailView`** should pop).
    var onEventDeleted: (() -> Void)? = nil

    @State private var title: String = ""
    @State private var eventDescription: String = ""
    @State private var startDate: Date = .now
    @State private var hasEndDate = false
    @State private var endDate: Date = .now
    @State private var showDeleteConfirm = false
    /// `nil` = use automatic cover (**`EventCardView`** picks latest in album).
    @State private var coverPhotoIdPick: UUID?

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var sortedCoverCandidates: [PhotoEntry] {
        guard let e = existing else { return [] }
        return e.photos.sorted { $0.capturedDate > $1.capturedDate }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Required", text: $title)
                        .foregroundStyle(CaviraTheme.textPrimary)
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                Section("Description") {
                    TextEditor(text: $eventDescription)
                        .frame(minHeight: 80)
                        .foregroundStyle(CaviraTheme.textPrimary)
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                Section("Dates") {
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                        .tint(CaviraTheme.accent)
                    Toggle("End date", isOn: $hasEndDate)
                        .tint(CaviraTheme.accent)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .tint(CaviraTheme.accent)
                    }
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                if isEditing, sortedCoverCandidates.count >= 2 {
                    Section("Cover photo") {
                        Picker("Card thumbnail", selection: $coverPhotoIdPick) {
                            Text("Automatic (latest)").tag(nil as UUID?)
                            ForEach(sortedCoverCandidates, id: \.id) { p in
                                Text(coverRowLabel(for: p)).tag(Optional(p.id))
                            }
                        }
                        .tint(CaviraTheme.accent)
                    }
                    .listRowBackground(CaviraTheme.surfaceCard)
                }

                if isEditing {
                    Section {
                        Button("Delete event", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                    .listRowBackground(CaviraTheme.surfaceCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle(isEditing ? "Edit event" : "New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(CaviraTheme.accent)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let e = existing {
                    title = e.title
                    eventDescription = e.eventDescription ?? ""
                    startDate = e.startDate
                    coverPhotoIdPick = e.coverPhotoId
                    if let ed = e.endDate {
                        hasEndDate = true
                        endDate = ed
                    } else {
                        hasEndDate = false
                        endDate = e.startDate
                    }
                }
            }
            .confirmationDialog(
                "Delete this event?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteExisting()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photos stay in your album; only the occasion and links are removed.")
            }
        }
    }

    private func coverRowLabel(for entry: PhotoEntry) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        switch entry.mediaKind {
        case .video:
            return "Video · \(f.string(from: entry.capturedDate))"
        case .image:
            return entry.isLivePhoto ? "Live Photo · \(f.string(from: entry.capturedDate))" : "Photo · \(f.string(from: entry.capturedDate))"
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let desc = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue: String? = desc.isEmpty ? nil : desc
        let endValue: Date? = hasEndDate ? endDate : nil

        if let e = existing {
            e.title = trimmed
            e.eventDescription = descriptionValue
            e.startDate = startDate
            e.endDate = endValue
            if sortedCoverCandidates.count >= 2 {
                if let pick = coverPhotoIdPick, sortedCoverCandidates.contains(where: { $0.id == pick }) {
                    e.coverPhotoId = pick
                } else {
                    e.coverPhotoId = nil
                }
            }
        } else {
            let e = Event(
                title: trimmed,
                eventDescription: descriptionValue,
                startDate: startDate,
                endDate: endValue,
                isPinned: false
            )
            modelContext.insert(e)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteExisting() {
        guard let e = existing else { return }
        for p in e.photos {
            p.event = nil
        }
        modelContext.delete(e)
        try? modelContext.save()
        onEventDeleted?()
        dismiss()
    }
}
