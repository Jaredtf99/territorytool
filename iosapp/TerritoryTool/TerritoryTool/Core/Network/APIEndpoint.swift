import Foundation

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
    var queryItems: [URLQueryItem]? { get }
}

extension APIEndpoint {
    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
    
    var body: Data? {
        return nil
    }
    
    var queryItems: [URLQueryItem]? {
        return nil
    }
}

// Helper function to convert role string to backend enum integer
// Backend RoleType: Unknown=0, SUPERADMIN=1, ADMIN=2, USER=3
private func roleStringToInt(_ role: String) -> Int {
    switch role.uppercased() {
    case "SUPERADMIN": return 1
    case "ADMIN": return 2
    case "USER": return 3
    default: return 0 // Unknown
    }
}

enum TerritoryEndpoint: APIEndpoint {
    case getTerritory(id: Int)
    case getTerritoryDetail(id: Int)
    case getTerritoryStats(id: Int)
    case getTerritoryTransactions(id: Int)
    case giveTerritory(code: String, personName: String, date: Date?)
    case pickTerritory(code: String, date: Date?)
    case getPersons(search: String?)
    case getPersonsWithAssignments(search: String?)
    case resolveTerritorySelector(value: String)
    case getDashboardSnapshot(weekStart: Date, timeZone: String, attentionDays: Int)
    case login(credentials: LoginCredentials)
    case getTerritories(term: String?, inUse: Bool?, orderBy: Int?, orderByAscending: Bool?, lastGivenDateFrom: Date?, lastGivenDateTo: Date?)
    case getTerritoryExplorer(term: String?, filter: TerritoryFilter, attentionDays: Int)
    case refreshTerritoryImage(id: Int)
    case syncTerritoryMap(id: Int)
    case syncAllTerritoryMaps
    case deleteTerritory(id: Int)
    case addPerson(name: String)
    case addTerritory(code: String, name: String, mapUrl: String)
    case updatePerson(id: Int, name: String, enabled: Bool)
    case deletePerson(name: String)
    case updateTerritory(id: Int, code: String, name: String, mapUrl: String)
    case getUsers
    case addUser(name: String, role: String, password: String)
    case updateUser(id: String, name: String, role: String)
    case deleteUser(id: String)
    case changeUserPassword(id: String, newPassword: String)
    case getRecentTransactions(days: Int)
    case getActionLogs(page: Int, pageSize: Int, sortField: String, sortOrder: String)
    case deleteTransaction(id: Int)
    case updateTransaction(id: Int, territoryId: Int, personId: Int?, date: Date, pickedDate: Date?)
    
    var path: String {
        return ""
    }
    
    var method: HTTPMethod {
        switch self {
        case .getTerritory, .getTerritoryDetail, .getTerritoryStats, .getTerritoryTransactions,
             .getPersons, .getPersonsWithAssignments, .resolveTerritorySelector,
             .getDashboardSnapshot, .getTerritories, .getTerritoryExplorer:
            return .GET
        case .giveTerritory, .pickTerritory, .login, .refreshTerritoryImage, .syncTerritoryMap, .syncAllTerritoryMaps, .addPerson, .updateTerritory, .addTerritory:
            return .POST
        case .updatePerson:
            return .PUT
        case .deleteTerritory, .deletePerson, .deleteUser:
            return .DELETE
        case .addUser, .updateUser, .changeUserPassword:
             return .POST
        case .getUsers, .getRecentTransactions, .getActionLogs:
            return .GET
        case .deleteTransaction:
            return .DELETE
        case .updateTransaction:
            return .PUT
        }
    }
    
