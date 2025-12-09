import SwiftUI
import SystemNotification

struct MainTabView: View {
    @ObservedObject private var toastManager = ToastManager.shared
    @StateObject private var notificationContext = SystemNotificationContext()
    
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(viewModel: DIContainer.shared.makeDashboardViewModel())
            }
            .tabItem {
                Label("dashboard.title", systemImage: "house.fill")
            }
            
            NavigationStack {
                TerritoriesView()
            }
            .tabItem {
                Label("territories.title", systemImage: "map.fill")
            }
            
            NavigationStack {
                TerritoryAssignmentView()
            }
            .tabItem {
                Label("assignment.title", systemImage: "person.badge.plus")
            }
            
            NavigationStack {
                TerritoryReturnView()
            }
            .tabItem {
                Label("return.title", systemImage: "tray.and.arrow.down")
            }
            
            NavigationStack {
                BrothersView()
            }
            .tabItem {
                Label("brothers.title", systemImage: "person.3.fill")
            }
        }
        .systemNotification(notificationContext)
        .onChange(of: toastManager.pendingMessage) { _, newValue in
            if let message = newValue {
                // Trigger Haptic Feedback
                switch message.style {
                case .success:
                    HapticManager.shared.notification(type: .success)
                case .error:
                    HapticManager.shared.notification(type: .error)
                case .warning:
                    HapticManager.shared.notification(type: .warning)
                case .info:
                    HapticManager.shared.impact(style: .light)
                }
                
                notificationContext.present() {
                    SystemNotificationMessage(
                        icon: Image(systemName: message.style.icon)
                            .font(.title2)
                            .foregroundColor(message.style.color),
                        title: nil,
                        text: LocalizedStringKey(message.message)
                    )
                }
                
                // Clear pending message
                toastManager.clearPending()
            }
        }
    }
}
