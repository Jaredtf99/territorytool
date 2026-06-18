import Foundation

struct Territory: Codable, Identifiable, Equatable {
    let id: Int
    let code: String
    let name: String
    let mapUrl: String
    let imgUrl: String?
    let personName: String?
    let givenDateUtc: Date?
    let lastPickedDateUtc: Date?
    let mapGeometry: TerritoryMapGeometry?
}

struct TerritoryDetail: Codable, Identifiable {
    let id: Int
    let code: String
    let name: String
    let mapUrl: String
    let imgUrl: String?
    let personName: String?
    let lastPickedDateUtc: Date?
    let givenDateUtc: Date?
    let pickedCount: Int
    let lastUser: String?
    let timelineItems: [TimelineItem]
    let mapGeometry: TerritoryMapGeometry?
}

struct TerritoryMapGeometry: Codable, Equatable {
    let version: Int
    let bounds: TerritoryMapBounds
    let polygons: [TerritoryMapFeature]
    let polylines: [TerritoryMapFeature]
    let markers: [TerritoryMapMarker]
}

struct TerritoryMapBounds: Codable, Equatable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
}

struct TerritoryMapCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct TerritoryMapFeature: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let description: String?
    let coordinates: [TerritoryMapCoordinate]
}

struct TerritoryMapMarker: Codable, Identifiable, Equatable {
    let id: String
    let title: String?
    let description: String?
    let latitude: Double
    let longitude: Double
}

struct TerritoryStatistics: Codable {
    let totalTerritories: Int
    let usageRank: Int
    let isHighUsage: Bool
    let isLowUsage: Bool
    let assignedTimePercentage: Double
    let globalAverageAssignedTimePercentage: Double
    let averageReassignmentTime: Double
    let globalAverageReassignmentTime: Double
    let averageHoldingTime: Double
    let globalAverageHoldingTime: Double
    let currentUnassignedTime: Double
    let uniqueUsersCount: Int
    let globalAverageUniqueUsersCount: Double
}

struct TimelineItem: Codable, Identifiable {
    let id: Int
    let description: String
    let type: TimelineType
    let date: Date
}

enum TimelineType: Int, Codable {
    case picked = 1
    case gave = 2
    case edited = 3
    case added = 4
}
