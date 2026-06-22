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

final class NetworkManager: APIService {
    static let shared = NetworkManager()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
        let payload = try await payload(for: endpoint)
        let data = try jsonData(from: payload)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }

    func request(endpoint: APIEndpoint) async throws {
        _ = try await payload(for: endpoint)
    }

    private func payload(for endpoint: APIEndpoint) async throws -> Any {
        guard let territoryEndpoint = endpoint as? TerritoryEndpoint else {
            throw NetworkError.invalidURL
        }

        switch territoryEndpoint {
        case .login(let credentials):
            let response = try await SupabaseAuthService.shared.login(username: credentials.userName, password: credentials.password)
            TokenManager.shared.saveToken(response.token)
            TokenManager.shared.saveRefreshToken(response.session.refreshToken)
            TokenManager.shared.saveProfile(userName: response.profile?.username, role: response.profile?.role)
            TokenManager.shared.saveActiveCongregationId(response.profile?.activeCongregationId)
            if let congregations = response.congregations {
                TokenManager.shared.saveCongregations(try? JSONEncoder().encode(congregations))
            }
            return ["token": response.token]

        case .getTerritories(let term, let inUse, let orderBy, let ascending, let fromDate, let toDate):
            let rows = try await rpcRows("search_territories", body: [
                "term": term ?? NSNull(),
                "only_free": inUse == false,
                "only_given": inUse == true,
                "take": 1000
            ])
            var territories = try await mapTerritories(rows)
            if let fromDate {
                territories = territories.filter { dateValue($0["givenDateUtc"]) >= fromDate }
            }
            if let toDate {
                territories = territories.filter { dateValue($0["givenDateUtc"]) <= toDate }
            }
            return sortTerritories(territories, orderBy: orderBy, ascending: ascending ?? true)

        case .getTerritoryExplorer(let term, let filter, let attentionDays):
            let rows = try await rpcRows("search_territory_explorer", body: [
                "term": term ?? NSNull(),
                "status": filter.backendValue,
                "attention_days": attentionDays,
                "take": 1000
            ])
            return mapExplorerTerritories(rows)

        case .getTerritory(let id):
            let row = try await singleRow("/rest/v1/territory_current_state", queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(id)")
            ])
            return (try await mapTerritories([row])).first ?? [:]

        case .getTerritoryDetail(let id):
            return try await buildTerritoryDetail(id: id)

        case .getTerritoryStats(let id):
            let stats = try await rpcObject("get_territory_statistics", body: ["territory_id": id])
            return mapStatistics(stats)

        case .getTerritoryTransactions(let id):
            let rows = try await restRows("/rest/v1/territory_details", queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "territory_id", value: "eq.\(id)"),
                URLQueryItem(name: "transaction_id", value: "not.is.null"),
                URLQueryItem(name: "order", value: "given_at.desc")
            ])
            return mapTransactions(rows)

        case .getRecentTransactions:
            let rows = try await restRows("/rest/v1/recent_transactions", queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "given_at.desc")
            ])
            return mapTransactions(rows)

        case .getDashboardSnapshot(let weekStart, let timeZone, let attentionDays):
            return try await rpcObject("get_dashboard_snapshot", body: [
                "p_week_start": isoFormatter.string(from: weekStart),
                "p_timezone": timeZone,
                "p_attention_days": attentionDays
            ])

        case .getMovementHistory(let page, let pageSize, let search, let filter, let sort):
            return try await rpcObject("get_movement_history", body: [
                "p_page": page,
                "p_page_size": pageSize,
                "p_search": search ?? NSNull(),
                "p_event_type": filter.rawValue,
                "p_sort_ascending": sort.ascending
            ])

        case .giveTerritory(let code, let personName, let date):
            return try await rpcObject("give_territory", body: [
                "territory_code": code,
                "person_name": personName,
                "custom_date": date.map { isoFormatter.string(from: $0) } ?? NSNull()
            ])

        case .pickTerritory(let code, let date):
            return try await rpcObject("pick_territory", body: [
                "territory_code": code,
                "custom_date": date.map { isoFormatter.string(from: $0) } ?? NSNull()
            ])

        case .getPersons(let search):
            // Query the persons table directly with the active transactions
            // embedded (territory_transactions still open, i.e. picked_at null),
            // mirroring the Angular client. search_persons only returns id/name/
            // enabled, which is why the territories never showed up.
            var items: [URLQueryItem] = [
                URLQueryItem(name: "select", value: "id,name,enabled,territory_transactions(given_at,picked_at,territories(id,name,code))"),
                URLQueryItem(name: "order", value: "name.asc")
            ]
            if let search = search, !search.isEmpty {
                items.append(URLQueryItem(name: "name", value: "ilike.*\(search)*"))
            }
            let rows = try await restRows("/rest/v1/persons", queryItems: items)
            return rows.map { row in
                let transactions = (row["territory_transactions"] as? [[String: Any]]) ?? []
                let territoriesInUse: [[String: Any]] = transactions
                    .filter { isNull($0["picked_at"]) }
                    .map { tx in
                        let territory = tx["territories"] as? [String: Any]
                        return [
                            "territoryId": territory?["id"] ?? 0,
                            "territoryName": territory?["name"] ?? "",
                            "territoryCode": territory?["code"] ?? "",
                            "givenDate": tx["given_at"] ?? ""
                        ]
                    }
                return [
                    "id": row["id"] ?? 0,
                    "name": row["name"] ?? "",
                    "enabled": row["enabled"] ?? true,
                    "territoriesInUse": territoriesInUse
                ]
            }

        case .getPersonsWithAssignments(let search):
            let rows = try await rpcRows("search_persons_with_assignments", body: [
                "term": search ?? NSNull(),
                "take": 1000
            ])
            return rows.map { row in
                [
                    "id": row["id"] ?? 0,
                    "name": row["name"] ?? "",
                    "enabled": row["enabled"] ?? true,
                    "territoriesInUse": row["territories_in_use"] ?? []
                ]
            }

        case .resolveTerritorySelector(let value):
            let rows = try await rpcRows("resolve_territory_selector", body: ["value": value])
            guard let territory = try await mapTerritories(rows).first else {
                throw NetworkError.serverError(
                    NSLocalizedString(
                        "quick_action.territory_not_found",
                        value: "Territory not found",
                        comment: ""
                    )
                )
            }
            return territory

        case .addPerson(let name):
            return try await rpcObject("add_person", body: ["name": name])

        case .updatePerson(let id, let name, let enabled):
            return try await rpcObject("update_person", body: ["person_id": id, "name": name, "enabled": enabled])

        case .deletePerson(let name):
            return try await rpcObject("delete_person", body: ["name": name])

        case .addTerritory(let code, let name, let mapUrl):
            return try await rpcObject("add_territory", body: ["code": code, "name": name, "map_url": mapUrl])

        case .updateTerritory(let id, let code, let name, let mapUrl):
            return try await rpcObject("update_territory", body: [
                "territory_id": id,
                "code": code,
                "name": name,
                "map_url": mapUrl
            ])

        case .deleteTerritory(let id):
            return try await rpcObject("delete_territory", body: ["territory_id": id])

        case .refreshTerritoryImage(let id):
            return try await edgeFunction("refresh-territory-image", body: ["territoryId": id])

        case .syncTerritoryMap(let id):
            return try await edgeFunction("refresh-territory-image", body: [
                "territoryId": id,
                "geometryOnly": true
            ])

        case .syncAllTerritoryMaps:
            return try await edgeFunction("refresh-territory-image", body: [
                "syncAllGeometry": true
            ])

        case .getActionLogs(let page, let pageSize, let sortField, let sortOrder):
            let response = try await rpcObject("get_action_logs", body: [
                "page_number": page,
                "page_size": pageSize,
                "sort_field": sortField,
                "sort_order": sortOrder
            ])
            let data = (response["data"] as? [[String: Any]]) ?? []
            let logs = data.map { row -> [String: Any] in
                [
                    "type": actionTypeName(row["actionType"] as? Int),
                    "dateUtc": row["dateUtc"] ?? row["DateUtc"] ?? "",
                    "userName": row["userName"] ?? row["UserName"] ?? NSNull(),
                    "message": row["message"] ?? row["Message"] ?? NSNull(),
                    "successful": row["successful"] ?? row["Successful"] ?? false
                ]
            }
            let total = response["totalCount"] as? Int ?? logs.count
            let lastPage = max(1, Int(ceil(Double(total) / Double(max(pageSize, 1)))))
            return [
                "data": logs,
                "current_page": page,
                "last_page": lastPage,
                "total": total
            ]

        case .getUsers:
            let rows = try await edgeRows("admin-users", body: ["action": "list"])
            return rows.map { row in
                [
                    "UserID": row["id"] ?? "",
                    "UserName": row["username"] ?? "",
                    "Role": row["role"] ?? "USER"
                ]
            }

        case .addUser(let name, let role, let password):
            return try await edgeFunction("admin-users", body: [
                "action": "create",
                "username": name,
                "role": role,
                "password": password
            ])

        case .updateUser(let id, let name, let role):
            return try await edgeFunction("admin-users", body: [
                "action": "update",
                "userId": id,
                "username": name,
                "role": role
            ])

        case .deleteUser(let id):
            return try await edgeFunction("admin-users", body: ["action": "delete", "userId": id])

        case .changeUserPassword(let id, let newPassword):
            return try await edgeFunction("admin-users", body: [
                "action": "change-password",
                "userId": id,
                "newPassword": newPassword
            ])

        case .deleteTransaction(let id):
            return try await rpcObject("delete_transaction", body: ["transaction_id": id])

        case .updateTransaction(let id, _, let personId, let date, let pickedDate):
            return try await rpcObject("update_transaction", body: [
                "transaction_id": id,
                "person_id": personId ?? NSNull(),
                "given_at": isoFormatter.string(from: date),
                "picked_at": pickedDate.map { isoFormatter.string(from: $0) } ?? NSNull()
            ])
        }
    }

    private func restRows(_ path: String, queryItems: [URLQueryItem]) async throws -> [[String: Any]] {
        return (try await requestJSON(path: path, method: "GET", queryItems: queryItems) as? [[String: Any]]) ?? []
    }

    private func singleRow(_ path: String, queryItems: [URLQueryItem]) async throws -> [String: Any] {
        let rows = try await restRows(path, queryItems: queryItems)
        guard let first = rows.first else { throw NetworkError.invalidResponse }
        return first
    }

    private func rpcRows(_ name: String, body: [String: Any]) async throws -> [[String: Any]] {
        return (try await requestJSON(path: "/rest/v1/rpc/\(name)", method: "POST", body: body) as? [[String: Any]]) ?? []
    }

    private func rpcObject(_ name: String, body: [String: Any]) async throws -> [String: Any] {
        let result = try await requestJSON(path: "/rest/v1/rpc/\(name)", method: "POST", body: body)
        if result is NSNull { return [:] }
        return (result as? [String: Any]) ?? [:]
    }

    private func edgeRows(_ name: String, body: [String: Any]) async throws -> [[String: Any]] {
        return (try await edgeFunction(name, body: body) as? [[String: Any]]) ?? []
    }

    private func edgeFunction(_ name: String, body: [String: Any]) async throws -> Any {
        return try await requestJSON(path: "/functions/v1/\(name)", method: "POST", body: body)
    }

    private func requestJSON(path: String, method: String, queryItems: [URLQueryItem] = [], body: Any? = nil, allowRefresh: Bool = true) async throws -> Any {
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

        let bearer = TokenManager.shared.getToken() ?? AppConfig.supabasePublishableKey
        request.addValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                // The access token likely expired. Try to exchange the refresh
                // token for a fresh one and replay the request once. Only give
                // up (and surface "session expired") if the refresh itself fails.
                if allowRefresh, TokenManager.shared.getRefreshToken() != nil {
                    do {
                        _ = try await SessionRefresher.shared.refresh()
                        return try await requestJSON(path: path, method: method, queryItems: queryItems, body: body, allowRefresh: false)
                    } catch {
                        // Refresh token revoked/expired — fall through to logout.
                    }
                }
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                throw NetworkError.unauthorized
            }
            throw NetworkError.serverError(errorMessage(from: data) ?? "Status code: \(httpResponse.statusCode)")
        }

        if data.isEmpty {
            return [:]
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func buildTerritoryDetail(id: Int) async throws -> [String: Any] {
        let state = try await singleRow("/rest/v1/territory_current_state", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.\(id)")
        ])
        let history = try await restRows("/rest/v1/territory_details", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "territory_id", value: "eq.\(id)"),
            URLQueryItem(name: "order", value: "given_at.desc")
        ])

        let territory = (try await mapTerritories([state])).first ?? [:]
        let timeline = history.flatMap { row -> [[String: Any]] in
            guard let transactionId = row["transaction_id"] as? Int else { return [] }
            var items: [[String: Any]] = [[
                "id": transactionId * 10 + 2,
                "description": "Entregado a \(row["person_name"] as? String ?? "")",
                "type": 2,
                "date": row["given_at"] ?? ""
            ]]
            if let picked = row["picked_at"], !(picked is NSNull) {
                items.append([
                    "id": transactionId * 10 + 1,
                    "description": "Recogido de \(row["person_name"] as? String ?? "")",
                    "type": 1,
                    "date": picked
                ])
            }
            return items
        }

        return [
            "id": territory["id"] ?? id,
            "code": territory["code"] ?? "",
            "name": territory["name"] ?? "",
            "mapUrl": territory["mapUrl"] ?? "",
            "imgUrl": territory["imgUrl"] ?? NSNull(),
            "personName": territory["personName"] ?? NSNull(),
            "lastPickedDateUtc": territory["lastPickedDateUtc"] ?? NSNull(),
            "givenDateUtc": territory["givenDateUtc"] ?? NSNull(),
            "pickedCount": history.filter { !isNull($0["picked_at"]) }.count,
            "lastUser": history.first?["person_name"] ?? NSNull(),
            "timelineItems": timeline,
            "mapGeometry": state["map_geometry"] ?? NSNull()
        ]
    }

    private func mapTerritories(_ rows: [[String: Any]]) async throws -> [[String: Any]] {
        var territories: [[String: Any]] = []
        for row in rows {
            let imagePath = row["image_path"] as? String
            territories.append([
                "id": row["id"] ?? 0,
                "code": row["code"] ?? "",
                "name": row["name"] ?? "",
                "mapUrl": row["map_url"] ?? "",
                "imgUrl": try await signedImageURL(for: imagePath) ?? NSNull(),
                "personName": row["person_name"] ?? NSNull(),
                "givenDateUtc": row["given_at"] ?? NSNull(),
                "lastPickedDateUtc": row["last_picked_at"] ?? NSNull(),
                "mapGeometry": row["map_geometry"] ?? NSNull()
            ])
        }
        return territories
    }

    private func mapExplorerTerritories(_ rows: [[String: Any]]) -> [[String: Any]] {
        rows.map { row in
            [
                "id": row["id"] ?? 0,
                "code": row["code"] ?? "",
                "name": row["name"] ?? "",
                "mapUrl": row["map_url"] ?? "",
                "imgUrl": NSNull(),
                "personName": row["person_name"] ?? NSNull(),
                "givenDateUtc": row["given_at"] ?? NSNull(),
                "lastPickedDateUtc": row["last_picked_at"] ?? NSNull(),
                "mapGeometry": row["map_geometry"] ?? NSNull()
            ]
        }
    }

    private func mapTransactions(_ rows: [[String: Any]]) -> [[String: Any]] {
        return rows.compactMap { row in
            guard let id = row["transaction_id"] as? Int else { return nil }
            return [
                "transactionId": id,
                "personId": row["person_id"] ?? 0,
                "givenDateUtc": row["given_at"] ?? "",
                "pickedDateUtc": row["picked_at"] ?? NSNull(),
                "givenBy": row["given_by_username"] ?? NSNull(),
                "pickedBy": row["picked_by_username"] ?? NSNull(),
                "territoryId": row["territory_id"] ?? 0,
                "territoryName": row["territory_name"] ?? row["name"] ?? "",
                "personName": row["person_name"] ?? ""
            ]
        }
    }

    private func mapStatistics(_ row: [String: Any]) -> [String: Any] {
        return [
            "totalTerritories": num(row["totalTerritories"]),
            "usageRank": num(row["usageRank"]),
            "isHighUsage": row["isHighUsage"] as? Bool ?? false,
            "isLowUsage": row["isLowUsage"] as? Bool ?? false,
            "assignedTimePercentage": num(row["assignedTimePercentage"]),
            "globalAverageAssignedTimePercentage": num(row["globalAverageAssignedTimePercentage"]),
            "averageReassignmentTime": num(row["averageReassignmentTime"]),
            "globalAverageReassignmentTime": num(row["globalAverageReassignmentTime"]),
            "averageHoldingTime": num(row["averageHoldingTime"]),
            "globalAverageHoldingTime": num(row["globalAverageHoldingTime"]),
            "currentUnassignedTime": num(row["currentUnassignedTime"]),
            "uniqueUsersCount": num(row["uniqueUsersCount"]),
            "globalAverageUniqueUsersCount": num(row["globalAverageUniqueUsersCount"])
        ]
    }

    // Coerces missing/JSON-null numeric values to 0 so decoding into non-optional
    // Int/Double fields never fails (e.g. averageHoldingTime is null when a
    // territory has no completed assignments).
    private func num(_ value: Any?) -> Any {
        if let value, !(value is NSNull) { return value }
        return 0
    }

    private func signedImageURL(for imagePath: String?) async throws -> Any? {
        guard let imagePath, !imagePath.isEmpty else { return nil }
        let encodedPath = imagePath
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        let result = try await requestJSON(
            path: "/storage/v1/object/sign/territory-images/\(encodedPath)",
            method: "POST",
            body: ["expiresIn": 3600]
        )
        guard let object = result as? [String: Any],
              let signed = object["signedURL"] as? String ?? object["signedUrl"] as? String else {
            return nil
        }
        // The sign endpoint returns a path relative to the Storage API root
        // (e.g. "/object/sign/territory-images/...?token=..."), so it needs the
        // "/storage/v1" prefix to form a reachable URL.
        if signed.hasPrefix("http") { return signed }
        let relative = signed.hasPrefix("/storage/v1") ? signed : "/storage/v1" + signed
        return AppConfig.supabaseURL + relative
    }

    private func sortTerritories(_ territories: [[String: Any]], orderBy: Int?, ascending: Bool) -> [[String: Any]] {
        guard let orderBy else { return territories }
        return territories.sorted { left, right in
            let result: ComparisonResult
            if orderBy == 1 {
                result = String(describing: left["name"] ?? "").localizedCaseInsensitiveCompare(String(describing: right["name"] ?? ""))
            } else if orderBy == 2 {
                result = String(describing: left["code"] ?? "").localizedCaseInsensitiveCompare(String(describing: right["code"] ?? ""))
            } else if orderBy == 3 {
                result = dateValue(left["givenDateUtc"]).compare(dateValue(right["givenDateUtc"]))
            } else {
                result = .orderedSame
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private func actionTypeName(_ value: Int?) -> String {
        switch value {
        case 1: return "AddTerritory"
        case 2: return "EditTerritory"
        case 3: return "DeleteTerritory"
        case 4: return "AddUser"
        case 5: return "DeleteUser"
        case 6: return "ChangeUserPassword"
        case 7: return "EditUser"
        case 8: return "AddPerson"
        case 9: return "EditPerson"
        case 10: return "DeletePerson"
        case 11: return "GiveTerritory"
        case 12: return "PickTerritory"
        case 13: return "RefreshTerritoryImage"
        case 14: return "EditTransaction"
        case 15: return "DeleteTransaction"
        default: return "Unknown"
        }
    }

    private func dateValue(_ value: Any?) -> Date {
        guard let string = value as? String else { return .distantPast }
        return isoFormatter.date(from: string) ?? .distantPast
    }

    private func jsonData(from payload: Any) throws -> Data {
        if JSONSerialization.isValidJSONObject(payload) {
            return try JSONSerialization.data(withJSONObject: payload)
        }
        return try encoder.encode(EmptyResponse())
    }

    private func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        return object["message"] as? String
            ?? object["error"] as? String
            ?? object["msg"] as? String
            ?? object["hint"] as? String
    }

    private func isNull(_ value: Any?) -> Bool {
        return value == nil || value is NSNull
    }
}
