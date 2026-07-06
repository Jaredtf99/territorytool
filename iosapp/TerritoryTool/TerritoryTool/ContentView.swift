//
//  ContentView.swift
//  TerritoryTool
//
//  Created by Jared Trapiello on 3/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("PREVIEW_REPORT") {
                ReportPreviewHarness()
            } else if appViewModel.isAuthenticated {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView(viewModel: DIContainer.shared.makeLoginViewModel())
                }
            }
        }
        .environment(\.locale, languageManager.locale)
        .preferredColorScheme(themeManager.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .authChanged)) { _ in
            appViewModel.checkAuth()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userRequestedLogout)) { _ in
            appViewModel.logout()
        }
        .overlay {
            if appViewModel.showSessionExpiredAlert {
                SessionExpiredAlertView(onLogout: {
                    appViewModel.logout()
                })
                .transition(.opacity)
            }
        }
    }
}

// Temporary scaffolding: renders the report screen with mock data and
// auto-generates the PDF so it can be screenshotted headlessly.
private struct ReportPreviewHarness: View {
    @StateObject private var viewModel = TerritoryReportViewModel(apiService: MockAPIService())

    var body: some View {
        NavigationStack {
            TerritoryReportView(viewModel: viewModel)
        }
        .task { await viewModel.generate() }
    }
}

extension Notification.Name {
    static let authChanged = Notification.Name("authChanged")
    // userRequestedLogout is defined in SettingsView.swift or should be moved to a shared extension file
}

#Preview {
    ContentView()
}
