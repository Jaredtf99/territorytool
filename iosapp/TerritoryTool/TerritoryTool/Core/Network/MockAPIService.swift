import Foundation

class MockAPIService: APIService {
    func request<T>(endpoint: APIEndpoint) async throws -> T where T : Decodable {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        switch endpoint {
        case let territoryEndpoint as TerritoryEndpoint:
            switch territoryEndpoint {
            case .getTerritoryDetail(let id):
                return TerritoryDetail(
                    id: id,
                    code: "T-10\(id)",
                    name: "Downtown Sector \(id)",
                    mapUrl: "https://example.com/map",
                    imgUrl: nil,
                    personName: id % 2 == 0 ? "John Doe" : nil,
                    lastPickedDateUtc: Date().addingTimeInterval(-86400 * 5),
                    givenDateUtc: id % 2 == 0 ? Date().addingTimeInterval(-86400 * 2) : nil,
                    pickedCount: 15,
                    lastUser: "Jane Smith",
                    timelineItems: [
                        TimelineItem(id: 1, description: "Picked by John", type: .picked, date: Date().addingTimeInterval(-86400 * 2)),
                        TimelineItem(id: 2, description: "Returned by Jane", type: .gave, date: Date().addingTimeInterval(-86400 * 5)),
                        TimelineItem(id: 3, description: "Created", type: .added, date: Date().addingTimeInterval(-86400 * 30))
                    ],
                    mapGeometry: nil
                ) as! T
                
            case .getTerritoryStats:
                return TerritoryStatistics(
                    totalTerritories: 50,
                    usageRank: 5,
                    isHighUsage: true,
                    isLowUsage: false,
                    assignedTimePercentage: 75.5,
                    globalAverageAssignedTimePercentage: 60.0,
                    averageReassignmentTime: 12.0,
                    globalAverageReassignmentTime: 15.0,
                    averageHoldingTime: 45.0,
                    globalAverageHoldingTime: 30.0,
                    currentUnassignedTime: 2.0,
                    uniqueUsersCount: 10,
                    globalAverageUniqueUsersCount: 5.5
                ) as! T
                
            case .getTerritoryTransactions:
                return [
                    Transaction(
                        id: 1,
                        personId: 101,
                        givenDateUtc: Date().addingTimeInterval(-86400 * 2),
                        pickedDateUtc: nil,
                        givenBy: "Admin",
                        pickedBy: nil,
                        territoryId: 1,
                        territoryName: "Downtown Sector 1",
                        personName: "John Doe"
                    ),
                    Transaction(
                        id: 2,
                        personId: 102,
                        givenDateUtc: Date().addingTimeInterval(-86400 * 10),
                        pickedDateUtc: Date().addingTimeInterval(-86400 * 5),
                        givenBy: "Admin",
                        pickedBy: "Admin",
                        territoryId: 1,
                        territoryName: "Downtown Sector 1",
                        personName: "Jane Smith"
                    )
                ] as! T
                
            case .getPersons:
                return [
                    Person(id: 1, name: "Alice Johnson", enabled: true, territoriesInUse: []),
                    Person(id: 2, name: "Bob Williams", enabled: true, territoriesInUse: []),
                    Person(id: 3, name: "Charlie Brown", enabled: true, territoriesInUse: [])
                ] as! T
                
            case .giveTerritory:
                return EmptyResponse() as! T
                
            default:
                fatalError("Mock not implemented for \(endpoint)")
            }
        default:
            fatalError("Mock not implemented for \(endpoint)")
        }
    }
    func request(endpoint: APIEndpoint) async throws {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // For void requests, we just simulate success unless we want to mock errors
        switch endpoint {
        case let territoryEndpoint as TerritoryEndpoint:
            switch territoryEndpoint {
            case .giveTerritory, .pickTerritory:
                return // Success
            default:
                fatalError("Mock not implemented for \(endpoint)")
            }
        default:
            fatalError("Mock not implemented for \(endpoint)")
        }
    }
}
