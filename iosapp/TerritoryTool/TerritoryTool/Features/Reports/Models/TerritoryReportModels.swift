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

/// Respuesta del endpoint del informe: los movimientos del rango más el
/// total de territorios de la congregación (para calcular los no trabajados).
struct TerritoryReportResponse: Codable {
    let totalTerritories: Int
    let entries: [TerritoryReportEntry]
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
    let totalTerritories: Int
    let groups: [TerritoryGroup]

    var territoriesWorked: Int { groups.count }
    var territoriesNotWorked: Int { max(0, totalTerritories - groups.count) }

    init(entries: [TerritoryReportEntry], totalTerritories: Int, startDate: Date, endDate: Date, congregationName: String?) {
        self.startDate = startDate
        self.endDate = endDate
        self.congregationName = congregationName
        self.totalTerritories = totalTerritories

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
