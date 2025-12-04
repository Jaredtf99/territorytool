import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .system: return String(localized: "settings.theme.system")
        case .light: return String(localized: "settings.theme.light")
        case .dark: return String(localized: "settings.theme.dark")
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .system
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
