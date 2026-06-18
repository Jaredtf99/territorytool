import SwiftUI

struct UsersView: View {
    @StateObject private var viewModel = DIContainer.shared.makeUsersViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var userToDelete: User?

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if let error = viewModel.errorMessage, viewModel.users.isEmpty {
                ContentUnavailableView {
                    Label("common.error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(error)
                } actions: {
                    Button("common.retry") {
                        Task { await viewModel.fetchUsers() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if viewModel.filteredUsers.isEmpty {
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
                ForEach(viewModel.filteredUsers) { user in
                    userRowView(for: user)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.fetchUsers()
            HapticManager.shared.notification(type: .success)
        }
        .navigationTitle("users.title")
        .navigationBarTitleDisplayMode(.large)
        // Título .large: la barra de búsqueda queda fija bajo el título y no
        // compite con el gesto de pull-to-refresh (igual que en Territorios).
        .searchable(text: $viewModel.searchText, placement: .automatic, prompt: "users.search_placeholder")
        .toolbar {
            ToolbarItem() {
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .background {
            LiquidBackgroundView()
        }
        .sheet(isPresented: $viewModel.showAddSheet, onDismiss: {
            // Refresh when add sheet is dismissed (saved or cancelled)
            Task { await viewModel.fetchUsers() }
        }) {
            AddEditUserView(viewModel: viewModel, mode: .add)
        }
        .sheet(isPresented: $viewModel.showEditSheet, onDismiss: {
            // Refresh when edit sheet is dismissed
            Task { await viewModel.fetchUsers() }
        }) {
            if let user = viewModel.selectedUser {
                AddEditUserView(viewModel: viewModel, mode: .edit(user))
            }
        }
        .alert("common.delete_confirmation", isPresented: $showingDeleteConfirmation) {
            Button("common.delete", role: .destructive) {
                if let user = userToDelete {
                    Task {
                        await viewModel.deleteUser(user: user)
                    }
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .task {
            await viewModel.fetchUsers()
        }
    }
    
    @ViewBuilder
    private func userRowView(for user: User) -> some View {
        UserRow(user: user, canEdit: viewModel.canEdit(user: user))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .onTapGesture {
                if viewModel.canEdit(user: user) {
                    HapticManager.shared.selection()
                    viewModel.selectedUser = user
                    viewModel.showEditSheet = true
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if viewModel.canDelete(user: user) {
                    Button {
                        HapticManager.shared.selection()
                        userToDelete = user
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.danger)
                }

                if viewModel.canEdit(user: user) {
                    Button {
                        HapticManager.shared.selection()
                        viewModel.selectedUser = user
                        viewModel.showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(.accent)
                }
            }
    }
}
