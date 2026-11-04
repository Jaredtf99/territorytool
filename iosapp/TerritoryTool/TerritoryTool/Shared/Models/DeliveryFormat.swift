import SwiftUI

/// Cómo se entregó un territorio: en papel (por defecto) o enviado en formato digital.
/// El `rawValue` es el valor de `territory_transactions.delivery_format`.
nonisolated enum DeliveryFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case physical
    case virtual

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .physical: "delivery_format.physical"
        case .virtual: "delivery_format.virtual"
        }
    }

    var localizedName: String {
        switch self {
        case .physical: String.localized("delivery_format.physical")
        case .virtual: String.localized("delivery_format.virtual")
        }
    }

    var systemImage: String {
        switch self {
        case .physical: "doc.text"
        case .virtual: "iphone"
        }
    }

    /// Color de la familia "formato de entrega" (filtros, marca virtual, interruptor).
    /// Azul pizarra: verde, ámbar y terracota quedan reservados al *estado* del
    /// territorio (libre, en uso, atención), así que ambos ejes no se confunden.
    static let familyTint: Color = .info

    /// Color de la marca en un elemento concreto: solo lo virtual se destaca.
    var tint: Color {
        switch self {
        case .physical: .textSecondary
        case .virtual: Self.familyTint
        }
    }
}
