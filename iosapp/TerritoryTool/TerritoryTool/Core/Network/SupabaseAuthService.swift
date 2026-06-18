import Foundation

struct SupabaseLoginResponse: Decodable {
    let token: String
    let session: SupabaseSession
    let profile: SupabaseProfile?
    let congregations: [CongregationSummary]?
}

struct SupabaseSession: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct SupabaseProfile: Decodable {
    let id: String
    let username: String
    let role: String
    let mustChangePassword: Bool
    let isSuperadmin: Bool?
    let activeCongregationId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case mustChangePassword = "must_change_password"
        case isSuperadmin = "is_superadmin"
        case activeCongregationId = "active_congregation_id"
    }
}

struct CongregationSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case isActive = "is_active"
    }
}

// Response from the GoTrue token refresh endpoint.
private struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private init() {}

    func login(username: String, password: String) async throws -> SupabaseLoginResponse {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/functions/v1/login-with-username") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(AppConfig.supabasePublishableKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = String(data: data, encoding: .utf8) {
                throw NetworkError.serverError(message)
            }
            throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(SupabaseLoginResponse.self, from: data)
    }

    // Sets the active congregation and refreshes the JWT so the new
    // congregation_id / app_role claims take effect. Returns the new access token.
    func setActiveCongregation(_ congregationId: String) async throws -> String {
        try await callRPC(name: "set_active_congregation", body: ["p_congregation_id": congregationId])
        return try await refreshSession()
    }

    // Reloads the congregations the current user can operate in.
    func getMyCongregations() async throws -> [CongregationSummary] {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/rpc/get_my_congregations") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data)
        return try JSONDecoder().decode([CongregationSummary].self, from: data)
    }

    // Changes the signed-in user's own password via GoTrue.
    func changeOwnPassword(newPassword: String) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/auth/v1/user") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        applyAuthHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["password": newPassword])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data)
    }

    // --- Superadmin congregation management ---

    func createCongregation(name: String) async throws {
        try await callRPC(name: "create_congregation", body: ["p_name": name])
    }

    func renameCongregation(id: String, name: String) async throws {
        try await callRPC(name: "rename_congregation", body: ["p_congregation_id": id, "p_name": name])
    }

    func deleteCongregation(id: String) async throws {
        try await callRPC(name: "delete_congregation", body: ["p_congregation_id": id])
    }

    // Exchanges the stored refresh token for a fresh access token (re-runs the
    // access-token hook, picking up the updated active congregation).
    func refreshSession() async throws -> String {
        guard let refreshToken = TokenManager.shared.getRefreshToken() else {
            throw NetworkError.unauthorized
        }
        guard let url = URL(string: "\(AppConfig.supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data)
        let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
        TokenManager.shared.saveRefreshToken(refreshed.refreshToken)
        TokenManager.shared.saveToken(refreshed.accessToken)
        return refreshed.accessToken
    }

    private func callRPC(name: String, body: [String: Any]) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/rpc/\(name)") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data)
    }

    private func applyAuthHeaders(_ request: inout URLRequest) {
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        let bearer = TokenManager.shared.getToken() ?? AppConfig.supabasePublishableKey
        request.addValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }

    private static func validate(_ response: URLResponse, _ data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 { throw NetworkError.unauthorized }
            throw NetworkError.serverError(String(data: data, encoding: .utf8) ?? "Status code: \(httpResponse.statusCode)")
        }
    }
}
