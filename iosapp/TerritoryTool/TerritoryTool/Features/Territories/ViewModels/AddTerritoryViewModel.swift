import Foundation
import Combine

@MainActor
class AddTerritoryViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var code: String = ""
    @Published var mapUrl: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    
    private let apiService: APIService
    
    init(apiService: APIService = NetworkManager()) {
        self.apiService = apiService
    }
    
    func createTerritory() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.addTerritory(code: code, name: name, mapUrl: mapUrl))
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
        } else if message.contains("INVALID_PARAMETERS") {
            return NSLocalizedString("error.invalid_parameters", comment: "")
        }
        
        return "Error: \(message)"
    }
}
