import Foundation

/// Ficha de hermano devuelta por la RPC `get_person_detail` (JSON en camelCase).
struct PersonDetail: Decodable, Equatable {
    let person: PersonDetailProfile
    let summary: PersonDetailSummary
    let current: [PersonCurrentAssignment]
    let activity: [PersonMonthlyActivity]
    let topTerritories: [PersonTopTerritory]
    let history: [PersonAssignment]

    enum CodingKeys: String, CodingKey {
        case person, summary, current, activity, topTerritories, history
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        person = try c.decode(PersonDetailProfile.self, forKey: .person)
        summary = try c.decode(PersonDetailSummary.self, forKey: .summary)
        current = try c.decodeIfPresent([PersonCurrentAssignment].self, forKey: .current) ?? []
        activity = try c.decodeIfPresent([PersonMonthlyActivity].self, forKey: .activity) ?? []
        topTerritories = try c.decodeIfPresent([PersonTopTerritory].self, forKey: .topTerritories) ?? []
        history = try c.decodeIfPresent([PersonAssignment].self, forKey: .history) ?? []
    }

    /// `Person` mínimo para reutilizar flujos que lo esperan (Acción rápida).
    var asPerson: Person {
        Person(
            id: person.id,
            name: person.name,
            enabled: person.enabled,
            territoriesInUse: current.map {
                TerritoryInUse(
                    territoryId: $0.territoryId,
                    territoryName: $0.territoryName,
                    territoryCode: $0.territoryCode,
                    givenDate: $0.givenAt
                )
            }
        )
    }
}

struct PersonDetailProfile: Decodable, Equatable {
    let id: Int
    let name: String
    let enabled: Bool
    let createdAt: Date?
}

struct PersonDetailSummary: Decodable, Equatable {
    let totalAssignments: Int
    let activeAssignments: Int
    let completedAssignments: Int
    let uniqueTerritories: Int
    let virtualAssignments: Int
    let averageHoldingDays: Double?
    let congregationAverageHoldingDays: Double?
    let longestHoldingDays: Int?
    let firstAssignmentAt: Date?
    let lastAssignmentAt: Date?
    let lastReturnAt: Date?
    let assignmentsLastYear: Int
    let activityRank: Int?
    let activePersonsCount: Int

    /// Última actividad (entrega o devolución, la más reciente).
    var lastActivityAt: Date? {
        [lastAssignmentAt, lastReturnAt].compactMap { $0 }.max()
    }

    /// Días de diferencia con la media de la congregación (positivo = devuelve más tarde).
    var holdingDelta: Int? {
        guard let averageHoldingDays, let congregationAverageHoldingDays, completedAssignments > 0 else { return nil }
        return Int((averageHoldingDays - congregationAverageHoldingDays).rounded())
    }
}

struct PersonCurrentAssignment: Decodable, Equatable, Identifiable {
    let transactionId: Int
    let territoryId: Int
    let territoryCode: String
    let territoryName: String
    let givenAt: Date
    let days: Int
    let deliveryFormat: DeliveryFormat
    let givenBy: String?
    let mapGeometry: TerritoryMapGeometry?

    var id: Int { transactionId }

    enum CodingKeys: String, CodingKey {
        case transactionId, territoryId, territoryCode, territoryName, givenAt, days, deliveryFormat, givenBy, mapGeometry
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        transactionId = try c.decode(Int.self, forKey: .transactionId)
        territoryId = try c.decode(Int.self, forKey: .territoryId)
        territoryCode = try c.decode(String.self, forKey: .territoryCode)
        territoryName = try c.decode(String.self, forKey: .territoryName)
        givenAt = try c.decode(Date.self, forKey: .givenAt)
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        deliveryFormat = (try? c.decodeIfPresent(DeliveryFormat.self, forKey: .deliveryFormat)) ?? .physical
        givenBy = try c.decodeIfPresent(String.self, forKey: .givenBy)
        // Una geometría corrupta no debe tumbar la ficha entera.
        mapGeometry = try? c.decodeIfPresent(TerritoryMapGeometry.self, forKey: .mapGeometry)
    }
}

struct PersonMonthlyActivity: Decodable, Equatable, Identifiable {
    /// Primer día del mes, en la zona horaria del dispositivo.
    let month: Date
    let givenCount: Int
    let returnedCount: Int

    var id: Date { month }

    enum CodingKeys: String, CodingKey { case month, givenCount, returnedCount }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `YYYY-MM-DD` sin hora: se interpreta en local para no saltar de mes.
        let raw = try c.decode(String.self, forKey: .month)
        guard let date = Self.monthFormatter.date(from: raw) else {
            throw DecodingError.dataCorruptedError(forKey: .month, in: c, debugDescription: "Invalid month \(raw)")
        }
        month = date
        givenCount = try c.decodeIfPresent(Int.self, forKey: .givenCount) ?? 0
        returnedCount = try c.decodeIfPresent(Int.self, forKey: .returnedCount) ?? 0
    }

    init(month: Date, givenCount: Int, returnedCount: Int) {
        self.month = month
        self.givenCount = givenCount
        self.returnedCount = returnedCount
    }
}

struct PersonTopTerritory: Decodable, Equatable, Identifiable {
    let territoryId: Int
    let territoryCode: String
    let territoryName: String
    let times: Int
    let totalDays: Int
    let lastGivenAt: Date?

    var id: Int { territoryId }
}

struct PersonAssignment: Decodable, Equatable, Identifiable {
    let transactionId: Int
    let territoryId: Int
    let territoryCode: String
    let territoryName: String
    let givenAt: Date
    let pickedAt: Date?
    let days: Int
    let deliveryFormat: DeliveryFormat
    let givenBy: String?
    let pickedBy: String?

    var id: Int { transactionId }
    var isOngoing: Bool { pickedAt == nil }

    enum CodingKeys: String, CodingKey {
        case transactionId, territoryId, territoryCode, territoryName, givenAt, pickedAt, days, deliveryFormat, givenBy, pickedBy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        transactionId = try c.decode(Int.self, forKey: .transactionId)
        territoryId = try c.decode(Int.self, forKey: .territoryId)
        territoryCode = try c.decode(String.self, forKey: .territoryCode)
        territoryName = try c.decode(String.self, forKey: .territoryName)
        givenAt = try c.decode(Date.self, forKey: .givenAt)
        pickedAt = try c.decodeIfPresent(Date.self, forKey: .pickedAt)
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        deliveryFormat = (try? c.decodeIfPresent(DeliveryFormat.self, forKey: .deliveryFormat)) ?? .physical
        givenBy = try c.decodeIfPresent(String.self, forKey: .givenBy)
        pickedBy = try c.decodeIfPresent(String.self, forKey: .pickedBy)
    }
}
