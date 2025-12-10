import Foundation
import Combine
import SwiftUI

@MainActor
class UsersViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var filteredUsers: [User] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false // Start false, fetch will set true
    @Published var errorMessage: String?
    @Published var showAddSheet: Bool = false
    @Published var showEditSheet: Bool = false
    @Published var selectedUser: User?
    
    // Configurable User - logic to determine if current user can edit/delete another user
    // We need the current user's role. For now, we decode it from the token or fetch it.
    // For this MVP, we will try to decode from token if possible, or assume ADMIN if not.
    var currentUserRole: UserRole? {
        // TODO: Implement JWT decoding or fetch current user info
        // For now, attempting to decode from stored token
        guard let token = TokenManager.shared.getToken() else { return nil }
        return JWTHelper.getUserRole(from: token)
    }
    
    var currentUserName: String? {
        guard let token = TokenManager.shared.getToken() else { return nil }
        return JWTHelper.getUserName(from: token)
    }

    private let networkManager: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(networkManager: APIService = NetworkManager.shared) {
        self.networkManager = networkManager
        
        // Debounce search text
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterUsers()
            }
            .store(in: &cancellables)
            
        // Also refilter when users list changes
        $users
            .sink { [weak self] _ in
                self?.filterUsers()
            }
            .store(in: &cancellables)
    }
    
    private func filterUsers() {
        let text = searchText
        let currentUsers = users
        
        let filtered: [User]
        if text.isEmpty {
            filtered = currentUsers
        } else {
            filtered = currentUsers.filter { $0.userName.localizedCaseInsensitiveContains(text) }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.filteredUsers = filtered
        }
    }
    
    func fetchUsers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedUsers: [User] = try await networkManager.request(endpoint: TerritoryEndpoint.getUsers)
                // Sort by name
                self.users = fetchedUsers.sorted { $0.userName < $1.userName }
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func addUser(name: String, role: UserRole, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await networkManager.request(endpoint: TerritoryEndpoint.addUser(name: name, role: role.rawValue, password: password))
            ToastManager.shared.show("users.add_success", style: .success)
            fetchUsers()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            ToastManager.shared.show(error.localizedDescription, style: .error)
            self.isLoading = false
            return false
        }
    }
    
    func updateUser(user: User, newName: String, newRole: UserRole) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await networkManager.request(endpoint: TerritoryEndpoint.updateUser(id: user.id, name: newName, role: newRole.rawValue))
            ToastManager.shared.show("users.update_success", style: .success)
            fetchUsers()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            ToastManager.shared.show(error.localizedDescription, style: .error)
            self.isLoading = false
            return false
        }
    }
    
    func changePassword(for user: User, newPassword: String) async -> Bool {
         isLoading = true
         errorMessage = nil
         
         do {
             try await networkManager.request(endpoint: TerritoryEndpoint.changeUserPassword(id: user.id, newPassword: newPassword))
             ToastManager.shared.show("users.change_password_success", style: .success)
             self.isLoading = false
             return true
         } catch {
             self.errorMessage = error.localizedDescription
             ToastManager.shared.show(error.localizedDescription, style: .error)
             self.isLoading = false
             return false
         }
    }

    func deleteUser(user: User) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await networkManager.request(endpoint: TerritoryEndpoint.deleteUser(id: user.id))
            ToastManager.shared.show("users.delete_success", style: .success)
            fetchUsers()
        } catch {
             self.errorMessage = error.localizedDescription
             ToastManager.shared.show(error.localizedDescription, style: .error)
             self.isLoading = false
        }
    }
    
    // MARK: - Permission Logic
    
    func canEdit(user: User) -> Bool {
        guard let currentRole = currentUserRole else { return false }
        
        // SUPERADMIN cannot be edited by anyone (except maybe themselves, but requirement says "Nadie puede gestionar SUPERADMIN")
        // Docs: "SUPERADMIN nunca puede ser configurado"
        if user.role == .superAdmin {
            return false
        }
        
        switch currentRole {
        case .superAdmin:
            return true
        case .admin:
            return user.role == .user
        case .user:
            return false
        }
    }
    
    func canDelete(user: User) -> Bool {
        return canEdit(user: user) 
    }
    
    func canChangePassword(for targetUser: User) -> Bool {
        // Logic from docs:
        // SUPERADMIN can change ADMIN and USER
        // ADMIN can change USER
        return canEdit(user: targetUser)
    }
    
    func availableRolesForAssignment() -> [UserRole] {
        guard let currentRole = currentUserRole else { return [] }
        switch currentRole {
        case .superAdmin:
            return [.admin, .user]
        case .admin:
            return [.user]
        case .user:
            return []
        }
    }
}
