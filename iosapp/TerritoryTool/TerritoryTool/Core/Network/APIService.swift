import Foundation

protocol APIService {
    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T
}
