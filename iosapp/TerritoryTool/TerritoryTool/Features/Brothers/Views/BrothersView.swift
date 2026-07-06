import SwiftUI

/// Explorador de Hermanos: búsqueda + chips de filtro fijos arriba, tarjeta
/// resumen y lista agrupada por estado operativo (disponibles para recibir,
/// con territorios, inactivos). "Entregar" abre la Acción rápida con la
/// persona ya resuelta.
private struct BrotherTerritoryRoute: Hashable {
    let id: Int
    let name: String
}

struct BrothersView: View {
    @StateObject private var viewModel: BrothersViewModel
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var router = AppRouter.shared
    @State private var showingDeleteConfirmation = false
    @State private var brotherToDelete: Person?
    @State private var territoryRoute: BrotherTerritoryRoute?

    /// Inyectable para previews/capturas con datos mock.
    init(viewModel: BrothersViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? DIContainer.shared.makeBrothersViewModel())
    }

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                BrothersControls(viewModel: viewModel)
            }
            .background { LiquidBackgroundView() }
            .navigationTitle("brothers.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CongregationSwitcher()
                }

                ToolbarItem(placement: .principal) {
                    Text("brothers.title")
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                }

                if permissionManager.canManageBrothers {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticManager.shared.selection()
                            viewModel.showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("brothers.add.title"))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddBrotherView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showEditSheet) {
                if let brother = viewModel.selectedBrother {
                    EditBrotherView(viewModel: viewModel, person: brother)
                }
            }
            .alert("brothers.delete_confirmation", isPresented: $showingDeleteConfirmation) {
                Button("brothers.delete", role: .destructive) {
                    if let brother = brotherToDelete {
                        Task {
                            await viewModel.deleteBrother(person: brother)
                        }
                    }
                }
                Button("common.cancel", role: .cancel) {}
            }
            .navigationDestination(item: $territoryRoute) { route in
                TerritoryDetailView(territoryId: route.id, territoryName: route.name)
            }
            .task {
                await viewModel.fetchBrothers()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.brothers.isEmpty {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text("common.loading"))
        } else if let error = viewModel.errorMessage, viewModel.brothers.isEmpty {
            ContentUnavailableView {
                Label("common.error", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(error)
            } actions: {
                Button("common.retry") {
                    Task { await viewModel.fetchBrothers() }
                }
                .buttonStyle(.glassProminent)
                .tint(.accent)
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if viewModel.filter == .all && !viewModel.brothers.isEmpty {
                BrothersSummaryCard(
                    holderCount: viewModel.summaryHolderCount,
                    enabledCount: viewModel.enabledCount,
                    assignmentDays: viewModel.summaryAssignmentDays
                )
                .appear(index: 0)
                .listRowStyleCarto(top: 0, bottom: AppSpacing.sm)
            }

            if viewModel.displayBrothers.isEmpty {
                emptyState
                    .listRowStyleCarto(top: AppSpacing.lg)
            } else {
                ForEach(viewModel.displayBrothers) { brother in
                    row(brother)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, AppSpacing.xl, for: .scrollContent)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.filter)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.searchText)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.sortOption)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.sortAscending)
        .animation(.spring(response: 0.4, dampingFraction: 0.84), value: viewModel.brothers)
        .refreshable {
            await viewModel.fetchBrothers()
            HapticManager.shared.notification(type: .success)
        }
    }

    private func row(_ brother: Person) -> some View {
        BrotherCard(
            person: brother,
            isExpanded: viewModel.isExpanded(brother.id),
            onToggle: { viewModel.toggleExpanded(brother.id) },
            onGive: { give(brother) },
            geometry: { viewModel.territoryGeometries[$0] },
            imageURL: { viewModel.territoryImageURLs[$0] },
            onOpenTerritory: {
                territoryRoute = BrotherTerritoryRoute(id: $0.territoryId, name: $0.territoryName)
            }
        )
        .listRowStyleCarto()
        .opacity(viewModel.isLoading ? 0.5 : 1)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if brother.enabled {
                Button {
                    give(brother)
                } label: {
                    Label("brothers.give", systemImage: "paperplane.fill")
                }
                .tint(.accent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Editar/eliminar solo para roles ADMIN+.
            if permissionManager.canManageBrothers {
                Button {
                    HapticManager.shared.selection()
                    brotherToDelete = brother
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.danger)

                Button {
                    edit(brother)
                } label: {
                    Image(systemName: "pencil")
                }
                .tint(.accent)
            }
        }
        .contextMenu {
            if brother.enabled {
                Button {
                    give(brother)
                } label: {
                    Label("brothers.give", systemImage: "paperplane.fill")
                }
            }
            if permissionManager.canManageBrothers {
                Button {
                    edit(brother)
                } label: {
                    Label("brothers.edit.title", systemImage: "pencil")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            CartoEmptyState(
                systemImage: "person.2.slash",
                message: "brothers.empty_filtered"
            )
            if viewModel.filter != .all || !viewModel.searchText.isEmpty {
                Button("brothers.clear_filters") {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.searchText = ""
                        viewModel.filter = .all
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(.accent)
            }
        }
    }

    private func give(_ brother: Person) {
        HapticManager.shared.impact(style: .medium)
        router.openQuickAction(.person(brother))
    }

    private func edit(_ brother: Person) {
        HapticManager.shared.selection()
        viewModel.selectedBrother = brother
        viewModel.showEditSheet = true
    }
}

private extension View {
    /// Estilo común de fila: sin fondo ni separador, con los márgenes del tema.
    func listRowStyleCarto(top: CGFloat = AppSpacing.xxs, bottom: CGFloat = AppSpacing.xxs) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: AppSpacing.md, bottom: bottom, trailing: AppSpacing.md))
    }
}
