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

enum TerritoryOperationalStatus: Equatable {
    case available
    case assigned(days: Int)
    case attention(days: Int)

    var isAssigned: Bool {
        switch self {
        case .available: false
        case .assigned, .attention: true
        }
    }

    var daysAssigned: Int? {
        switch self {
        case .available: nil
        case .assigned(let days), .attention(let days): days
        }
    }
}

extension Territory {
    func operationalStatus(
        attentionDays: Int = 90,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TerritoryOperationalStatus {
        guard personName != nil else { return .available }
        guard let givenDateUtc else { return .assigned(days: 0) }
        let days = max(calendar.dateComponents([.day], from: givenDateUtc, to: now).day ?? 0, 0)
        return days >= attentionDays ? .attention(days: days) : .assigned(days: days)
    }
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

/// Todo lo que necesita la pantalla de detalle, en una sola respuesta.
///
/// Existe para que el ViewModel no encadene tres peticiones que, además, hacían que el
/// historial (`territory_details`) se descargara dos veces.
struct TerritoryDetailBundle: Codable {
    let territory: TerritoryDetail
    let stats: TerritoryStatistics
    let transactions: [Transaction]
}

nonisolated struct TerritoryMapGeometry: Codable, Equatable, Sendable {
    let version: Int
    let bounds: TerritoryMapBounds
    let polygons: [TerritoryMapFeature]
    let polylines: [TerritoryMapFeature]
    let markers: [TerritoryMapMarker]
}

nonisolated struct TerritoryMapBounds: Codable, Equatable, Sendable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
}

nonisolated struct TerritoryMapCoordinate: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

nonisolated struct TerritoryMapFeature: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String?
    let description: String?
    let coordinates: [TerritoryMapCoordinate]
}

nonisolated struct TerritoryMapMarker: Codable, Identifiable, Equatable, Sendable {
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
