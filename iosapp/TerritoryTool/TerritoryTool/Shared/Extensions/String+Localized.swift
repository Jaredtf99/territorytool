import SwiftUI

extension String {
    static func localized(_ key: String) -> String {
        let languageCode = LanguageManager.shared.currentLanguage.rawValue
        
        guard languageCode != "system",
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}
