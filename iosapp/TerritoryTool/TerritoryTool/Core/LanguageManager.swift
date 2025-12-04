import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case spanish = "es"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .system
    }
    
    var locale: Locale {
        switch currentLanguage {
        case .system:
            return Locale.current
        case .english:
            return Locale(identifier: "en")
        case .spanish:
            return Locale(identifier: "es")
        }
    }
}
