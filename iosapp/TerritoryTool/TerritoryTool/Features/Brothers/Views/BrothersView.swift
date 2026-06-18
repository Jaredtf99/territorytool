import SwiftUI


struct BrothersView: View {
    @StateObject private var viewModel = DIContainer.shared.makeBrothersViewModel()
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var brotherToDelete: Person?

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.brothers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if let error = viewModel.errorMessage, viewModel.brothers.isEmpty {
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(error)
                } actions: {
                    Button("common.retry") {
                        Task { await viewModel.fetchBrothers() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if viewModel.filteredBrothers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("common.no_results")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredBrothers) { brother in
                    BrotherRowView(
                        person: brother,
                        onEdit: {
                            HapticManager.shared.selection()
                            viewModel.selectedBrother = brother
                            viewModel.showEditSheet = true
                        },
                        onDelete: {
                            HapticManager.shared.selection()
                            brotherToDelete = brother
                            showingDeleteConfirmation = true
                        },
                        isExpanded: Binding(
                            get: { viewModel.isExpanded(brother.id) },
                            set: { _ in
                                viewModel.toggleExpanded(brother.id)
                            }
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Only show edit/delete swipe actions for ADMIN+ roles
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
                                HapticManager.shared.selection()
                                viewModel.selectedBrother = brother
                                viewModel.showEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .tint(.accent)
                        }
                    }
                }
                .opacity(viewModel.isLoading ? 0.5 : 1.0)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.expandedBrotherIds)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.filteredBrothers)
        .refreshable {
            await viewModel.fetchBrothers()
            HapticManager.shared.notification(type: .success)
        }
        .navigationTitle("brothers.title")
        .navigationBarTitleDisplayMode(.large)
        // Título .large: la barra de búsqueda queda fija bajo el título y no
        // compite con el gesto de pull-to-refresh (igual que en Territorios).
        .searchable(text: $viewModel.searchText, placement: .automatic, prompt: "brothers.search_placeholder")
        .toolbar {
            // Only show add button for ADMIN+ roles
            if permissionManager.canManageBrothers {
                ToolbarItem() {
                    Button(action: {
                        HapticManager.shared.selection()
                        viewModel.showAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .background {
            LiquidBackgroundView()
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
        .task {
            await viewModel.fetchBrothers()
        }
    }
}
