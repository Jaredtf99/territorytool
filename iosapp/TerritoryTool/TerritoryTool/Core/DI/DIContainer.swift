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
    
    func makeTerritoryAssignmentViewModel(territory: Territory? = nil) -> TerritoryAssignmentViewModel {
        let viewModel = TerritoryAssignmentViewModel(apiService: apiService)
        if let territory = territory {
            viewModel.selectedTerritory = territory
        }
        return viewModel
    }
    
    func makeTerritoryReturnViewModel(territory: Territory? = nil) -> TerritoryReturnViewModel {
        let viewModel = TerritoryReturnViewModel(apiService: apiService)
        if let territory = territory {
            viewModel.selectedTerritory = territory
        }
        return viewModel
    }
    
    func makeBrothersViewModel() -> BrothersViewModel {
        return BrothersViewModel(networkManager: apiService)
    }
    
    func makeUsersViewModel() -> UsersViewModel {
        return UsersViewModel(networkManager: apiService)
    }
}


