import Foundation
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showSessionExpiredAlert = false
    
    init() {
        self.isAuthenticated = TokenManager.shared.isAuthenticated
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSessionExpired), name: .sessionExpired, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func checkAuth() {
        self.isAuthenticated = TokenManager.shared.isAuthenticated
    }
    
    func logout() {
        TokenManager.shared.clearToken()
        self.isAuthenticated = false
        self.showSessionExpiredAlert = false
        NotificationCenter.default.post(name: .authChanged, object: nil)
    }
    
    @objc func handleSessionExpired() {
        DispatchQueue.main.async {
            self.showSessionExpiredAlert = true
        }
    }
}

extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}
