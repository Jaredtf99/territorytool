import SwiftUI

struct TerritoriesView: View {
    @StateObject private var viewModel = DIContainer.shared.makeTerritoriesViewModel()
    @StateObject private var locationService = TerritoryLocationService()
    @ObservedObject private var router = AppRouter.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showAddSheet = false
    @State private var territoryToEdit: Territory?
    @State private var territoryToDelete: Territory?
    @State private var showDeleteConfirmation = false
    @State private var controlsHeight: CGFloat = 0
    @State private var isMapFullscreen = false

    var body: some View {
        ZStack(alignment: .top) {
            content
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.985)))

            if !isMapFullscreen {
                controlsLayer
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background { LiquidBackgroundView() }
        .navigationTitle("territories.title")
        .navigationBarTitleDisplayMode(.inline)
        // Toolbar nativa siempre visible, salvo en pantalla completa del mapa, donde la
        // ocultamos junto con la tab bar y la barra de estado para una vista inmersiva.
        .toolbar(isMapFullscreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(isMapFullscreen ? .hidden : .automatic, for: .tabBar)
        .statusBarHidden(isMapFullscreen)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CongregationSwitcher()
            }

            ToolbarItem(placement: .principal) {
                Text("territories.title")
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
            }

            if permissionManager.canManageTerritories {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.selection()
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("territory.add.title"))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTerritoryView()
                .onDisappear { viewModel.reload() }
        }
        .sheet(item: $territoryToEdit) { territory in
            EditTerritoryView(territory: territory, apiService: DIContainer.shared.apiService)
                .onDisappear { viewModel.reload() }
        }
        .alert("territory.detail.delete_confirmation_title", isPresented: $showDeleteConfirmation) {
            Button("territory.detail.delete", role: .destructive) {
                guard let territoryToDelete else { return }
                Task {
                    await viewModel.deleteTerritory(territoryToDelete)
                    HapticManager.shared.notification(type: .success)
                    ToastManager.shared.show(
                        NSLocalizedString("territory.delete.success", comment: ""),
                        style: .success,
                        undoHandle: viewModel.lastDeleteUndoHandle,
                        duration: viewModel.lastDeleteUndoHandle?.toastDuration ?? 3
                    )
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("territory.detail.delete_confirmation_message")
        }
        .task {
            if let context = router.consumeTerritoriesLaunchContext() {
                viewModel.applyLaunchContext(context)
            }
            await viewModel.loadTerritories()
        }
        .onChange(of: router.territoriesLaunchContext) { _, context in
            guard router.selectedTab == .territories, let context else { return }
            _ = router.consumeTerritoriesLaunchContext()
            viewModel.applyLaunchContext(context)
            viewModel.reload()
        }
        .onChange(of: router.selectedTab) { _, tab in
            guard tab == .territories, let context = router.consumeTerritoriesLaunchContext() else { return }
            viewModel.applyLaunchContext(context)
            viewModel.reload()
        }
    }

    private var controlsLayer: some View {
        TerritoryExplorerControls(viewModel: viewModel, locationService: locationService)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ControlsHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ControlsHeightKey.self) { controlsHeight = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.territories.isEmpty {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text("common.loading"))
        } else if let error = viewModel.errorMessage, viewModel.territories.isEmpty {
            ContentUnavailableView {
                Label("common.error", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(error)
            } actions: {
                Button("common.retry") {
                    Task { await viewModel.loadTerritories() }
                }
                .buttonStyle(.glassProminent)
                .tint(.accent)
            }
            .padding(.top, controlsHeight)
        } else if viewModel.territories.isEmpty {
            ContentUnavailableView {
                Label("territories.empty_list", systemImage: "map")
            } description: {
                if viewModel.filterStatus != .all || !viewModel.searchText.isEmpty {
                    Text("territories.empty_filtered")
                }
            } actions: {
                if viewModel.filterStatus != .all || !viewModel.searchText.isEmpty {
                    Button("territories.clear_filters") {
                        viewModel.searchText = ""
                        viewModel.filterStatus = .all
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accent)
                }
            }
            .padding(.top, controlsHeight)
        } else {
            Group {
                switch viewModel.presentation {
                case .map:
                    TerritoriesExplorerMap(
                        viewModel: viewModel,
                        locationService: locationService,
                        topInset: isMapFullscreen ? 0 : controlsHeight,
                        isFullscreen: $isMapFullscreen,
                        onAssign: openQuickAction,
                        onReturn: openQuickAction,
                        onEdit: { territoryToEdit = $0 },
                        onDelete: confirmDelete
                    )
                case .list:
                    TerritoryExplorerList(
                        viewModel: viewModel,
                        locationService: locationService,
                        topInset: controlsHeight,
                        onAssign: openQuickAction,
                        onReturn: openQuickAction,
                        onEdit: { territoryToEdit = $0 },
                        onDelete: confirmDelete
                    )
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.28), value: viewModel.presentation)
            .overlay(alignment: .top) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(AppSpacing.xs)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.top, controlsHeight + AppSpacing.sm)
                }
            }
        }
    }

    private func confirmDelete(_ territory: Territory) {
        HapticManager.shared.selection()
        territoryToDelete = territory
        showDeleteConfirmation = true
    }

    private func openQuickAction(_ territory: Territory) {
        HapticManager.shared.selection()
        router.openQuickAction(.territory(territory))
    }
}

private struct ControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
