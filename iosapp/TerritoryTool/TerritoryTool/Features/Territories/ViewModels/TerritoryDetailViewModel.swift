import Foundation
import Combine

@MainActor
class TerritoryDetailViewModel: ObservableObject {
    @Published var territory: TerritoryDetail?
    @Published var stats: TerritoryStatistics?
    @Published var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showDeleteConfirmation: Bool = false
    @Published var isRefreshingImage: Bool = false
    
    private let apiService: APIService
    let territoryId: Int
    
    init(territoryId: Int, apiService: APIService) {
        self.territoryId = territoryId
        self.apiService = apiService
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use sequential await instead of async let to avoid main actor isolation warnings
            let detail: TerritoryDetail = try await apiService.request(endpoint: TerritoryEndpoint.getTerritoryDetail(id: territoryId))
            let statistics: TerritoryStatistics = try await apiService.request(endpoint: TerritoryEndpoint.getTerritoryStats(id: territoryId))
            let txs: [Transaction] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritoryTransactions(id: territoryId))
            
            self.territory = detail
            self.stats = statistics
            self.transactions = txs
        } catch {
            self.errorMessage = "Error loading data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshImage() async -> Bool {
        isRefreshingImage = true
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.refreshTerritoryImage(id: territoryId))
            // Reload detail to get new image URL
            let updatedDetail: TerritoryDetail = try await apiService.request(endpoint: TerritoryEndpoint.getTerritoryDetail(id: territoryId))
            self.territory = updatedDetail
            isRefreshingImage = false
            return true
        } catch {
            self.errorMessage = "Error refreshing image: \(error.localizedDescription)"
            isRefreshingImage = false
            return false
        }
    }
    
    func deleteTerritory() async -> Bool {
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.deleteTerritory(id: territoryId))
            return true
        } catch {
            self.errorMessage = "Error deleting territory: \(error.localizedDescription)"
            return false
        }
    }
}
