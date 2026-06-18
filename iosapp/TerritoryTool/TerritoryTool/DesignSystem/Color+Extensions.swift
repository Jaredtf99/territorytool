import SwiftUI
import UIKit

// MARK: - Design tokens (fuente única de color). Tema "Cartográfico cálido".
// Paleta de mapa/expedición: papel cálido, verde bosque, ámbar y terracota.
// Todos los colores son dinámicos claro/oscuro.
extension Color {

    /// Color dinámico claro/oscuro a partir de enteros 0xRRGGBB.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }

    // MARK: Acento / marca
    /// Verde bosque — acción principal, selección, rutas.
    static let accent          = Color(light: 0x2F6B4F, dark: 0x5FB389)
    /// Ámbar — acento cálido secundario, énfasis.
    static let accentSecondary = Color(light: 0xD98A2B, dark: 0xE8A857)
    /// Terracota — tercer acento, marcadores.
    static let accentTertiary  = Color(light: 0xC4633B, dark: 0xD98A63)

    // MARK: Estados semánticos
    static let success = Color(light: 0x2F6B4F, dark: 0x5FB389)
    static let warning = Color(light: 0xC8821F, dark: 0xE8A857)
    static let danger  = Color(light: 0xBC4B2E, dark: 0xE07A52)
    static let info    = Color(light: 0x3E6B8C, dark: 0x7FAAC9)

    // MARK: Superficies y texto — papel cálido
    /// Fondo base de pantalla.
    static let appBackground     = Color(light: 0xF4EFE6, dark: 0x1A1714)
    /// Veladura/borde del fondo (viñeta cálida).
    static let appBackgroundDeep = Color(light: 0xE7DECB, dark: 0x12100D)
    /// Superficie de tarjetas y filas.
    static let surface           = Color(light: 0xFBF8F1, dark: 0x252019)
    /// Superficie elevada (chips/iconos sobre tarjeta).
    static let surfaceRaised     = Color(light: 0xFFFFFF, dark: 0x2E2820)
    /// Línea de contorno topográfico del fondo.
    static let cartoLine         = Color(light: 0x9C8A6E, dark: 0x6E6354)
    /// Borde fino cálido de tarjetas.
    static let hairline          = Color(light: 0xDED3BE, dark: 0x3A3329)
    static let textPrimary       = Color(light: 0x2C271F, dark: 0xEFE9DD)
    static let textSecondary     = Color(light: 0x756A56, dark: 0xACA290)

    // MARK: Alias legacy (mapeados a tokens; retirar tras completar la migración)
    static let brandPrimary    = Color.accent
    static let brandSecondary  = Color.accentSecondary
    static let error           = Color.danger
    static let background      = Color.appBackground
    static let secondaryBackground = Color.surface
    static let glassBorder     = Color.hairline
    static let glassShadow     = Color(light: 0x4A3F2A, dark: 0x000000).opacity(0.10)
    static let gradientStart   = Color.accent
    static let gradientEnd     = Color.accentSecondary
}

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
