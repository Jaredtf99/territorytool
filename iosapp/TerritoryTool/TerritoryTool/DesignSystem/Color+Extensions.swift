import SwiftUI

extension Color {
    // Brand Colors
    static let brandPrimary = Color.blue
    static let brandSecondary = Color.indigo
    
    // Semantic Colors
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    
    // Status Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    // Legacy support (to be removed after refactor, mapped to new system)
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let glassBorder = Color.clear
    static let glassShadow = Color.black.opacity(0.1)
    static let gradientStart = brandPrimary
    static let gradientEnd = brandSecondary
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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
