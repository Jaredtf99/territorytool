import SwiftUI

@MainActor
class DIContainer {
    static let shared = DIContainer()
    
    // Services
    let apiService: APIService
    
    // ViewModels Factory
    
    init() {
        self.apiService = NetworkManager()
    }
    
    func makeLoginViewModel() -> LoginViewModel {
        return LoginViewModel(apiService: apiService)
    }
    
    func makeDashboardViewModel() -> DashboardViewModel {
        return DashboardViewModel(apiService: apiService)
    }
    
    func makeTerritoriesViewModel() -> TerritoriesViewModel {
        return TerritoriesViewModel(apiService: apiService)
    }
}


