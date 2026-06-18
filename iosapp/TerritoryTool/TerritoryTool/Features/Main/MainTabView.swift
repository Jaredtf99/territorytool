import SwiftUI
import SystemNotification

/// Navegación raíz: 5 tabs como máximo (iOS oculta el resto en "More").
/// Asignar/Devolver son acciones contextuales (botón + en Territorios y detalle),
/// Usuarios vive dentro de Ajustes. Ver docs/DESIGN_GUIDE.md §6.
struct MainTabView: View {
    @ObservedObject private var toastManager = ToastManager.shared
    @StateObject private var notificationContext = SystemNotificationContext()
    @ObservedObject private var permissionManager = PermissionManager.shared

    var body: some View {
        TabView {
            Tab("dashboard.title", systemImage: "house.fill") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("territories.title", systemImage: "map.fill") {
                NavigationStack {
                    TerritoriesView()
                }
            }

            Tab("brothers.title", systemImage: "person.3.fill") {
                NavigationStack {
                    BrothersView()
                }
            }

            // Registros: solo SUPERADMIN.
            if permissionManager.canViewActionLogs {
                Tab("actionlogs.title", systemImage: "list.bullet.clipboard") {
                    NavigationStack {
                        ActionLogsView()
                    }
                }
            }

            Tab("settings.title", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .systemNotification(notificationContext)
        .onChange(of: toastManager.pendingMessage) { _, newValue in
            guard let message = newValue else { return }
            // Haptic acorde al estilo del mensaje.
            switch message.style {
            case .success: HapticManager.shared.notification(type: .success)
            case .error:   HapticManager.shared.notification(type: .error)
            case .warning: HapticManager.shared.notification(type: .warning)
            case .info:    HapticManager.shared.impact(style: .light)
            }

            notificationContext.present {
                SystemNotificationMessage(
                    icon: Image(systemName: message.style.icon)
                        .font(.title2)
                        .foregroundStyle(message.style.color),
                    title: nil,
                    text: LocalizedStringKey(message.message)
                )
            }

            toastManager.clearPending()
        }
    }
}
