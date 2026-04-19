import PhotosUI
import SwiftData
import SwiftUI

/// How imported items attach to an occasion when **`presetEvent`** is nil.
private enum ImportOccasionTarget: Hashable {
    case newOccasion
    case existing(UUID)
}

/// Confirmation step after picking library assets; performs reference-only import.
struct ImportOptionsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss

    let pickerResults: [PHPickerResult]
    /// When set (e.g. import from **`EventDetailView`**), items are linked to this occasion; the event picker is hidden.
    var presetEvent: Event? = nil

    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]

    @State private var addToEvent = false
    @State private var newOccasionTitle: String = ""
    @State private var occasionTarget: ImportOccasionTarget = .newOccasion
    @State private var importErrorMessage: String?
    @State private var showImportMessageAlert = false
    @State private var isImporting = false

    private var itemCount: Int {
        pickerResults.count
    }

    /// `true` when “Add to an event” is on but the user has not satisfied title / picker rules.
    private var occasionAssignmentInvalid: Bool {
        guard presetEvent == nil, addToEvent else { return false }
        if events.isEmpty {
            return newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        switch occasionTarget {
        case .newOccasion:
            return newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .existing:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Items stay in Apple Photos. Cavira saves organisation and tags only — no duplicate library on your device.")
                        .font(CaviraTheme.Typography.body)
                        .foregroundStyle(CaviraTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(CaviraTheme.surfaceCard)

                Section {
                    if let locked = presetEvent {
                        LabeledContent("Occasion") {
                            Text(locked.title)
                                .font(CaviraTheme.Typography.body)
                                .foregroundStyle(CaviraTheme.textSecondary)
                        }
                        Text("New picks are added to your Cavira album and linked to this occasion.")
                            .font(CaviraTheme.Typography.caption)
                            .foregroundStyle(CaviraTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Toggle("Add to an event", isOn: $addToEvent)
                            .tint(CaviraTheme.accent)
                        if addToEvent {
                            if events.isEmpty {
                                Text("New occasion")
                                    .font(CaviraTheme.Typography.caption)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                                TextField("Occasion name", text: $newOccasionTitle)
                                    .foregroundStyle(CaviraTheme.textPrimary)
                                Text("A new occasion is created when you import. You can edit dates in Calendar.")
                                    .font(CaviraTheme.Typography.caption)
                                    .foregroundStyle(CaviraTheme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Picker("Assign to", selection: $occasionTarget) {
                                    Text("New occasion…").tag(ImportOccasionTarget.newOccasion)
                                    ForEach(events, id: \.id) { ev in
                                        Text(ev.title).tag(ImportOccasionTarget.existing(ev.id))
                                    }
                                }
                                .tint(CaviraTheme.accent)

                                if occasionTarget == .newOccasion {
                                    TextField("New occasion name", text: $newOccasionTitle)
                                        .foregroundStyle(CaviraTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(CaviraTheme.surfaceCard)
            }
            .scrollContentBackground(.hidden)
            .background(CaviraTheme.backgroundSecondary)
            .navigationTitle(itemCount == 1 ? "Import 1 item" : "Import \(itemCount) items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CaviraTheme.barBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CaviraTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { runImport() }
                        .fontWeight(.semibold)
                        .foregroundStyle(CaviraTheme.accent)
                        .disabled(isImporting || occasionAssignmentInvalid)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView()
                        .tint(CaviraTheme.accent)
                        .padding()
                        .background(CaviraTheme.surfaceElevated.opacity(0.95), in: RoundedRectangle(cornerRadius: CaviraTheme.Radius.medium))
                }
            }
            .alert("Import", isPresented: $showImportMessageAlert) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .onAppear {
                guard presetEvent == nil else { return }
                addToEvent = false
                newOccasionTitle = ""
                occasionTarget = events.first.map { .existing($0.id) } ?? .newOccasion
            }
        }
    }

    private func runImport() {
        guard let services = appServices else { return }

        let event: Event? = {
            if let presetEvent { return presetEvent }
            guard addToEvent else { return nil }

            if events.isEmpty {
                let t = newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let e = Event(title: t, startDate: .now, endDate: nil, isPinned: false)
                modelContext.insert(e)
                try? modelContext.save()
                return e
            }

            switch occasionTarget {
            case .newOccasion:
                let t = newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let e = Event(title: t, startDate: .now, endDate: nil, isPinned: false)
                modelContext.insert(e)
                try? modelContext.save()
                return e
            case .existing(let id):
                return events.first { $0.id == id }
            }
        }()

        if presetEvent == nil, addToEvent, event == nil {
            importErrorMessage = "Enter an occasion name, pick an existing occasion, or turn off “Add to an event”."
            showImportMessageAlert = true
            return
        }

        isImporting = true
        Task { @MainActor in
            defer { isImporting = false }
            do {
                let inserted = try PhotoImportService.importPickerResults(
                    pickerResults,
                    event: event,
                    context: modelContext,
                    photoLibrary: services.photoLibrary
                )
                if inserted == 0, !pickerResults.isEmpty {
                    importErrorMessage = "Nothing new was added. Selected items may already be in your album."
                    showImportMessageAlert = true
                } else {
                    dismiss()
                }
            } catch {
                importErrorMessage = error.localizedDescription
                showImportMessageAlert = true
            }
        }
    }
}
