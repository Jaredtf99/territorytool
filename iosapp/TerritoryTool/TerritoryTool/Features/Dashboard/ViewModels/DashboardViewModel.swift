import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var oldTerritories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIService
    
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    func loadOldTerritories() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate date 4 months ago
            let fourMonthsAgo = Calendar.current.date(byAdding: .month, value: -4, to: Date())
            
            // Fetch territories: inUse=true, orderBy=3 (Oldest), lastGivenDateTo=4 months ago
            let territories: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: nil,
                inUse: true,
                orderBy: 3,
                orderByAscending: true,
                lastGivenDateFrom: nil,
                lastGivenDateTo: fourMonthsAgo
            ))
            
            // Limit to top 3 as per requirements
            self.oldTerritories = Array(territories.prefix(3))
        } catch {
            errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func logout() {
        TokenManager.shared.clearToken()
    }
}
