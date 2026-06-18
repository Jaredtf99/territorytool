import SwiftUI

struct SettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared

    @State private var showLogoutAlert = false

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
        .scrollContentBackground(.hidden)
        .background {
            LiquidBackgroundView()
        }
    }
}

extension Notification.Name {
    static let userRequestedLogout = Notification.Name("userRequestedLogout")
}
