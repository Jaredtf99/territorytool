import Foundation
import Security

/// `nonisolated` a propósito: el target compila con
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, así que sin esto quedaría aislado al actor
/// principal y el transporte de red no podría leer el token sin saltar a main en cada
/// petición. Es seguro porque todo el estado vive en `UserDefaults`, que es thread-safe;
/// la clase no tiene estado mutable propio.
nonisolated final class TokenManager: Sendable {
    static let shared = TokenManager()
    private let key = "authToken"
    private let refreshKey = "authRefreshToken"
    private let userNameKey = "authUserName"
    private let roleKey = "authUserRole"
    private let activeCongregationKey = "activeCongregationId"
    private let congregationsKey = "congregationsJSON"

    // For simplicity in this demo, we use UserDefaults.
    // In production, Keychain is recommended.

    /// Persiste la sesión completa y **después** publica un único `.authChanged`.
    ///
    /// Antes el login guardaba token, refresh, perfil y congregación por separado, y
    /// `saveToken` publicaba la notificación en el primer paso: un observador podía
    /// despertar, leer el token nuevo y encontrarse el nombre de usuario o la congregación
    /// activa todavía sin escribir.
    func saveSession(
        token: String,
        refreshToken: String?,
        userName: String?,
        role: String?,
        activeCongregationId: String?,
        congregations: Data?
    ) {
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: key)
        if let refreshToken { defaults.set(refreshToken, forKey: refreshKey) }
        if let userName { defaults.set(userName, forKey: userNameKey) }
        if let role { defaults.set(role, forKey: roleKey) }
        if let activeCongregationId {
            defaults.set(activeCongregationId, forKey: activeCongregationKey)
        } else {
            defaults.removeObject(forKey: activeCongregationKey)
        }
        if let congregations { defaults.set(congregations, forKey: congregationsKey) }

        postAuthChanged()
    }

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
        postAuthChanged()
    }

    /// Los observadores de `.authChanged` son de UI (`ContentView`, cachés), así que la
    /// notificación siempre sale en el actor principal aunque el token se refresque desde
    /// una tarea de red en segundo plano.
    private func postAuthChanged() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .authChanged, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .authChanged, object: nil)
            }
        }
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
        postAuthChanged()
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
