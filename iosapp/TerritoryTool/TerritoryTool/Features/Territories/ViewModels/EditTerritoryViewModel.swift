import Foundation
import Combine

@MainActor
class EditTerritoryViewModel: ObservableObject {
    @Published var name: String
    @Published var code: String
    @Published var mapUrl: String
    @Published var excludeFromSuggestions: Bool
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var lastUndoHandle: UndoHandle?
    
    private let apiService: APIService
    private let territoryId: Int
    /// Valor guardado tal y como llegó; `nil` si la fuente no lo traía.
    private let storedExcludeFromSuggestions: Bool?
    
    init(territory: TerritoryDetail, apiService: APIService) {
        self.territoryId = territory.id
        self.name = territory.name
        self.code = territory.code
        self.mapUrl = territory.mapUrl
        self.storedExcludeFromSuggestions = territory.excludeFromSuggestions
        self.excludeFromSuggestions = territory.excludeFromSuggestions ?? false
        self.apiService = apiService
    }
    
    init(territory: Territory, apiService: APIService) {
        self.territoryId = territory.id
        self.name = territory.name
        self.code = territory.code
        self.mapUrl = territory.mapUrl
        self.storedExcludeFromSuggestions = territory.excludeFromSuggestions
        self.excludeFromSuggestions = territory.excludeFromSuggestions ?? false
        self.apiService = apiService
    }
    
    func save() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(endpoint: TerritoryEndpoint.updateTerritoryUndoable(id: territoryId, code: code, name: name, mapUrl: mapUrl, excludeFromSuggestions: excludeFromSuggestionsToSend))
            lastUndoHandle = undoResponse.handle(kind: .domain)
            isLoading = false
            return true
        } catch {
            isLoading = false
            lastUndoHandle = nil
            errorMessage = mapError(error)
            return false
        }
    }
    
    /// Sólo se envía si se conocía o si el usuario lo cambió: así, editar desde una fuente
    /// que no trae el campo nunca pisa el valor guardado (`nil` = no tocar).
    private var excludeFromSuggestionsToSend: Bool? {
        if storedExcludeFromSuggestions != nil || excludeFromSuggestions { return excludeFromSuggestions }
        return nil
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
