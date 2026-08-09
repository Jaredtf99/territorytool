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
            TokenManager.shared.saveSession(
                token: response.token,
                refreshToken: response.session.refreshToken,
                userName: response.profile?.username,
                role: response.profile?.role,
                activeCongregationId: response.profile?.activeCongregationId,
                congregations: response.congregations.flatMap { try? JSONEncoder().encode($0) }
            )
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
