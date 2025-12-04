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
    
    init(apiService: APIService) {
        self.apiService = apiService
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
            let credentials = LoginCredentials(userName: userName, password: password)
            let response: LoginResponse = try await apiService.request(endpoint: TerritoryEndpoint.login(credentials: credentials))
            
            TokenManager.shared.saveToken(response.token)
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
