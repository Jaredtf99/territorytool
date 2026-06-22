import SwiftUI
import SystemNotification

/// Navegación raíz: 5 tabs como máximo (iOS oculta el resto en "More").
/// Asignar/Devolver son acciones contextuales (botón + en Territorios y detalle),
/// Usuarios vive dentro de Ajustes. Ver docs/DESIGN_GUIDE.md §6.
struct MainTabView: View {
    @ObservedObject private var toastManager = ToastManager.shared
    @StateObject private var notificationContext = SystemNotificationContext()
    @ObservedObject private var permissionManager = PermissionManager.shared
    @StateObject private var router = AppRouter.shared

    /// Variante rellena del símbolo solo cuando la pestaña está activa.
    private func icon(_ base: String, _ tab: AppTab) -> String {
        router.selectedTab == tab ? "\(base).fill" : base
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("dashboard.title", systemImage: icon("house", .dashboard), value: AppTab.dashboard) {
                NavigationStack(path: $router.dashboardPath) {
                    DashboardView()
                }
            }

            Tab("territories.title", systemImage: icon("map", .territories), value: AppTab.territories) {
                NavigationStack(path: $router.territoriesPath) {
                    TerritoriesView()
                }
            }

            Tab("brothers.title", systemImage: icon("person.3", .brothers), value: AppTab.brothers) {
                NavigationStack(path: $router.brothersPath) {
                    BrothersView()
                }
            }

            // Registros: solo SUPERADMIN.
            if permissionManager.canViewActionLogs {
                Tab("tab.logs", systemImage: icon("list.bullet.clipboard", .actionLogs), value: AppTab.actionLogs) {
                    NavigationStack(path: $router.actionLogsPath) {
                        ActionLogsView()
                    }
                }
            }

            // Acción rápida: pestaña de rol .search (iOS 26) — separada a la derecha,
            // siempre visible. No abre contenido: dispara la hoja de Acción rápida.
            // Título vacío -> solo icono (la tab bar ignora labelStyle, así que es la
            // forma fiable de ocultar el texto). El tinte verde oscuro viene de .tint.
            Tab("", systemImage: "qrcode.viewfinder", value: AppTab.quickAction, role: .search) {
                Color.clear
            }
        }
        .tint(.accentDeep)
        .tabBarMinimizeBehavior(.never)
        // iOS 27 dejó de aplicar el desenfoque progresivo por defecto en la navigation bar;
        // lo forzamos con el estilo "soft" del scroll edge effect en el borde superior.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onChange(of: router.selectedTab) { oldValue, newValue in
            guard newValue == .quickAction else { return }
            // No navegamos a la pestaña; volvemos a la anterior y presentamos la hoja.
            router.selectedTab = oldValue == .quickAction ? .dashboard : oldValue
            router.isQuickActionPresented = true
        }
        .sheet(isPresented: $router.isQuickActionPresented) {
            QuickActionHubView()
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
