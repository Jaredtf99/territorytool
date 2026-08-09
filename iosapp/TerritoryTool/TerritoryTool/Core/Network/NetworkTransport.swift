import Foundation

/// Transporte HTTP aislado fuera del actor principal.
///
/// El target compila con `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, así que
/// `NetworkManager` es implícitamente `@MainActor`. `URLSession` sí transporta fuera de
/// main, pero **todo lo que ocurre al volver** —parsear el JSON, remapearlo y
/// decodificarlo— se ejecutaba en el hilo principal, sobre respuestas de hasta 1000
/// territorios con su geometría completa.
///
/// Este actor mueve esa parte fuera. Recibe una `URLRequest` ya construida (que es
/// `Sendable`), inyecta la autenticación, gestiona el 401 con reintento, y decodifica DTOs
/// `Sendable` dentro de su propio aislamiento. Nada que no sea `Sendable` cruza la frontera:
/// ni endpoints, ni diccionarios `[String: Any]`, ni modelos de UI.
actor NetworkTransport {
    static let shared = NetworkTransport()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        // Instancia propia del actor: nunca hay dos tareas usándola a la vez.
        self.decoder = SupabaseJSONDecoder.make()
    }

    // MARK: - Peticiones

    /// Ejecuta la petición y devuelve el cuerpo crudo.
    func data(for request: URLRequest) async throws -> Data {
        try await send(request, allowRefresh: true)
    }

    /// Ejecuta la petición y decodifica el cuerpo **dentro del actor**, sin pasar por
    /// diccionarios intermedios ni por una segunda serialización.
    func decoded<T: Decodable & Sendable>(_ type: T.Type, for request: URLRequest) async throws -> T {
        let data = try await send(request, allowRefresh: true)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("Decoding error for \(T.self): \(error)")
            #endif
            throw NetworkError.decodingError
        }
    }

    private func send(_ request: URLRequest, allowRefresh: Bool) async throws -> Data {
        var authorized = request
        let bearer = TokenManager.shared.getToken() ?? AppConfig.supabasePublishableKey
        authorized.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: authorized)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                // El token de acceso probablemente ha caducado. Intentamos canjear el
                // refresh token y repetir la petición una vez. Sólo nos rendimos (y
                // mostramos "sesión expirada") si el propio refresco falla.
                if allowRefresh, TokenManager.shared.getRefreshToken() != nil {
                    do {
                        _ = try await SessionRefresher.shared.refresh()
                        return try await send(request, allowRefresh: false)
                    } catch {
                        // Refresh token revocado o caducado: seguimos hasta el logout.
                    }
                }
                Self.postOnMain(.sessionExpired)
                throw NetworkError.unauthorized
            }
            throw NetworkError.serverError(
                Self.errorMessage(from: data) ?? "Status code: \(http.statusCode)"
            )
        }

        return data
    }

    // MARK: - Construcción de peticiones

    /// Construye la petición. El cuerpo llega ya serializado para que todo lo que cruza la
    /// frontera del actor sea `Sendable`.
    nonisolated static func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: AppConfig.supabaseURL + path) else {
            throw NetworkError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    // MARK: - Apoyo

    nonisolated static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        return object["message"] as? String
            ?? object["error"] as? String
            ?? object["msg"] as? String
            ?? object["hint"] as? String
    }

    /// Los observadores de estas notificaciones son de UI, así que salen siempre en main.
    nonisolated static func postOnMain(_ name: Notification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}
