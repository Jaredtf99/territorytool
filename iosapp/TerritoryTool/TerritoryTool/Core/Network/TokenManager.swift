import Foundation
import Security

class TokenManager {
    static let shared = TokenManager()
    private let key = "authToken"
    private let refreshKey = "authRefreshToken"
    private let userNameKey = "authUserName"
    private let roleKey = "authUserRole"
    private let activeCongregationKey = "activeCongregationId"
    private let congregationsKey = "congregationsJSON"

    // For simplicity in this demo, we use UserDefaults.
    // In production, Keychain is recommended.

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
        NotificationCenter.default.post(name: .authChanged, object: nil)
    }

    func saveRefreshToken(_ token: String?) {
        if let token {
            UserDefaults.standard.set(token, forKey: refreshKey)
        }
    }

    func getRefreshToken() -> String? {
        return UserDefaults.standard.string(forKey: refreshKey)
    }

    func saveProfile(userName: String?, role: String?) {
        if let userName {
            UserDefaults.standard.set(userName, forKey: userNameKey)
        }
        if let role {
            UserDefaults.standard.set(role, forKey: roleKey)
        }
    }

    func saveActiveCongregationId(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: activeCongregationKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeCongregationKey)
        }
    }

    func getActiveCongregationId() -> String? {
        return UserDefaults.standard.string(forKey: activeCongregationKey)
    }

    func saveCongregations(_ data: Data?) {
        if let data {
            UserDefaults.standard.set(data, forKey: congregationsKey)
        }
    }

    func getCongregationsData() -> Data? {
        return UserDefaults.standard.data(forKey: congregationsKey)
    }

    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: key)
    }

    func clearToken() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: roleKey)
        UserDefaults.standard.removeObject(forKey: activeCongregationKey)
        UserDefaults.standard.removeObject(forKey: congregationsKey)
        NotificationCenter.default.post(name: .authChanged, object: nil)
    }

    func getUserName() -> String? {
        return UserDefaults.standard.string(forKey: userNameKey)
    }

    func getUserRole() -> String? {
        return UserDefaults.standard.string(forKey: roleKey)
    }

    var isAuthenticated: Bool {
        return getToken() != nil
    }
}
