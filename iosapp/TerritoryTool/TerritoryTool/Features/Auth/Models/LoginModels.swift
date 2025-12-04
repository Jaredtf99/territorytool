import Foundation

struct LoginCredentials: Codable {
    let userName: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
}
