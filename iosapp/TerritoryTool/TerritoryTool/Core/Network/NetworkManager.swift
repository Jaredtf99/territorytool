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

    private static let territoryImagesBucket = "territory-images"

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

    /// Explorador de territorios sin pasar por diccionarios.
    ///
    /// El parseo y la decodificación ocurren dentro de `NetworkTransport`, fuera del actor
    /// principal; aquí sólo queda construir los modelos, que es trabajo trivial. El camino
    /// heredado hacía `JSON → [String: Any] → Data → Decodable` **entero en main**, y sobre
    /// este endpoint en concreto eso significa hasta 1000 territorios con toda su geometría.
    func territoryExplorer(
        term: String?,
        filter: TerritoryFilter,
        attentionDays: Int
    ) async throws -> [Territory] {
        let request = try NetworkTransport.makeRequest(
            path: "/rest/v1/rpc/search_territory_explorer",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: [
                "term": term ?? NSNull(),
                "status": filter.backendValue,
                "attention_days": attentionDays,
                "take": 1000
            ])
        )

        let rows = try await NetworkTransport.shared.decoded([TerritoryRowDTO].self, for: request)

        let signedURLs = await signedImageURLs(
            for: rows.compactMap { row in
                // Sólo los territorios sin geometría llegan a usar `imgUrl`.
                guard row.mapGeometry == nil,
                      let path = row.imagePath,
                      !path.isEmpty else {
                    return nil
                }
                return path
            }
        )

        return rows.map { row in
            row.territory(imageURL: row.imagePath.flatMap { signedURLs[$0] })
        }
    }

    private func payload(for endpoint: APIEndpoint) async throws -> Any {
        guard let territoryEndpoint = endpoint as? TerritoryEndpoint else {
            throw NetworkError.invalidURL
        }

        switch territoryEndpoint {
        case .login(let credentials):
            let response = try await SupabaseAuthService.shared.login(username: credentials.userName, password: credentials.password)
            TokenManager.shared.saveSession(
                token: response.token,
                refreshToken: response.session.refreshToken,
                userName: response.profile?.username,
                role: response.profile?.role,
                activeCongregationId: response.profile?.activeCongregationId,
                congregations: response.congregations.flatMap { try? JSONEncoder().encode($0) }
            )
            return ["token": response.token]

        case .getTerritories(let term, let inUse, let orderBy, let ascending, let fromDate, let toDate):
            let rows = try await rpcRows("search_territories", body: [
                "term": term ?? NSNull(),
                "only_free": inUse == false,
                "only_given": inUse == true,
                "take": 1000
            ])
            var territories = await mapTerritories(rows)
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
            return await mapTerritories(rows)

        case .searchQuickAction(let term):
            // Buscador unificado: una sola RPC devuelve territorios y personas mezclados,
            // ya rankeados por score. El `data` viene en crudo; reusamos los mismos
            // mapeos (territorios necesitan firmar la URL de imagen).
            let rows = try await rpcRows("search_quick_action", body: [
                "term": term,
                "take": 20
            ])
            var hits: [[String: Any]] = []
            for row in rows {
                let kind = (row["kind"] as? String) ?? ""
                let score = (row["score"] as? NSNumber)?.doubleValue ?? (row["score"] as? Double) ?? 0
                guard let data = row["data"] as? [String: Any] else { continue }
                if kind == "person" {
                    hits.append(["kind": "person", "score": score, "person": data, "territory": NSNull()])
                } else {
                    let territory = (await mapTerritories([data])).first ?? [:]
                    hits.append(["kind": "territory", "score": score, "territory": territory, "person": NSNull()])
                }
            }
            return hits

        case .getTerritory(let id):
            let row = try await singleRow("/rest/v1/territory_current_state", queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(id)")
            ])
            return (await mapTerritories([row])).first ?? [:]

        case .getTerritoryDetail(let id):
            return try await buildTerritoryDetail(id: id)

        case .getTerritoryDetailBundle(let id):
            return try await buildTerritoryDetailBundle(id: id)

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

        case .getTerritoryReport(let start, let end):
            // Misma consulta que la edge function `generate-territory-report`:
            // movimientos cuya entrega o recogida cae dentro del rango. RLS
            // limita las filas a la congregación activa del JWT.
            let startStr = isoFormatter.string(from: start)
            let endStr = isoFormatter.string(from: end)
            let rows = try await restRows("/rest/v1/territory_details", queryItems: [
                URLQueryItem(name: "select", value: "territory_id,name,code,person_name,given_at,picked_at"),
                URLQueryItem(name: "or", value: "(and(given_at.gte.\(startStr),given_at.lte.\(endStr)),and(picked_at.gte.\(startStr),picked_at.lte.\(endStr)))"),
                URLQueryItem(name: "order", value: "code.asc,given_at.asc")
            ])
            let allTerritories = try await restRows("/rest/v1/territories", queryItems: [
                URLQueryItem(name: "select", value: "id")
            ])
            return [
                "totalTerritories": allTerritories.count,
                "entries": rows.map { row in
                    [
                        "territoryId": row["territory_id"] ?? 0,
                        "code": row["code"] ?? "",
                        "territoryName": row["name"] ?? "",
                        "personName": row["person_name"] ?? NSNull(),
                        "givenAt": row["given_at"] ?? NSNull(),
                        "pickedAt": row["picked_at"] ?? NSNull()
                    ]
                }
            ]

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

        case .giveTerritoryUndoable(let code, let personName, let date):
            return try await rpcObject("give_territory_undoable", body: [
                "territory_code": code,
                "person_name": personName,
                "custom_date": date.map { isoFormatter.string(from: $0) } ?? NSNull()
            ])

        case .pickTerritory(let code, let date):
            return try await rpcObject("pick_territory", body: [
                "territory_code": code,
                "custom_date": date.map { isoFormatter.string(from: $0) } ?? NSNull()
            ])

        case .pickTerritoryUndoable(let code, let date):
            return try await rpcObject("pick_territory_undoable", body: [
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
            guard let territory = await mapTerritories(rows).first else {
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

        case .addPersonUndoable(let name):
            return try await rpcObject("add_person_undoable", body: ["name": name])

        case .updatePerson(let id, let name, let enabled):
            return try await rpcObject("update_person", body: ["person_id": id, "name": name, "enabled": enabled])

        case .updatePersonUndoable(let id, let name, let enabled):
            return try await rpcObject("update_person_undoable", body: ["person_id": id, "name": name, "enabled": enabled])

        case .deletePerson(let name):
            return try await rpcObject("delete_person", body: ["name": name])

        case .deletePersonUndoable(let name):
            return try await rpcObject("delete_person_undoable", body: ["name": name])

        case .addTerritory(let code, let name, let mapUrl):
            return try await rpcObject("add_territory", body: ["code": code, "name": name, "map_url": mapUrl])

        case .addTerritoryUndoable(let code, let name, let mapUrl):
            return try await rpcObject("add_territory_undoable", body: ["code": code, "name": name, "map_url": mapUrl])

        case .updateTerritory(let id, let code, let name, let mapUrl):
            return try await rpcObject("update_territory", body: [
                "territory_id": id,
                "code": code,
                "name": name,
                "map_url": mapUrl
            ])

        case .updateTerritoryUndoable(let id, let code, let name, let mapUrl):
            return try await rpcObject("update_territory_undoable", body: [
                "territory_id": id,
                "code": code,
                "name": name,
                "map_url": mapUrl
            ])

        case .deleteTerritory(let id):
            return try await rpcObject("delete_territory", body: ["territory_id": id])

        case .deleteTerritoryUndoable(let id):
            return try await rpcObject("delete_territory_undoable", body: ["territory_id": id])

        case .undoAction(let id):
            return try await rpcObject("undo_action", body: ["p_undo_id": id])

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

        case .addUserUndoable(let name, let role, let password):
            return try await edgeFunction("admin-users", body: [
                "action": "create-undoable",
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

        case .updateUserUndoable(let id, let name, let role):
            return try await edgeFunction("admin-users", body: [
                "action": "update-undoable",
                "userId": id,
                "username": name,
                "role": role
            ])

        case .deleteUser(let id):
            return try await edgeFunction("admin-users", body: ["action": "delete", "userId": id])

        case .deleteUserUndoable(let id):
            return try await edgeFunction("admin-users", body: ["action": "delete-undoable", "userId": id])

        case .undoUserAction(let id):
            return try await edgeFunction("admin-users", body: ["action": "undo", "undoId": id])

        case .changeUserPassword(let id, let newPassword):
            return try await edgeFunction("admin-users", body: [
                "action": "change-password",
                "userId": id,
                "newPassword": newPassword
            ])

        case .deleteTransaction(let id):
            return try await rpcObject("delete_transaction", body: ["transaction_id": id])

        case .deleteTransactionUndoable(let id):
            return try await rpcObject("delete_transaction_undoable", body: ["transaction_id": id])

        case .updateTransaction(let id, _, let personId, let date, let pickedDate):
            return try await rpcObject("update_transaction", body: [
                "transaction_id": id,
                "person_id": personId ?? NSNull(),
                "given_at": isoFormatter.string(from: date),
                "picked_at": pickedDate.map { isoFormatter.string(from: $0) } ?? NSNull()
            ])

        case .updateTransactionUndoable(let id, _, let personId, let date, let pickedDate):
            return try await rpcObject("update_transaction_undoable", body: [
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

    /// Camino heredado: la respuesta se parsea a diccionarios y se remapea aquí, en main.
    /// Los endpoints que mueven volumen usan `decoded(_:for:)` del transporte y se saltan
    /// este viaje entero.
    private func requestJSON(path: String, method: String, queryItems: [URLQueryItem] = [], body: Any? = nil) async throws -> Any {
        let request = try NetworkTransport.makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: try body.map { try JSONSerialization.data(withJSONObject: $0) }
        )
        let data = try await NetworkTransport.shared.data(for: request)

        if data.isEmpty {
            return [:]
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func buildTerritoryDetail(id: Int) async throws -> [String: Any] {
        async let stateRow = territoryStateRow(id: id)
        async let historyRows = territoryHistoryRows(id: id)
        return try await territoryDetailPayload(state: stateRow, history: historyRows, id: id)
    }

    /// Detalle, estadísticas y transacciones en una sola llamada del ViewModel.
    ///
    /// Antes la pantalla encadenaba `getTerritoryDetail` + `getTerritoryStats` +
    /// `getTerritoryTransactions`, y `getTerritoryDetail` pedía a su vez dos recursos: eran
    /// cuatro viajes en serie **y** `territory_details` se descargaba dos veces, una para la
    /// línea de tiempo y otra para las transacciones. Aquí el historial se pide una sola vez
    /// y las tres consultas se solapan.
    private func buildTerritoryDetailBundle(id: Int) async throws -> [String: Any] {
        async let stateRow = territoryStateRow(id: id)
        async let historyRows = territoryHistoryRows(id: id)
        async let statsRow = rpcObject("get_territory_statistics", body: ["territory_id": id])

        let state = try await stateRow
        let history = try await historyRows
        let stats = try await statsRow

        return [
            "territory": await territoryDetailPayload(state: state, history: history, id: id),
            "stats": mapStatistics(stats),
            "transactions": mapTransactions(history)
        ]
    }

    private func territoryStateRow(id: Int) async throws -> [String: Any] {
        try await singleRow("/rest/v1/territory_current_state", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.\(id)")
        ])
    }

    private func territoryHistoryRows(id: Int) async throws -> [[String: Any]] {
        try await restRows("/rest/v1/territory_details", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "territory_id", value: "eq.\(id)"),
            URLQueryItem(name: "order", value: "given_at.desc")
        ])
    }

    private func territoryDetailPayload(
        state: [String: Any],
        history: [[String: Any]],
        id: Int
    ) async -> [String: Any] {
        let territory = (await mapTerritories([state])).first ?? [:]
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

    private func mapTerritories(_ rows: [[String: Any]]) async -> [[String: Any]] {
        let signedURLs = await signedImageURLs(for: imagePathsNeedingSignature(in: rows))

        return rows.map { row in
            let imagePath = row["image_path"] as? String
            return [
                "id": row["id"] ?? 0,
                "code": row["code"] ?? "",
                "name": row["name"] ?? "",
                "mapUrl": row["map_url"] ?? "",
                "imgUrl": imagePath.flatMap { signedURLs[$0] } ?? NSNull(),
                "personName": row["person_name"] ?? NSNull(),
                "givenDateUtc": row["given_at"] ?? NSNull(),
                "lastPickedDateUtc": row["last_picked_at"] ?? NSNull(),
                "mapGeometry": row["map_geometry"] ?? NSNull()
            ]
        }
    }

    /// Rutas de imagen que merece la pena firmar.
    ///
    /// Sólo las de territorios **sin** geometría: cuando hay geometría, las vistas dibujan
    /// el snapshot del polígono y nunca llegan a mirar `imgUrl` (es la rama `else` de
    /// `TerritoryExplorerRow.mapBackdrop`, `TerritoryCard` y `QuickActionConfirmView`).
    /// Antes se firmaba una por una, en serie y con `await`, también las que se descartaban:
    /// con 60 territorios eran 60 viajes de ida y vuelta antes de poder pintar la lista.
    private func imagePathsNeedingSignature(in rows: [[String: Any]]) -> [String] {
        rows.compactMap { row in
            guard isNull(row["map_geometry"]),
                  let path = row["image_path"] as? String,
                  !path.isEmpty else {
                return nil
            }
            return path
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

    /// Firma en una sola petición todas las rutas que no estén ya en caché.
    ///
    /// El endpoint de lote responde con un array de `{path, signedURL, error}` y **puede
    /// devolver HTTP 200 con entradas fallidas dentro**, así que cada una se comprueba por
    /// separado. Un fallo de firma deja esa imagen sin URL en lugar de tumbar la carga
    /// entera de la lista, que es lo que ocurría cuando se firmaban de una en una.
    private func signedImageURLs(for paths: [String]) async -> [String: String] {
        var result: [String: String] = [:]
        var pending: [String] = []

        for path in Set(paths) {
            if let cached = SignedImageURLCache.shared.url(forPath: path, bucket: Self.territoryImagesBucket) {
                result[path] = cached
            } else {
                pending.append(path)
            }
        }

        guard !pending.isEmpty else { return result }

        let response = try? await requestJSON(
            path: "/storage/v1/object/sign/\(Self.territoryImagesBucket)",
            method: "POST",
            body: ["expiresIn": 3600, "paths": pending]
        )
        guard let entries = response as? [[String: Any]] else { return result }

        for entry in entries {
            guard isNull(entry["error"]),
                  let path = entry["path"] as? String,
                  let signed = entry["signedURL"] as? String ?? entry["signedUrl"] as? String else {
                continue
            }
            let absolute = absoluteStorageURL(signed)
            result[path] = absolute
            SignedImageURLCache.shared.store(absolute, forPath: path, bucket: Self.territoryImagesBucket)
        }

        return result
    }

    /// El endpoint de firma devuelve una ruta relativa a la raíz de la API de Storage
    /// (p. ej. "/object/sign/territory-images/...?token=..."), así que necesita el prefijo
    /// "/storage/v1" para formar una URL alcanzable.
    private func absoluteStorageURL(_ signed: String) -> String {
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
