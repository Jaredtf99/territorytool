import Foundation
import SwiftUI

struct DashboardSnapshot: Decodable {
    let generatedAt: Date
    let totals: DashboardTotals
    let priority: DashboardPriority?
    let activity: [DashboardDailyActivity]
    let weeklyEvents: [DashboardMovement]
    let recentEvents: [DashboardMovement]
    let hasMoreRecentEvents: Bool
    let attentionTerritories: [DashboardAttentionTerritory]
}

struct DashboardTotals: Decodable {
    let total: Int
    let free: Int
    let inUse: Int
    let givenThisWeek: Int
}

struct DashboardPriority: Decodable {
    let territoryId: Int
    let code: String
    let name: String
    let personId: Int
    let personName: String
    let givenAt: Date
    let mapUrl: String
    let imagePath: String?
    let mapGeometry: TerritoryMapGeometry?

    var territory: Territory {
        Territory(
            id: territoryId,
            code: code,
            name: name,
            mapUrl: mapUrl,
            imgUrl: nil,
            personName: personName,
            givenDateUtc: givenAt,
            lastPickedDateUtc: nil,
            mapGeometry: mapGeometry
        )
    }
}

struct DashboardDailyActivity: Decodable, Identifiable {
    let date: Date
    let givenCount: Int
    let returnedCount: Int

    var id: Date { date }

    private enum CodingKeys: String, CodingKey {
        case date, givenCount, returnedCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawDate = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let parsed = formatter.date(from: rawDate) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Invalid dashboard activity date: \(rawDate)"
            )
        }
        date = parsed
        givenCount = try container.decode(Int.self, forKey: .givenCount)
        returnedCount = try container.decode(Int.self, forKey: .returnedCount)
    }
}

enum DashboardMovementType: String, Decodable, Hashable {
    case given
    case returned
}

struct DashboardMovement: Decodable, Identifiable, Hashable {
    let transactionId: Int
    let eventType: DashboardMovementType
    let eventDate: Date
    let territoryId: Int
    let territoryCode: String
    let territoryName: String
    let personId: Int
    let personName: String
    let givenAt: Date
    let pickedAt: Date?
    let actorName: String

    var id: String { "\(transactionId)-\(eventType.rawValue)" }

    var transaction: Transaction {
        Transaction(
            id: transactionId,
            personId: personId,
            givenDateUtc: givenAt,
            pickedDateUtc: pickedAt,
            givenBy: eventType == .given ? actorName : nil,
            pickedBy: eventType == .returned ? actorName : nil,
            territoryId: territoryId,
            territoryName: territoryName,
            personName: personName
        )
    }
}

enum MovementHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case given
    case returned

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "movements.filter.all"
        case .given: "movements.filter.given"
        case .returned: "movements.filter.returned"
        }
    }
}

enum MovementHistorySort: String, CaseIterable, Identifiable {
    case newest
    case oldest

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .newest: "movements.sort.newest"
        case .oldest: "movements.sort.oldest"
        }
    }

    var ascending: Bool { self == .oldest }
}

struct DashboardMapBounds: Decodable, Hashable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double

    var latitude: Double { (south + north) / 2 }
    var longitude: Double { (west + east) / 2 }
}

struct DashboardAttentionTerritory: Decodable, Identifiable, Hashable {
    let territoryId: Int
    let code: String
    let name: String
    let personName: String
    let givenAt: Date
    let mapBounds: DashboardMapBounds?

    var id: Int { territoryId }
}
