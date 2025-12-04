import Foundation

struct Person: Codable, Identifiable {
    let id: Int
    let name: String
    let enabled: Bool
    let territoriesInUse: [TerritoryInUse]
}

struct TerritoryInUse: Codable {
    let territoryName: String
    let territoryCode: String
    let givenDate: Date
}
