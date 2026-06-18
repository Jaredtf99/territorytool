import SwiftUI

/// Escala de radios de esquina. Ver `docs/DESIGN_GUIDE.md` §4.
enum AppRadius {
    /// 8 — badges, chips, controles pequeños
    static let sm: CGFloat = 8
    /// 12 — campos, botones
    static let md: CGFloat = 12
    /// 20 — tarjetas
    static let lg: CGFloat = 20
    /// 26 — hojas y contenedores grandes
    static let xl: CGFloat = 26
}

/// Elevación estandarizada. En Liquid Glass la profundidad la aporta el material,
/// así que se usa con moderación. Ver `docs/DESIGN_GUIDE.md` §4.
enum AppElevation {
    static let cardColor = Color.black.opacity(0.08)
    static let cardRadius: CGFloat = 8
    static let cardY: CGFloat = 4
}
