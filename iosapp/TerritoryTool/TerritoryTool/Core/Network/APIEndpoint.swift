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

enum TerritoryEndpoint: APIEndpoint {
    case getTerritory(id: Int)
    case getTerritoryDetail(id: Int)
    case getTerritoryStats(id: Int)
    case getTerritoryTransactions(id: Int)
    case giveTerritory(code: String, personName: String, date: Date?)
    case pickTerritory(code: String, date: Date?)
    case getPersons(search: String?)
    case login(credentials: LoginCredentials)
    case getTerritories(term: String?, inUse: Bool?, orderBy: Int?, orderByAscending: Bool?, lastGivenDateFrom: Date?, lastGivenDateTo: Date?)
    case refreshTerritoryImage(id: Int)
    case deleteTerritory(id: Int)
    case addPerson(name: String)
    case addTerritory(code: String, name: String, mapUrl: String)
    case updatePerson(id: Int, name: String, enabled: Bool)
    case deletePerson(name: String)
    case updateTerritory(id: Int, code: String, name: String, mapUrl: String)
    
    var path: String {
        switch self {
        case .getTerritory(let id):
            return "/api/v1/territories/\(id)"
        case .getTerritoryDetail(let id):
            return "/api/v1/territories/\(id)/detail"
        case .getTerritoryStats(let id):
            return "/api/v1/territories/\(id)/statistics"
        case .getTerritoryTransactions(let id):
            return "/api/v1/territories/\(id)/transactions"
        case .giveTerritory:
            return "/api/v1/territories/give-territory"
        case .pickTerritory:
            return "/api/v1/territories/pick-territory"
        case .getPersons(let search):
            if let search = search, !search.isEmpty, let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                return "/api/v1/persons/\(encoded)"
            }
            return "/api/v1/persons"
        case .addPerson:
            return "/api/v1/persons"
        case .updatePerson(let id, _, _):
            return "/api/v1/persons/\(id)"
        case .deletePerson(let name):
            if let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                return "/api/v1/persons/\(encoded)"
            }
            return "/api/v1/persons/\(name)"
        case .login:
            return "/api/v1/users/login"
        case .getTerritories:
            return "/api/v1/territories/all"
        case .refreshTerritoryImage(let id):
            return "/api/v1/territories/\(id)/refresh-image"
        case .deleteTerritory(let id), .updateTerritory(let id, _, _, _):
            return "/api/v1/territories/\(id)"
        case .addTerritory:
            return "/api/v1/territories"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getTerritory, .getTerritoryDetail, .getTerritoryStats, .getTerritoryTransactions, .getPersons, .getTerritories:
            return .GET
        case .giveTerritory, .pickTerritory, .login, .refreshTerritoryImage, .addPerson, .updateTerritory, .addTerritory:
            return .POST
        case .updatePerson:
            return .PUT
        case .deleteTerritory, .deletePerson:
            return .DELETE
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
        default:
            return nil
        }
    }
}
