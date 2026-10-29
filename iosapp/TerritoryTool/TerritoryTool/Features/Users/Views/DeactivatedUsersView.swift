import SwiftUI

struct DeactivatedUsersView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UsersViewModel
    @State private var reactivatingUserId: String?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoadingDeactivated && viewModel.deactivatedUsers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if let error = viewModel.deactivatedErrorMessage, viewModel.deactivatedUsers.isEmpty {
                    ContentUnavailableView {
                        Label("common.error", systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("common.retry") {
                            Task { await viewModel.fetchDeactivatedUsers() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if viewModel.deactivatedUsers.isEmpty {
                    ContentUnavailableView(
                        "users.deactivated_empty",
                        systemImage: "person.crop.circle.badge.checkmark",
                        description: Text("users.deactivated_info")
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(viewModel.deactivatedUsers) { user in
                            deactivatedRow(for: user)
                        }
                    } footer: {
                        Text("users.deactivated_info")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                await viewModel.fetchDeactivatedUsers()
            }
            .background {
                LiquidBackgroundView()
                    .ignoresSafeArea()
            }
            .navigationTitle("users.deactivated_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "multiply")
                    }
                }
            }
            .task {
                await viewModel.fetchDeactivatedUsers()
            }
        }
    }

    @ViewBuilder
    private func deactivatedRow(for user: User) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(user.userName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                RoleBadge(role: user.role)
            }

            Spacer()

            if reactivatingUserId == user.id {
                ProgressView()
            } else {
                Button("users.reactivate") {
                    HapticManager.shared.selection()
                    reactivatingUserId = user.id
                    Task {
                        await viewModel.reactivateUser(user: user)
                        reactivatingUserId = nil
                    }
                }
                .buttonStyle(.bordered)
                .tint(.accent)
                .disabled(reactivatingUserId != nil)
            }
        }
        .padding()
        .glassCardStyle(cornerRadius: 12, padding: 0)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}
