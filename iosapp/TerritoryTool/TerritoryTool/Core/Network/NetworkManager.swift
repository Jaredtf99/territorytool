import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
    case unauthorized
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error.invalid_url", value: "Invalid URL", comment: "")
        case .invalidResponse:
            return NSLocalizedString("error.invalid_response", value: "Invalid response from server", comment: "")
        case .decodingError:
            return NSLocalizedString("error.decoding", value: "Error decoding data", comment: "")
        case .serverError(let message):
            return message
        case .unauthorized:
            return NSLocalizedString("error.unauthorized", value: "Session expired", comment: "")
        case .unknown:
            return NSLocalizedString("error.unknown", value: "Unknown error occurred", comment: "")
        }
    }
}

class NetworkManager: APIService {
    static let shared = NetworkManager()
    private let baseURL = AppConfig.apiBaseURL
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
        let data = try await performRequest(endpoint: endpoint)
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    func request(endpoint: APIEndpoint) async throws {
        _ = try await performRequest(endpoint: endpoint)
    }
    
    private func performRequest(endpoint: APIEndpoint) async throws -> Data {
        guard var urlComponents = URLComponents(string: baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        
        // Add headers
        endpoint.headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add Auth Token
        if let token = TokenManager.shared.getToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                throw NetworkError.unauthorized
            }
            
            // Try to decode error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let message = json["message"] as? String {
                     throw NetworkError.serverError(message)
                } else if let error = json["error"] as? String {
                     throw NetworkError.serverError(error)
                } else if let title = json["title"] as? String {
                     throw NetworkError.serverError(title)
                }
            }
            
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw NetworkError.serverError(errorMessage)
            }
            throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        return data
    }
}
