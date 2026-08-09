import Foundation

protocol APIService {
    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T
    func request(endpoint: APIEndpoint) async throws

    /// Ruta directa del explorador: decodifica DTOs `Sendable` fuera del actor principal en
    /// lugar de pasar por el remapeo a diccionarios de `request(endpoint:)`.
    /// Es el endpoint que más volumen mueve (hasta 1000 territorios con geometría completa).
    func territoryExplorer(
        term: String?,
        filter: TerritoryFilter,
        attentionDays: Int
    ) async throws -> [Territory]
}
