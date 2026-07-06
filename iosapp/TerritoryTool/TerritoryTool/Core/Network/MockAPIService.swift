import Foundation

class MockAPIService: APIService {
    /// Polígono de ejemplo (irregular, junto a un río) para previsualizar la
    /// silueta y los mapas sin backend.
    static let sampleGeometry: TerritoryMapGeometry = {
        let points: [(Double, Double)] = [
            (40.42310, -3.70560),
            (40.42280, -3.70210),
            (40.42150, -3.69950),
            (40.41940, -3.69820),
            (40.41700, -3.69900),
            (40.41560, -3.70140),
            (40.41530, -3.70430),
            (40.41650, -3.70690),
            (40.41890, -3.70810),
            (40.42130, -3.70750)
        ]
        return TerritoryMapGeometry(
            version: 1,
            bounds: TerritoryMapBounds(south: 40.41530, west: -3.70810, north: 40.42310, east: -3.69820),
            polygons: [
                TerritoryMapFeature(
                    id: "poly-1",
                    name: "Barrio del Río",
                    description: nil,
                    coordinates: points.map { TerritoryMapCoordinate(latitude: $0.0, longitude: $0.1) }
                )
            ],
            polylines: [],
            markers: []
        )
    }()

    func request<T>(endpoint: APIEndpoint) async throws -> T where T : Decodable {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        switch endpoint {
        case let territoryEndpoint as TerritoryEndpoint:
            switch territoryEndpoint {
            case .getTerritoryDetail(let id):
                return TerritoryDetail(
                    id: id,
                    code: "T-04\(id)",
                    name: "Barrio del Río",
                    mapUrl: "https://example.com/map",
                    imgUrl: nil,
                    personName: id % 2 == 0 ? "Andrés Morales" : nil,
                    lastPickedDateUtc: Date().addingTimeInterval(-86400 * 190),
                    givenDateUtc: id % 2 == 0 ? Date().addingTimeInterval(-86400 * 186) : nil,
                    pickedCount: 15,
                    lastUser: "Jane Smith",
                    timelineItems: [
                        TimelineItem(id: 1, description: "Picked by John", type: .picked, date: Date().addingTimeInterval(-86400 * 2)),
                        TimelineItem(id: 2, description: "Returned by Jane", type: .gave, date: Date().addingTimeInterval(-86400 * 5)),
                        TimelineItem(id: 3, description: "Created", type: .added, date: Date().addingTimeInterval(-86400 * 30))
                    ],
                    mapGeometry: Self.sampleGeometry
                ) as! T

            case .getTerritoryStats:
                return TerritoryStatistics(
                    totalTerritories: 52,
                    usageRank: 4,
                    isHighUsage: true,
                    isLowUsage: false,
                    assignedTimePercentage: 78.0,
                    globalAverageAssignedTimePercentage: 64.0,
                    averageReassignmentTime: 26.0,
                    globalAverageReassignmentTime: 18.0,
                    averageHoldingTime: 131.0,
                    globalAverageHoldingTime: 94.0,
                    currentUnassignedTime: 2.0,
                    uniqueUsersCount: 6,
                    globalAverageUniqueUsersCount: 4.2
                ) as! T

            case .getTerritoryTransactions:
                func cycle(_ id: Int, _ person: String, givenDaysAgo: Int, pickedDaysAgo: Int?) -> Transaction {
                    Transaction(
                        id: id,
                        personId: 100 + id,
                        givenDateUtc: Date().addingTimeInterval(-86400 * Double(givenDaysAgo)),
                        pickedDateUtc: pickedDaysAgo.map { Date().addingTimeInterval(-86400 * Double($0)) },
                        givenBy: "Admin",
                        pickedBy: pickedDaysAgo == nil ? nil : "Admin",
                        territoryId: 1,
                        territoryName: "Barrio del Río",
                        personName: person
                    )
                }
                return [
                    cycle(1, "Andrés Morales", givenDaysAgo: 186, pickedDaysAgo: nil),
                    cycle(2, "Lucía García", givenDaysAgo: 302, pickedDaysAgo: 196),
                    cycle(3, "Marcos Ruiz", givenDaysAgo: 391, pickedDaysAgo: 319),
                    cycle(4, "Julia Pérez", givenDaysAgo: 502, pickedDaysAgo: 414),
                    cycle(5, "Sergio Ortega", givenDaysAgo: 640, pickedDaysAgo: 521)
                ] as! T
                
            case .getPersons:
                return [
                    Person(id: 1, name: "Alice Johnson", enabled: true, territoriesInUse: []),
                    Person(id: 2, name: "Bob Williams", enabled: true, territoriesInUse: []),
                    Person(id: 3, name: "Charlie Brown", enabled: true, territoriesInUse: [])
                ] as! T

            case .getPersonsWithAssignments:
                func held(_ id: Int, _ code: String, _ name: String, days: Int) -> TerritoryInUse {
                    TerritoryInUse(
                        territoryId: id,
                        territoryName: name,
                        territoryCode: code,
                        givenDate: Date().addingTimeInterval(-86400 * Double(days))
                    )
                }
                return [
                    Person(id: 1, name: "María Ruiz", enabled: true, territoriesInUse: []),
                    Person(id: 2, name: "Carlos Vega", enabled: true, territoriesInUse: []),
                    Person(id: 3, name: "Laura Gómez", enabled: true, territoriesInUse: nil),
                    Person(id: 4, name: "Andrés Morales", enabled: true, territoriesInUse: [
                        held(42, "T-042", "Barrio del Río", days: 186),
                        held(31, "T-031", "Casco Antiguo", days: 54)
                    ]),
                    Person(id: 5, name: "Luis Peña", enabled: true, territoriesInUse: [
                        held(63, "T-063", "Polígono Norte", days: 42)
                    ]),
                    Person(id: 6, name: "Elena Ortiz", enabled: true, territoriesInUse: [
                        held(12, "T-012", "Ensanche Sur", days: 210),
                        held(55, "T-055", "La Estación", days: 120),
                        held(71, "T-071", "Vega Baja", days: 30)
                    ]),
                    Person(id: 7, name: "Pablo Iglesias", enabled: true, territoriesInUse: [
                        held(20, "T-020", "Las Huertas", days: 260)
                    ]),
                    Person(id: 8, name: "Sofía Martín", enabled: false, territoriesInUse: []),
                    Person(id: 9, name: "Jorge Díaz", enabled: false, territoriesInUse: [])
                ] as! T
                
            case .getTerritoryExplorer:
                func territory(_ id: Int, _ code: String, _ name: String, scale: Double, dx: Double, dy: Double) -> Territory {
                    // Variante desplazada/escalada del polígono base para que
                    // cada silueta se distinga en las previews.
                    let base = Self.sampleGeometry
                    let coords = base.polygons[0].coordinates.map {
                        TerritoryMapCoordinate(
                            latitude: 40.4192 + ($0.latitude - 40.4192) * scale + dy,
                            longitude: -3.7032 + ($0.longitude + 3.7032) * scale + dx
                        )
                    }
                    let geometry = TerritoryMapGeometry(
                        version: 1,
                        bounds: base.bounds,
                        polygons: [TerritoryMapFeature(id: "poly-\(id)", name: name, description: nil, coordinates: coords)],
                        polylines: [],
                        markers: []
                    )
                    return Territory(
                        id: id, code: code, name: name, mapUrl: "", imgUrl: nil,
                        personName: nil, givenDateUtc: nil, lastPickedDateUtc: nil,
                        mapGeometry: geometry
                    )
                }
                return [
                    territory(42, "T-042", "Barrio del Río", scale: 1.0, dx: 0, dy: 0),
                    territory(31, "T-031", "Casco Antiguo", scale: 0.7, dx: 0.001, dy: 0.0016),
                    territory(63, "T-063", "Polígono Norte", scale: 1.2, dx: -0.0008, dy: 0.0004),
                    territory(12, "T-012", "Ensanche Sur", scale: 0.85, dx: 0.0012, dy: -0.001),
                    territory(55, "T-055", "La Estación", scale: 1.1, dx: -0.0005, dy: -0.0014),
                    territory(71, "T-071", "Vega Baja", scale: 0.65, dx: 0.0002, dy: 0.0009),
                    territory(20, "T-020", "Las Huertas", scale: 0.9, dx: -0.0011, dy: 0.0011)
                ] as! T

            case .giveTerritory:
                return EmptyResponse() as! T

            case .getTerritoryReport(let start, let end):
                // Movimientos de ejemplo repartidos dentro del rango pedido.
                let span = max(end.timeIntervalSince(start), 86400)
                func date(_ ratio: Double) -> Date { start.addingTimeInterval(span * ratio) }
                return [
                    TerritoryReportEntry(territoryId: 1, code: "T-01", territoryName: "Barrio del Río", personName: "Andrés Morales", givenAt: date(0.05), pickedAt: date(0.35)),
                    TerritoryReportEntry(territoryId: 1, code: "T-01", territoryName: "Barrio del Río", personName: "Lucía Ferrer", givenAt: date(0.5), pickedAt: nil),
                    TerritoryReportEntry(territoryId: 2, code: "T-02", territoryName: "Casco Antiguo", personName: "Marcos Vidal", givenAt: date(0.1), pickedAt: date(0.8)),
                    TerritoryReportEntry(territoryId: 3, code: "T-03", territoryName: "Zona Industrial", personName: "Elena Ruiz", givenAt: date(0.4), pickedAt: date(0.6))
                ] as! T

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