    var body: Data? {
        switch self {
        case .giveTerritory(let code, let personName, let date):
            let params: [String: Any] = [
                "territoryCode": code,
                "personName": personName,
                "isCustomDate": date != nil,
                "customDate": date.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .pickTerritory(let code, let date):
            let params: [String: Any] = [
                "territoryCode": code,
                "isCustomDate": date != nil,
                "customDate": date.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .addPerson(let name):
            let params: [String: Any] = ["name": name]
            return try? JSONSerialization.data(withJSONObject: params)
        case .updatePerson(_, let name, let enabled):
            let params: [String: Any] = [
                "name": name,
                "enabled": enabled
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .login(let credentials):
            return try? JSONEncoder().encode(credentials)
        case .updateTerritory(_, let code, let name, let mapUrl):
            let params: [String: Any] = [
                "code": code,
                "name": name,
                "mapUrl": mapUrl
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .addTerritory(let code, let name, let mapUrl):
            let params: [String: Any] = [
                "code": code,
                "name": name,
                "mapUrl": mapUrl
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .addUser(let name, let role, let password):
            // Backend expects PascalCase keys and Role as integer enum
            let roleInt = roleStringToInt(role)
            let params: [String: Any] = [
                "UserName": name,
                "Role": roleInt,
                "Password": password
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .updateUser(_, let name, let role):
            // Backend expects PascalCase keys and Role as integer enum
            let roleInt = roleStringToInt(role)
            let params: [String: Any] = [
                "UserName": name,
                "Role": roleInt
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .changeUserPassword(_, let newPassword):
            let params: [String: Any] = [
                "NewPassword": newPassword
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        case .getUsers, .deleteUser, .deleteTransaction,
             .getPersonsWithAssignments, .resolveTerritorySelector, .getDashboardSnapshot:
            return nil
        case .updateTransaction(_, let territoryId, let personId, let date, let pickedDate):
            // Use a properly configured date formatter
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            var params: [String: Any] = [
                "territoryId": territoryId,
                "givenDateUtc": dateFormatter.string(from: date)
            ]
            
            if let personId = personId {
                params["personId"] = personId
            }
            
            if let pickedDate = pickedDate {
                params["pickedDateUtc"] = dateFormatter.string(from: pickedDate)
            } else {
                params["pickedDateUtc"] = NSNull()
            }
            
            return try? JSONSerialization.data(withJSONObject: params)
        default:
            return nil
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {

        case .getTerritories(let term, let inUse, let orderBy, let orderByAscending, let lastGivenDateFrom, let lastGivenDateTo):
            var items: [URLQueryItem] = []
            if let term = term { items.append(URLQueryItem(name: "term", value: term)) }
            if let inUse = inUse { items.append(URLQueryItem(name: "inUse", value: String(inUse))) }
            if let orderBy = orderBy { items.append(URLQueryItem(name: "orderBy", value: String(orderBy))) }
            if let orderByAscending = orderByAscending { items.append(URLQueryItem(name: "orderByAscending", value: String(orderByAscending))) }
            let formatter = ISO8601DateFormatter()
            if let lastGivenDateFrom = lastGivenDateFrom { items.append(URLQueryItem(name: "lastGivenDateFrom", value: formatter.string(from: lastGivenDateFrom))) }
            if let lastGivenDateTo = lastGivenDateTo { items.append(URLQueryItem(name: "lastGivenDateTo", value: formatter.string(from: lastGivenDateTo))) }
            return items.isEmpty ? nil : items
        case .getTerritoryExplorer(let term, let filter, let attentionDays):
            var items = [
                URLQueryItem(name: "status", value: filter.backendValue),
                URLQueryItem(name: "attentionDays", value: String(attentionDays))
            ]
            if let term { items.append(URLQueryItem(name: "term", value: term)) }
            return items
        case .getRecentTransactions(let days):
            return [URLQueryItem(name: "days", value: String(days))]
        case .getActionLogs(let page, let pageSize, let sortField, let sortOrder):
             return [
                 URLQueryItem(name: "pageNumber", value: String(page)),
                 URLQueryItem(name: "pageSize", value: String(pageSize)),
                 URLQueryItem(name: "sortField", value: sortField),
                 URLQueryItem(name: "sortOrder", value: sortOrder)
             ]
        default:
            return nil
        }
    }
}
