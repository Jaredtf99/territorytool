import SwiftUI

struct UserRow: View {
    let user: User
    let canEdit: Bool
    
    var body: some View {
        HStack {
            Text(user.userName)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            RoleBadge(role: user.role)
        }
        .padding()
        .glassCardStyle(cornerRadius: 12, padding: 0)
        .contentShape(Rectangle()) // Make full row tappable
    }
}

struct RoleBadge: View {
    let role: UserRole
    
    var body: some View {
        Text(role.rawValue) // Will localize rawValue later or map it
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(8)
    }
    
    var backgroundColor: Color {
        switch role {
        case .superAdmin: return .red
        case .admin: return .orange
        case .user: return .blue
        }
    }
}
