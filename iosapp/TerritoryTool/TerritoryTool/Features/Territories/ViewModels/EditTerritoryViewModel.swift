import Foundation
import Combine

@MainActor
class EditTerritoryViewModel: ObservableObject {
    @Published var name: String
    @Published var code: String
    @Published var mapUrl: String
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let apiService: APIService
    private let territoryId: Int
    
    init(territory: TerritoryDetail, apiService: APIService) {
        self.territoryId = territory.id
        self.name = territory.name
        self.code = territory.code
        self.mapUrl = territory.mapUrl
        self.apiService = apiService
    }
    
    init(territory: Territory, apiService: APIService) {
        self.territoryId = territory.id
        self.name = territory.name
        self.code = territory.code
        self.mapUrl = territory.mapUrl
        self.apiService = apiService
    }
    
    func save() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.updateTerritory(id: territoryId, code: code, name: name, mapUrl: mapUrl))
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = mapError(error)
            return false
        }
    }
    
    private func mapError(_ error: Error) -> String {
        let message = error.localizedDescription
        
        if message.contains("CODE_EXIST") {
            return NSLocalizedString("error.territory.code_exists", comment: "")
        } else if message.contains("NAME_EXIST") {
            return NSLocalizedString("error.territory.name_exists", comment: "")
        } else if message.contains("MAPURL_EXIST") {
            return NSLocalizedString("error.territory.map_url_exists", comment: "")
        } else if message.contains("TERRITORY_NOT_FOUND") {
            return NSLocalizedString("error.territory.not_found", comment: "")
        } else if message.contains("INVALID_PARAMETERS") {
            return NSLocalizedString("error.invalid_parameters", comment: "")
        }
        
        return "Error: \(message)"
    }
}
