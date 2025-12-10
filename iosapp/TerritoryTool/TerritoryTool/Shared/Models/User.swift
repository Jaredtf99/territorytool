import Foundation

struct User: Codable, Identifiable {
    // API returns "userID"
    let id: String
    let userName: String
    let role: UserRole
    
    enum CodingKeys: String, CodingKey {
        case id = "UserID"
        case userName = "UserName"
        case role = "Role"
    }
}

enum UserRole: String, Codable {
    case superAdmin = "SUPERADMIN"
    case admin = "ADMIN"
    case user = "USER"
}
