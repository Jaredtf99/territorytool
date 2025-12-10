import SwiftUI

struct UsersView: View {
    @StateObject private var viewModel = DIContainer.shared.makeUsersViewModel()
    @State private var showingAddSheet = false
    @State private var isSearching = false
    @State private var showingDeleteConfirmation = false
    @State private var userToDelete: User?
    @Environment(\.isSearching) private var envIsSearching
    
    var body: some View {
        List {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView()
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
            viewModel.fetchUsers()
        }
        .navigationTitle("users.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, isPresented: $isSearching, prompt: "users.search_placeholder")
        .toolbar {
            ToolbarItem() {
                Button {
                    isSearching.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            
            ToolbarSpacer(.flexible)
            
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
            viewModel.fetchUsers()
        }) {
            AddEditUserView(viewModel: viewModel, mode: .add)
        }
        .sheet(isPresented: $viewModel.showEditSheet, onDismiss: {
            // Refresh when edit sheet is dismissed
            viewModel.fetchUsers()
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
                        await viewModel.fetchUsers() 
                    }
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .task {
            if viewModel.users.isEmpty {
                viewModel.fetchUsers()
            }
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
                    .tint(.red)
                }
                
                if viewModel.canEdit(user: user) {
                    Button {
                        HapticManager.shared.selection()
                        viewModel.selectedUser = user
                        viewModel.showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(.brandPrimary)
                }
            }
    }
}
