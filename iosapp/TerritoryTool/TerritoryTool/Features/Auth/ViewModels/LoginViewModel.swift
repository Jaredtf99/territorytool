import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var userName = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    private let apiService: APIService
    private let authService: SupabaseAuthService
    
    init(apiService: APIService, authService: SupabaseAuthService = .shared) {
        self.apiService = apiService
        self.authService = authService
        self.isAuthenticated = TokenManager.shared.isAuthenticated
    }
    
    func login() async {
        guard !userName.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter username and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await authService.login(username: userName, password: password)
            TokenManager.shared.saveToken(response.token)
            TokenManager.shared.saveRefreshToken(response.session.refreshToken)
            TokenManager.shared.saveProfile(userName: response.profile?.username, role: response.profile?.role)
            TokenManager.shared.saveActiveCongregationId(response.profile?.activeCongregationId)
            if let congregations = response.congregations {
                TokenManager.shared.saveCongregations(try? JSONEncoder().encode(congregations))
            }
            isAuthenticated = true
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func logout() {
        TokenManager.shared.clearToken()
        isAuthenticated = false
        userName = ""
        password = ""
    }
}
