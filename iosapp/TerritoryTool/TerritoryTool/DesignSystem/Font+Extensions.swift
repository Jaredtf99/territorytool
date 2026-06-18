import SwiftUI

// MARK: - Tokens tipográficos. Ver docs/DESIGN_GUIDE.md §3.
// Se mapean a text styles del sistema (soportan Dynamic Type) con design .rounded.
// Sin pesos thin/light: poco legibles.
extension Font {
    static func appLargeTitle() -> Font {
        .system(.largeTitle, design: .rounded).weight(.bold)
    }

    static func appTitle() -> Font {
        .system(.title2, design: .rounded).weight(.semibold)
    }

    static func appHeadline() -> Font {
        .system(.headline, design: .rounded).weight(.semibold)
    }

    static func appBody() -> Font {
        .system(.body, design: .rounded)
    }

    static func appSubheadline() -> Font {
        .system(.subheadline, design: .rounded).weight(.medium)
    }

    static func appCaption() -> Font {
        .system(.caption, design: .rounded)
    }
}
