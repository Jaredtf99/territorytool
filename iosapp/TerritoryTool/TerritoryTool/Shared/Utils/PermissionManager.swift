//
//  PermissionManager.swift
//  TerritoryTool
//
//  Permission manager for role-based UI visibility
//

import Foundation
import SwiftUI
import Combine

/// Centralized permission manager that checks user role from JWT token
/// and provides computed properties for permission checks
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    private init() {}
    
    /// Current user's role extracted from JWT token
    var currentUserRole: UserRole? {
        guard let token = TokenManager.shared.getToken() else { return nil }
        return JWTHelper.getUserRole(from: token)
    }
    
    /// Returns true if user is authenticated (has a valid role)
    var isAuthenticated: Bool {
        currentUserRole != nil
    }
    
    /// Returns true if user has ADMIN or SUPERADMIN role
    var isAdminOrHigher: Bool {
        guard let role = currentUserRole else { return false }
        return role == .superAdmin || role == .admin
    }
    
    // MARK: - Territory Permissions
    
    /// Can add/edit/delete territories (ADMIN+)
    var canManageTerritories: Bool {
        isAdminOrHigher
    }
    
    /// Can refresh territory image (ADMIN+)
    var canRefreshTerritoryImage: Bool {
        isAdminOrHigher
    }
    
    // MARK: - Brothers (Persons) Permissions
    
    /// Can add/edit/delete brothers (ADMIN+)
    var canManageBrothers: Bool {
        isAdminOrHigher
    }
    
    // MARK: - Users Permissions
    
    /// Can view/manage users (ADMIN+)
    var canManageUsers: Bool {
        isAdminOrHigher
    }
    
    // MARK: - Action Logs Permissions
    
    /// Can view action logs (SUPERADMIN only)
    var canViewActionLogs: Bool {
        currentUserRole == .superAdmin
    }
}
