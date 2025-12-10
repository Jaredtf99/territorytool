import Foundation

struct Person: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let enabled: Bool
    let territoriesInUse: [TerritoryInUse]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, enabled, territoriesInUse
        case Id, Name, Enabled, TerritoriesInUse
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try camelCase first, then PascalCase
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? container.decode(Int.self, forKey: .Id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? container.decode(String.self, forKey: .Name)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? container.decode(Bool.self, forKey: .Enabled)
        territoriesInUse = try container.decodeIfPresent([TerritoryInUse].self, forKey: .territoriesInUse) ?? container.decodeIfPresent([TerritoryInUse].self, forKey: .TerritoriesInUse)
    }
    
    // Default init for creating instances manually if needed
    init(id: Int, name: String, enabled: Bool, territoriesInUse: [TerritoryInUse]?) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.territoriesInUse = territoriesInUse
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(territoriesInUse, forKey: .territoriesInUse)
    }
}

struct TerritoryInUse: Codable, Equatable {
    let territoryName: String
    let territoryCode: String
    let givenDate: Date
    
    enum CodingKeys: String, CodingKey {
        case territoryName, territoryCode, givenDate
        case TerritoryName, TerritoryCode, GivenDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        territoryName = try container.decodeIfPresent(String.self, forKey: .territoryName) ?? container.decode(String.self, forKey: .TerritoryName)
        territoryCode = try container.decodeIfPresent(String.self, forKey: .territoryCode) ?? container.decode(String.self, forKey: .TerritoryCode)
        givenDate = try container.decodeIfPresent(Date.self, forKey: .givenDate) ?? container.decode(Date.self, forKey: .GivenDate)
    }
    
    init(territoryName: String, territoryCode: String, givenDate: Date) {
        self.territoryName = territoryName
        self.territoryCode = territoryCode
        self.givenDate = givenDate
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(territoryName, forKey: .territoryName)
        try container.encode(territoryCode, forKey: .territoryCode)
        try container.encode(givenDate, forKey: .givenDate)
    }
}
