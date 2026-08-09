import SwiftUI

struct SettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared

    @State private var showLogoutAlert = false
    @State private var showClearMapCacheAlert = false
    @State private var mapSnapshotCacheSizeBytes: Int64 = 0

    var body: some View {
        Form {
            if permissionManager.canManageUsers || permissionManager.canManageCongregations {
                Section(header: Text("settings.administration")) {
                    if permissionManager.canManageUsers {
                        NavigationLink(destination: UsersView()) {
                            Label("users.title", systemImage: "person.2.badge.gearshape.fill")
                        }
                    }
                    if permissionManager.canManageCongregations {
                        NavigationLink(destination: CongregationsManagementView()) {
                            Label("congregations.title", systemImage: "building.2.fill")
                        }
                    }
                }
            }

            Section(header: Text("settings.reports")) {
                NavigationLink(destination: TerritoryReportView()) {
                    Label("reports.title", systemImage: "doc.richtext.fill")
                }
            }

            Section(header: Text("settings.appearance")) {
                Picker("settings.appearance", selection: $themeManager.currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("settings.language")) {
                Picker("settings.language", selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(
                header: Text("settings.storage"),
                footer: Text("settings.map_cache.description")
            ) {
                HStack {
                    Label("settings.map_cache.title", systemImage: "map.fill")
                    Spacer()
                    Text(formattedMapSnapshotCacheSize)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Button(role: .destructive) {
                    showClearMapCacheAlert = true
                } label: {
                    Text("settings.map_cache.clear")
                }
                .disabled(mapSnapshotCacheSizeBytes == 0)
            }
            
            Section(header: Text("settings.account")) {
                NavigationLink(destination: ChangePasswordView()) {
                    Label("change_password.title", systemImage: "key.fill")
                }
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Text("logout.title")
                }
            }
        }
        .navigationTitle("settings.title")
        .alert("logout.title", isPresented: $showLogoutAlert) {
            Button("cancel", role: .cancel) { }
            Button("logout.title", role: .destructive) {
                NotificationCenter.default.post(name: .userRequestedLogout, object: nil)
            }
        } message: {
            Text("settings.logout.confirmation")
        }
        .alert("settings.map_cache.clear", isPresented: $showClearMapCacheAlert) {
            Button("cancel", role: .cancel) { }
            Button("settings.map_cache.clear", role: .destructive) {
                Task {
                    await TerritorySnapshotCache.shared.clear()
                    await refreshMapSnapshotCacheSize()
                }
            }
        } message: {
            Text("settings.map_cache.clear_confirmation")
        }
        .task {
            await refreshMapSnapshotCacheSize()
        }
        .scrollContentBackground(.hidden)
        .background {
            LiquidBackgroundView()
        }
    }

    private var formattedMapSnapshotCacheSize: String {
        ByteCountFormatter.string(
            fromByteCount: mapSnapshotCacheSizeBytes,
            countStyle: .file
        )
    }

    /// Enumerar el directorio de caché también salía del hilo principal: ahora lo hace el
    /// worker de disco y aquí sólo se espera el resultado.
    private func refreshMapSnapshotCacheSize() async {
        mapSnapshotCacheSizeBytes = await TerritorySnapshotCache.shared.diskSizeBytes()
    }
}
