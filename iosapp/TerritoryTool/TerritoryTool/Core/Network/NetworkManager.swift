import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
    case unauthorized
    case unknown
}

class NetworkManager: APIService {
    private let baseURL = AppConfig.apiBaseURL
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
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
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw NetworkError.serverError(errorMessage)
            }
            throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        do {
            // Handle Void response (empty body)
            if T.self == Void.self {
                return () as! T
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
}
