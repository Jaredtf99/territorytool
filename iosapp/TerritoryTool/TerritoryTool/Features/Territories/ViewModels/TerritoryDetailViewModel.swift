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
    @Published private(set) var lastUndoHandle: UndoHandle?
    
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

            if detail.mapGeometry == nil {
                await syncMapGeometry()
            }
        } catch {
            if !error.isCancellation {
                self.errorMessage = "Error loading data: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    private func syncMapGeometry() async {
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.syncTerritoryMap(id: territoryId))
            let updatedDetail: TerritoryDetail = try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritoryDetail(id: territoryId)
            )
            self.territory = updatedDetail
        } catch {
            // Keep the legacy image fallback. Geometry can be retried on the
            // next detail load or through the administrator refresh action.
            print("Unable to synchronize territory map geometry: \(error)")
        }
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
            // Don't replace the whole detail view with an error; surface it as a toast.
            ToastManager.shared.show("territory_detail.refresh_image_failed", style: .error)
            isRefreshingImage = false
            return false
        }
    }
    
    func deleteTerritory() async -> Bool {
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(endpoint: TerritoryEndpoint.deleteTerritoryUndoable(id: territoryId))
            lastUndoHandle = undoResponse.handle(kind: .domain)
            return true
        } catch {
            lastUndoHandle = nil
            self.errorMessage = "Error deleting territory: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Transaction Management
    
    func deleteTransaction(id: Int) async -> Bool {
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(endpoint: TerritoryEndpoint.deleteTransactionUndoable(id: id))
            lastUndoHandle = undoResponse.handle(kind: .domain)
            // Remove from local list
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                transactions.remove(at: index)
            }
            // Refresh stats and detail as they might change
            await loadData()
            return true
        } catch {
            lastUndoHandle = nil
            self.errorMessage = "Error deleting transaction: \(error.localizedDescription)"
            return false
        }
    }
    
    func fetchDataForEdit() async throws -> ([Person], [Territory]) {
        // Reuse getPersons and getTerritories from TerritoryEndpoint
        async let personsRequest: [Person] = apiService.request(endpoint: TerritoryEndpoint.getPersons(search: nil))
        async let territoriesRequest: [Territory] = apiService.request(
            endpoint: TerritoryEndpoint.getTerritories(
                term: nil,
                inUse: nil,
                orderBy: nil,
                orderByAscending: nil,
                lastGivenDateFrom: nil,
                lastGivenDateTo: nil
            )
        )
        
        return try await (personsRequest, territoriesRequest)
    }
    
    func updateFullTransaction(originalTransactionId: Int, territoryId: Int, personId: Int, givenDate: Date, pickedDate: Date?) async {
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(endpoint: TerritoryEndpoint.updateTransactionUndoable(
                id: originalTransactionId,
                territoryId: territoryId,
                personId: personId, // Ensure optionality is handled if API expects it
                date: givenDate,
                pickedDate: pickedDate
            ))
            lastUndoHandle = undoResponse.handle(kind: .domain)
            
            // Reload data to reflect changes
            await loadData()
        } catch {
            lastUndoHandle = nil
            self.errorMessage = "Error updating transaction: \(error.localizedDescription)"
        }
    }
}
