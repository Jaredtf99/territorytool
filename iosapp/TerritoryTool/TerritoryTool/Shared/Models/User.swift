import Foundation

struct User: Codable, Identifiable {
    // API returns "userID"
    let id: String
    let userName: String
    let role: UserRole
    
    enum CodingKeys: String, CodingKey {
        case id = "userID"
        case userName
        case role
    }
}

enum UserRole: String, Codable {
    case superAdmin = "SUPERADMIN"
    case admin = "ADMIN"
    case user = "USER"
}
