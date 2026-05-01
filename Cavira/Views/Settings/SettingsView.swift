import SwiftUI

struct SettingsView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext

    @State private var settings: AppSettings?
    @State private var storageUsedBytes: Int64 = 0
    @State private var showThemePicker = false
    @State private var showResetSettingsConfirm = false
    @State private var showDeleteAllDataConfirm = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Photos stay in your library. Cavira doesn’t duplicate full‑resolution files in v1.")
                        .font(CaviraTheme.Typography.caption)
                        .foregroundStyle(CaviraTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("On‑device copy storage")
                            .foregroundStyle(CaviraTheme.textPrimary)
                        Spacer()
                        Text(storageUsedLabel)
                            .foregroundStyle(CaviraTheme.textTertiary)
                    }

                    NavigationLink {
                        StorageSettingsView()
                    } label: {
                        Text("Manage stored photos")
                            .foregroundStyle(CaviraTheme.textPrimary)
                    }
                }
            } header: {
                Text("Storage")
                    .foregroundStyle(CaviraTheme.textSecondary)
            }

            Section {
                Picker("Default home view", selection: defaultHomeViewBinding) {
                    Text("Grid").tag(HomeViewMode.grid)
                    Text("Timeline").tag(HomeViewMode.timeline)
                    Text("Videos").tag(HomeViewMode.videos)
                }
                .tint(CaviraTheme.accent)

                HStack {
                    Text("Theme")
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Spacer()
                    Button {
                        showThemePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            themeSwatch(themePaletteBinding.wrappedValue.themePickerSwatchColor)
                            Text(themePaletteBinding.wrappedValue.displayName)
                                .foregroundStyle(CaviraTheme.textTertiary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CaviraTheme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Theme")
                }
            } header: {
                Text("Display")
                    .foregroundStyle(CaviraTheme.textSecondary)
            } footer: {
                Text("Ranger is the default. Themes change colors only — layout and features stay the same.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }

            Section {
                Button {
                    showResetSettingsConfirm = true
                } label: {
                    Text("Reset settings")
                        .foregroundStyle(CaviraTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(role: .destructive) {
                    showDeleteAllDataConfirm = true
                } label: {
                    Text("Delete all Cavira data")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text("Data")
                    .foregroundStyle(CaviraTheme.textSecondary)
            } footer: {
                Text("Reset restores default preferences only. Delete removes stories, Home organisation, tags, and notes from Cavira. Nothing is removed from Apple Photos.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textTertiary)
            }

            Section {
                HStack {
                    Text("App")
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Spacer()
                    Text("Cavira")
                        .foregroundStyle(CaviraTheme.textTertiary)
                }

                Text("Built for privacy. Everything stays on your device.")
                    .font(CaviraTheme.Typography.caption)
                    .foregroundStyle(CaviraTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("About")
                    .foregroundStyle(CaviraTheme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(CaviraTheme.backgroundPrimary)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            let s = DataService.getOrCreateSettings(context: modelContext)
            settings = s
            sanitizeLegacyDefaultsIfNeeded(s)
            storageUsedBytes = Int64(appServices?.photoStorage.totalStorageUsed() ?? 0)
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet(
                selected: themePaletteBinding.wrappedValue,
                onSelect: { palette in
                    themePaletteBinding.wrappedValue = palette
                    showThemePicker = false
                },
                onCancel: { showThemePicker = false }
            )
            .presentationDetents([.fraction(0.75), .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Reset settings?", isPresented: $showResetSettingsConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset") {
                performResetSettings()
            }
        } message: {
            Text("This restores the default home view, appearance, and theme. Your stories and library organisation are not affected.")
        }
        .alert("Delete all Cavira data?", isPresented: $showDeleteAllDataConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) {
                performDeleteAllData()
            }
        } message: {
            Text("This permanently removes stories, Home album layout, tags, and notes stored in Cavira. Photos and videos in Apple Photos are not deleted.")
        }
    }

    private func performResetSettings() {
        do {
            try DataService.resetSettingsToDefaults(context: modelContext)
            let s = DataService.getOrCreateSettings(context: modelContext)
            settings = s
            ThemeStore.shared.apply(s.themePalette ?? .ranger)
            storageUsedBytes = Int64(appServices?.photoStorage.totalStorageUsed() ?? 0)
        } catch {
            // SwiftData save failures are rare; no separate UI in v1.
        }
    }

    private func performDeleteAllData() {
        guard let photoStorage = appServices?.photoStorage else { return }
        do {
            try DataService.deleteAllCaviraData(context: modelContext, photoStorage: photoStorage)
            let s = DataService.getOrCreateSettings(context: modelContext)
            settings = s
            ThemeStore.shared.apply(s.themePalette ?? .ranger)
            storageUsedBytes = Int64(photoStorage.totalStorageUsed())
        } catch {
            // Rare; user can retry.
        }
    }

    private var defaultHomeViewBinding: Binding<HomeViewMode> {
        Binding(
            get: { settings?.defaultHomeView ?? .grid },
            set: { newValue in
                let sanitized: HomeViewMode = {
                    switch newValue {
                    case .grid, .timeline, .videos:
                        return newValue
                    case .events, .profile:
                        return .grid
                    }
                }()
                let s = settings ?? DataService.getOrCreateSettings(context: modelContext)
                settings = s
                s.defaultHomeView = sanitized
                try? modelContext.save()
            }
        )
    }

    private var themePaletteBinding: Binding<ThemePalette> {
        Binding(
            get: { settings?.themePalette ?? .ranger },
            set: { newValue in
                let s = settings ?? DataService.getOrCreateSettings(context: modelContext)
                settings = s
                s.themePalette = newValue
                try? modelContext.save()
                ThemeStore.shared.apply(newValue)
            }
        )
    }

    private func themeSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(CaviraTheme.border, lineWidth: 1)
            )
    }

    private func sanitizeLegacyDefaultsIfNeeded(_ settings: AppSettings) {
        if settings.defaultHomeView == .events || settings.defaultHomeView == .profile {
            settings.defaultHomeView = .grid
            try? modelContext.save()
        }
    }

    private var storageUsedLabel: String {
        ByteCountFormatter.string(fromByteCount: storageUsedBytes, countStyle: .file)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .caviraPreviewShell()
}
