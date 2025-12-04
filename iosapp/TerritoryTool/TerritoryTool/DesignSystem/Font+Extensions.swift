import SwiftUI

extension Font {
    static func appTitle() -> Font {
        return .system(size: 34, weight: .thin, design: .default)
    }
    
    static func appHeadline() -> Font {
        return .system(size: 24, weight: .light, design: .default)
    }
    
    static func appBody() -> Font {
        return .system(size: 17, weight: .regular, design: .default)
    }
    
    static func appCaption() -> Font {
        return .system(size: 13, weight: .light, design: .default)
    }
}
