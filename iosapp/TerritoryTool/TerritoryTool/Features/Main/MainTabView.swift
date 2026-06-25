import SwiftUI

/// Navegación raíz: 5 tabs como máximo (iOS oculta el resto en "More").
/// Asignar/Devolver son acciones contextuales (botón + en Territorios y detalle),
/// Usuarios vive dentro de Ajustes. Ver docs/DESIGN_GUIDE.md §6.
struct MainTabView: View {
    @ObservedObject private var toastManager = ToastManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @StateObject private var router = AppRouter.shared
    @State private var visibleToast: ToastMessage?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var isUndoingToast = false

    /// Variante rellena del símbolo solo cuando la pestaña está activa.
    private func icon(_ base: String, _ tab: AppTab) -> String {
        router.selectedTab == tab ? "\(base).fill" : base
    }

    var body: some View {
        ZStack {
            tabs

            // Acción rápida a pantalla completa (cubre la tab bar real) con entrada
            // tipo zoom. No es una hoja: es una vista normal superpuesta.
            if router.isQuickActionPresented {
                QuickActionHubView(onClose: { router.isQuickActionPresented = false })
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: router.isQuickActionPresented)
        .overlay(alignment: .bottom) {
            toastOverlay
        }
        .animation(.bouncy, value: visibleToast)
        .onChange(of: toastManager.pendingMessage) { _, newValue in
            guard let message = newValue else { return }
            presentToast(message)
        }
        .onDisappear {
            toastDismissTask?.cancel()
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let visibleToast {
            ToastGlassMessageView(
                message: visibleToast,
                isUndoing: isUndoingToast,
                onUndo: visibleToast.undoHandle.map { _ in { undoVisibleToast() } }
            )
                .id(visibleToast.transitionKey)
                .padding(.horizontal, 20)
                .padding(.bottom, 64)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.97, anchor: .bottom))
                    )
                )
                .zIndex(2)
        }
    }

    private var tabs: some View {
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
            // No navegamos a la pestaña; volvemos a la anterior y abrimos la Acción rápida.
            router.selectedTab = oldValue == .quickAction ? .dashboard : oldValue
            router.isQuickActionPresented = true
        }
    }

    private func presentToast(_ message: ToastMessage) {
        // Haptic acorde al estilo del mensaje.
        switch message.style {
        case .success: HapticManager.shared.notification(type: .success)
        case .error:   HapticManager.shared.notification(type: .error)
        case .warning: HapticManager.shared.notification(type: .warning)
        case .info:    HapticManager.shared.impact(style: .light)
        }

        toastDismissTask?.cancel()
        withAnimation(.snappy(duration: 0.22)) {
            isUndoingToast = false
            visibleToast = message
        }
        toastManager.clearPending()

        toastDismissTask = Task {
            let seconds = max(message.undoHandle?.expiresAt.timeIntervalSinceNow ?? message.duration, 0.1)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard visibleToast == message else { return }
                withAnimation(.snappy(duration: 0.18)) {
                    visibleToast = nil
                }
            }
        }
    }

    private func undoVisibleToast() {
        guard let handle = visibleToast?.undoHandle, !isUndoingToast else { return }
        withAnimation(.snappy(duration: 0.18)) {
            isUndoingToast = true
        }
        toastDismissTask?.cancel()

        Task {
            do {
                switch handle.kind {
                case .domain:
                    try await NetworkManager.shared.request(endpoint: TerritoryEndpoint.undoAction(id: handle.id))
                case .user:
                    try await NetworkManager.shared.request(endpoint: TerritoryEndpoint.undoUserAction(id: handle.id))
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
                    if handle.kind == .user {
                        NotificationCenter.default.post(name: .userDataChanged, object: nil)
                    }
                    withAnimation(.snappy(duration: 0.16)) {
                        visibleToast = nil
                        isUndoingToast = false
                    }
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    ToastManager.shared.show("undo.success", style: .success)
                }
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
                    if handle.kind == .user {
                        NotificationCenter.default.post(name: .userDataChanged, object: nil)
                    }
                    let message = error.localizedDescription.localizedCaseInsensitiveContains("UNDO_EXPIRED")
                        ? "undo.expired"
                        : "undo.failed"
                    withAnimation(.snappy(duration: 0.16)) {
                        visibleToast = nil
                        isUndoingToast = false
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await MainActor.run {
                            ToastManager.shared.show(message, style: .error)
                        }
                    }
                }
            }
        }
    }
}
