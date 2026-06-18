import SwiftUI

/// Acciones rápidas accesibles desde el botón (+) de Territorios.
enum TerritoryQuickAction: Int, Identifiable {
    case assign
    case returnTerritory
    var id: Int { rawValue }
}

struct TerritoriesView: View {
    @StateObject private var viewModel = DIContainer.shared.makeTerritoriesViewModel()
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var showAddSheet = false
    @State private var territoryToEdit: Territory?
    @State private var territoryToDelete: Territory?
    @State private var showDeleteConfirmation = false
    @State private var quickAction: TerritoryQuickAction?

    init() {}
    
    var body: some View {
        List {
            // Filters
            FilterScrollView(viewModel: viewModel)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .padding(.vertical, 8)
                .padding(.horizontal, 16) // Add padding back

            // Content
            if viewModel.isLoading && viewModel.territories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text(error)
                        .foregroundColor(.error)
                        .padding()
                        .multilineTextAlignment(.center)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    Button("common.retry") {
                        Task { await viewModel.loadTerritories() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if viewModel.territories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("territories.empty_list")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.territories) { territory in
                    ZStack {
                        NavigationLink(destination: TerritoryDetailView(territoryId: territory.id, territoryName: territory.name)) {
                           EmptyView() 
                        }
                        .opacity(0)
                        
                        TerritoryCard(territory: territory)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Only show edit/delete swipe actions for ADMIN+ roles
                        if permissionManager.canManageTerritories {
                            Button {
                                HapticManager.shared.selection()
                                territoryToDelete = territory
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.danger)

                            Button {
                                HapticManager.shared.selection()
                                territoryToEdit = territory
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .tint(.accent)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.territories)
        .refreshable {
            await viewModel.loadTerritories()
            HapticManager.shared.notification(type: .success)
        }
        .navigationTitle("territories.title")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, placement: .automatic, prompt: "territories.search_placeholder")
        .toolbar {
            ToolbarItem() {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(TerritorySortOption.allCases) { option in
                            Text(option.localizedName).tag(option)
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { 
                        HapticManager.shared.selection()
                        viewModel.sortAscending.toggle() 
                    }) {
                        Label(
                            viewModel.sortAscending ? "territories.sort.ascending" : "territories.sort.descending",
                            systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            
            ToolbarSpacer(.flexible)
            
            // Acciones rápidas: Asignar/Devolver para todos; Añadir solo ADMIN+.
            ToolbarItem() {
                Menu {
                    Button {
                        HapticManager.shared.selection()
                        quickAction = .assign
                    } label: {
                        Label("assignment.title", systemImage: "person.badge.plus")
                    }
                    Button {
                        HapticManager.shared.selection()
                        quickAction = .returnTerritory
                    } label: {
                        Label("return.title", systemImage: "tray.and.arrow.down")
                    }
                    if permissionManager.canManageTerritories {
                        Divider()
                        Button {
                            HapticManager.shared.selection()
                            showAddSheet = true
                        } label: {
                            Label("territory.add.title", systemImage: "plus")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(item: $quickAction) { action in
            switch action {
            case .assign:
                TerritoryAssignmentView()
            case .returnTerritory:
                TerritoryReturnView()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTerritoryView()
                .onDisappear {
                    Task {
                        await viewModel.loadTerritories()
                    }
                }
        }
        .sheet(item: $territoryToEdit) { territory in
            EditTerritoryView(territory: territory, apiService: DIContainer.shared.apiService)
                .onDisappear {
                    Task {
                        await viewModel.loadTerritories()
                    }
                }
        }
        .alert("territory.detail.delete_confirmation_title", isPresented: $showDeleteConfirmation) {
            Button("territory.detail.delete", role: .destructive) {
                if let territory = territoryToDelete {
                    Task {
                        await viewModel.deleteTerritory(territory)
                        HapticManager.shared.notification(type: .success)
                        ToastManager.shared.show(NSLocalizedString("territory.delete.success", value: "Territory deleted", comment: ""), style: .success)
                    }
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("territory.detail.delete_confirmation_message")
        }
        .background {
            LiquidBackgroundView()
        }
        .task {
            await viewModel.loadTerritories()
        }
    }
}

struct FilterScrollView: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TerritoryFilter.allCases) { filter in
                    let isSelected = viewModel.filterStatus == filter
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.filterStatus = filter
                        }
                    }) {
                        Text(filter.localizedName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                    }
                    .glassEffect(
                        isSelected ? .regular.tint(.accent).interactive() : .regular.interactive(),
                        in: .capsule
                    )
                }
            }
            
        }
    }
}
