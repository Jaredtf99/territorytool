import Foundation

/// Un movimiento (entrega y, si existe, recogida) dentro del rango del informe.
struct TerritoryReportEntry: Codable, Identifiable, Equatable {
    let territoryId: Int
    let code: String
    let territoryName: String
    let personName: String?
    let givenAt: Date?
    let pickedAt: Date?

    var id: String {
        "\(territoryId)-\(givenAt?.timeIntervalSince1970 ?? 0)-\(pickedAt?.timeIntervalSince1970 ?? 0)"
    }
}

/// Datos ya agrupados y resumidos, listos para pintar el PDF.
struct TerritoryReportData {
    struct TerritoryGroup {
        let code: String
        let name: String
        let entries: [TerritoryReportEntry]
    }

    let startDate: Date
    let endDate: Date
    let congregationName: String?
    let groups: [TerritoryGroup]

    var totalMovements: Int { groups.reduce(0) { $0 + $1.entries.count } }
    var totalTerritories: Int { groups.count }
    var totalPersons: Int {
        Set(groups.flatMap { $0.entries.compactMap(\.personName) }).count
    }
    var totalGiven: Int {
        groups.flatMap(\.entries).filter { entry in
            guard let given = entry.givenAt else { return false }
            return given >= startDate && given <= endDate
        }.count
    }
    var totalPicked: Int {
        groups.flatMap(\.entries).filter { entry in
            guard let picked = entry.pickedAt else { return false }
            return picked >= startDate && picked <= endDate
        }.count
    }

    init(entries: [TerritoryReportEntry], startDate: Date, endDate: Date, congregationName: String?) {
        self.startDate = startDate
        self.endDate = endDate
        self.congregationName = congregationName

        var order: [String] = []
        var byTerritory: [String: (name: String, entries: [TerritoryReportEntry])] = [:]
        for entry in entries {
            if byTerritory[entry.code] == nil {
                order.append(entry.code)
                byTerritory[entry.code] = (entry.territoryName, [])
            }
            byTerritory[entry.code]?.entries.append(entry)
        }
        self.groups = order.compactMap { code in
            guard let value = byTerritory[code] else { return nil }
            let sorted = value.entries.sorted {
                ($0.givenAt ?? .distantPast) < ($1.givenAt ?? .distantPast)
            }
            return TerritoryGroup(code: code, name: value.name, entries: sorted)
        }
    }
}
