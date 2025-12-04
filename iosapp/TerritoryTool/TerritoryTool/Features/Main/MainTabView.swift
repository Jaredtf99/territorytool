import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(viewModel: DIContainer.shared.makeDashboardViewModel())
            }
            .tabItem {
                Label("dashboard.title", systemImage: "house.fill")
            }
            
            NavigationStack {
                TerritoriesView(viewModel: DIContainer.shared.makeTerritoriesViewModel())
            }
            .tabItem {
                Label("territories.title", systemImage: "map.fill")
            }
        }
    }
}
