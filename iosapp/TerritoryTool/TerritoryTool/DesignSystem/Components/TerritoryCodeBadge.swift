import SwiftUI

struct TerritoryCodeBadge: View {
    let code: String
    var fontSize: Font = .system(.title3, design: .rounded)
    var paddingHorizontal: CGFloat = 12
    var paddingVertical: CGFloat = 6
    
    var body: some View {
        Text(code)
            .font(fontSize.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, paddingHorizontal)
            .padding(.vertical, paddingVertical)
            .background(
                LinearGradient(colors: [.brandPrimary, .brandSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: .brandPrimary.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
