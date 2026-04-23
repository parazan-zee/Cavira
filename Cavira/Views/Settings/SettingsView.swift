import SwiftUI

struct SettingsView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext

    @State private var settings: AppSettings?
    @State private var storageUsedBytes: Int64 = 0

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
            } header: {
                Text("Display")
                    .foregroundStyle(CaviraTheme.textSecondary)
            } footer: {
                Text("Cavira v1 ships one visual system (Ranger). Appearance and themes aren’t configurable yet.")
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

                HStack {
                    Text("Version")
                        .foregroundStyle(CaviraTheme.textPrimary)
                    Spacer()
                    Text(appVersionLabel)
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

    private func sanitizeLegacyDefaultsIfNeeded(_ settings: AppSettings) {
        if settings.defaultHomeView == .events || settings.defaultHomeView == .profile {
            settings.defaultHomeView = .grid
            try? modelContext.save()
        }
    }

    private var storageUsedLabel: String {
        ByteCountFormatter.string(fromByteCount: storageUsedBytes, countStyle: .file)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? "—"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .caviraPreviewShell()
}
