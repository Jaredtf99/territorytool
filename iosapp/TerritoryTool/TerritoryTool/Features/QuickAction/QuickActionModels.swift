import Foundation

// MARK: - Modelos de soporte del flujo de Acción rápida.
// El flujo no obliga al usuario a elegir "entregar" o "devolver": infiere la
// acción a partir del territorio o la persona seleccionada. Ver mockups y spec.

/// Resultado que la pantalla quiere resolver (escaneo o selección).
/// Se empuja en la pila de navegación del hub (sin hojas anidadas) y el
/// `QuickActionResolutionViewModel` decide el paso inicial.
enum QuickActionResolution: Identifiable, Hashable {
    case territory(Territory)
    case person(Person)

    var id: String {
        switch self {
        case .territory(let t): "territory-\(t.id)"
        case .person(let p): "person-\(p.id)"
        }
    }

    static func == (lhs: QuickActionResolution, rhs: QuickActionResolution) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Resultado del buscador unificado: un territorio o una persona, con su `score` de
/// relevancia (calculado en el backend). La lista llega ya ordenada por score.
struct QuickSearchHit: Decodable, Identifiable {
    enum Kind: String, Decodable {
        case territory
        case person
    }

    let kind: Kind
    let score: Double
    let territory: Territory?
    let person: Person?

    var id: String {
        switch kind {
        case .territory: "t-\(territory?.id ?? -1)"
        case .person: "p-\(person?.id ?? -1)"
        }
    }

    /// La resolución que abre la hoja correspondiente al tocar el resultado.
    var resolution: QuickActionResolution? {
        switch kind {
        case .territory: territory.map(QuickActionResolution.territory)
        case .person: person.map(QuickActionResolution.person)
        }
    }
}

// MARK: - Helpers de presentación operativa

extension Territory {
    /// `true` si el territorio está actualmente entregado a alguien.
    var isAssigned: Bool { personName != nil }

    /// Días que lleva entregado (desde `givenDateUtc`).
    func daysAssigned(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard isAssigned, let givenDateUtc else { return nil }
        return max(calendar.dateComponents([.day], from: givenDateUtc, to: now).day ?? 0, 0)
    }

    /// Días que lleva libre (desde la última recogida/devolución).
    func daysFree(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard !isAssigned, let lastPickedDateUtc else { return nil }
        return max(calendar.dateComponents([.day], from: lastPickedDateUtc, to: now).day ?? 0, 0)
    }
}

extension Person {
    /// Territorio activo principal (el primero en uso), si lo hay.
    var primaryActiveTerritory: TerritoryInUse? { territoriesInUse?.first }

    /// Número de territorios actualmente en uso.
    var activeTerritoryCount: Int { territoriesInUse?.count ?? 0 }

    var hasActiveTerritory: Bool { activeTerritoryCount > 0 }
}

extension TerritoryInUse {
    /// Días que la persona lleva con este territorio.
    func daysHeld(now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(calendar.dateComponents([.day], from: givenDate, to: now).day ?? 0, 0)
    }

    /// Reconstruye un `Territory` mínimo para reutilizar el flujo de devolución.
    func asTerritory(personName: String) -> Territory {
        Territory(
            id: territoryId,
            code: territoryCode,
            name: territoryName,
            mapUrl: "",
            imgUrl: nil,
            personName: personName,
            givenDateUtc: givenDate,
            lastPickedDateUtc: nil,
            mapGeometry: nil
        )
    }
}
