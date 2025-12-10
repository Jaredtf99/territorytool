import Foundation

struct ActionLog: Codable, Identifiable {
    let id = UUID() // Local ID for SwiftUI
    let type: ActionType
    let dateUtc: Date
    let userName: String?
    let message: String?
    let successful: Bool
    
    enum CodingKeys: String, CodingKey {
        case type, dateUtc, userName, message, successful
        // PascalCase keys
        case typePascal = "Type"
        case dateUtcPascal = "DateUtc"
        case userNamePascal = "UserName"
        case messagePascal = "Message"
        case successfulPascal = "Successful"
        // Alternative keys for Type
        case actionType = "actionType"
        case actionTypePascal = "ActionType"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try multiple variations for Type key
        if let t = try container.decodeIfPresent(ActionType.self, forKey: .type) {
            type = t
        } else if let t = try container.decodeIfPresent(ActionType.self, forKey: .typePascal) {
            type = t
        } else if let t = try container.decodeIfPresent(ActionType.self, forKey: .actionType) {
            type = t
        } else if let t = try container.decodeIfPresent(ActionType.self, forKey: .actionTypePascal) {
            type = t
        } else {
             // Fallback instead of throwing to prevent app crash on one bad log
             type = .unknown
        }

        dateUtc = try container.decodeIfPresent(Date.self, forKey: .dateUtc) ?? container.decode(Date.self, forKey: .dateUtcPascal)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? container.decodeIfPresent(String.self, forKey: .userNamePascal)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? container.decodeIfPresent(String.self, forKey: .messagePascal)
        successful = try container.decodeIfPresent(Bool.self, forKey: .successful) ?? container.decode(Bool.self, forKey: .successfulPascal)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(dateUtc, forKey: .dateUtc)
        try container.encode(userName, forKey: .userName)
        try container.encode(message, forKey: .message)
        try container.encode(successful, forKey: .successful)
    }
    
    // Default initializer for preview/testing
    init(type: ActionType, dateUtc: Date, userName: String?, message: String?, successful: Bool) {
        self.type = type
        self.dateUtc = dateUtc
        self.userName = userName
        self.message = message
        self.successful = successful
    }
}

enum ActionType: String, Codable {
    // Values match backend C# enum (PascalCase via StringEnumConverter)
    case unknown = "Unknown"
    case addTerritory = "AddTerritory"
    case editTerritory = "EditTerritory"
    case deleteTerritory = "DeleteTerritory"
    case addUser = "AddUser"
    case deleteUser = "DeleteUser"
    case changeUserPassword = "ChangeUserPassword"
    case editUser = "EditUser"
    case addPerson = "AddPerson"
    case editPerson = "EditPerson"
    case deletePerson = "DeletePerson"
    case giveTerritory = "GiveTerritory"
    case pickTerritory = "PickTerritory"
    case refreshTerritoryImage = "RefreshTerritoryImage"
    case editTransaction = "EditTransaction"
    case deleteTransaction = "DeleteTransaction"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try String
        if let stringValue = try? container.decode(String.self) {
            if let type = ActionType(rawValue: stringValue) {
                self = type
                return
            }
        }
        
        // Fallback
        self = .unknown
    }
}
