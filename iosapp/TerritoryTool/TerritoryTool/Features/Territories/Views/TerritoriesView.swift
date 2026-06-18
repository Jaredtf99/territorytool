import SwiftUI

private enum TerritoryExplorerFlow: Identifiable, Hashable {
    case assign(Territory)
    case returnTerritory(Territory)

    var id: String {
        switch self {
        case .assign(let territory): "assign-\(territory.id)"
        case .returnTerritory(let territory): "return-\(territory.id)"
        }
    }

    static func == (lhs: TerritoryExplorerFlow, rhs: TerritoryExplorerFlow) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

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
    @State private var flow: TerritoryExplorerFlow?
    @State private var controlsHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            content
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.985)))

            controlsLayer
        }
        .background { LiquidBackgroundView() }
        .navigationTitle("territories.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        .navigationDestination(item: $flow) { destination in
            switch destination {
            case .assign(let territory):
                TerritoryAssignmentView(territory: territory) {
                    flow = nil
                    viewModel.reload()
                }
            case .returnTerritory(let territory):
                TerritoryReturnView(territory: territory) {
                    flow = nil
                    viewModel.reload()
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
                        style: .success
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
            .background(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: Color.appBackground.opacity(0.55), location: 0.0),
                        .init(color: Color.appBackground.opacity(0.85), location: 0.28),
                        .init(color: Color.appBackground.opacity(0.85), location: 0.6),
                        .init(color: Color.appBackground.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .padding(.bottom, -36)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
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
                        topInset: controlsHeight,
                        onAssign: { flow = .assign($0) },
                        onReturn: { flow = .returnTerritory($0) },
                        onEdit: { territoryToEdit = $0 },
                        onDelete: confirmDelete
                    )
                case .list:
                    TerritoryExplorerList(
                        viewModel: viewModel,
                        locationService: locationService,
                        topInset: controlsHeight + 48,
                        onAssign: { flow = .assign($0) },
                        onReturn: { flow = .returnTerritory($0) },
                        onEdit: { territoryToEdit = $0 },
                        onDelete: confirmDelete
                    )
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.28), value: viewModel.presentation)
            .overlay(alignment: .topTrailing) {
                PresentationToggle(viewModel: viewModel)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, controlsHeight + AppSpacing.xs)
                    .zIndex(10)
            }
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
}

private struct ControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
