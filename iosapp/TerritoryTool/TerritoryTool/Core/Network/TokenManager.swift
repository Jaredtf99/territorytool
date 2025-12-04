import Foundation
import Security

class TokenManager {
    static let shared = TokenManager()
    private let key = "authToken"
    
    // For simplicity in this demo, we use UserDefaults. 
    // In production, Keychain is recommended.
    
    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
        NotificationCenter.default.post(name: .authChanged, object: nil)
    }
    
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: key)
    }
    
    func clearToken() {
        UserDefaults.standard.removeObject(forKey: key)
        NotificationCenter.default.post(name: .authChanged, object: nil)
    }
    
    var isAuthenticated: Bool {
        return getToken() != nil
    }
}
