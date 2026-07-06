import Combine
import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case territories
    case brothers
    case actionLogs
    case settings
    /// Pestaña de rol .search (iOS 26): no muestra contenido, dispara Acción rápida.
    case quickAction
}

enum TerritoriesPresentation: Hashable {
    case list
    case map
}

struct TerritoriesLaunchContext: Equatable {
    let filter: TerritoryFilter
    let presentation: TerritoriesPresentation
    let attentionDays: Int

    static let free = TerritoriesLaunchContext(filter: .free, presentation: .list, attentionDays: 90)
    static let inUse = TerritoriesLaunchContext(filter: .inUse, presentation: .list, attentionDays: 90)
    static let attention = TerritoriesLaunchContext(filter: .attention, presentation: .list, attentionDays: 90)
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .dashboard
    @Published var dashboardPath = NavigationPath()
    @Published var territoriesPath = NavigationPath()
    @Published var brothersPath = NavigationPath()
    @Published var actionLogsPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    @Published var territoriesLaunchContext: TerritoriesLaunchContext?
    @Published var isQuickActionPresented = false
    @Published var quickActionInitialResolution: QuickActionResolution?

    private init() {}

    var isSelectedTabAtRoot: Bool {
        switch selectedTab {
        case .dashboard: dashboardPath.isEmpty
        case .territories: territoriesPath.isEmpty
        case .brothers: brothersPath.isEmpty
        case .actionLogs: actionLogsPath.isEmpty
        case .settings: settingsPath.isEmpty
        case .quickAction: true
        }
    }

    func openTerritories(_ context: TerritoriesLaunchContext) {
        territoriesLaunchContext = context
        territoriesPath = NavigationPath()
        selectedTab = .territories
    }

    func openQuickAction(_ resolution: QuickActionResolution? = nil) {
        quickActionInitialResolution = resolution
        isQuickActionPresented = true
    }

    func closeQuickAction() {
        quickActionInitialResolution = nil
        isQuickActionPresented = false
    }

    func consumeTerritoriesLaunchContext() -> TerritoriesLaunchContext? {
        defer { territoriesLaunchContext = nil }
        return territoriesLaunchContext
    }
}
