import SwiftUI

/// Badge del código de territorio con gradiente de acento. Ver docs/DESIGN_GUIDE.md §5.
struct TerritoryCodeBadge: View {
    let code: String
    var fontSize: Font = .system(.title3, design: .rounded)
    var paddingHorizontal: CGFloat = AppSpacing.sm
    var paddingVertical: CGFloat = AppSpacing.xs

    var body: some View {
        Text(code)
            .font(fontSize.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, paddingHorizontal)
            .padding(.vertical, paddingVertical)
            .background(
                LinearGradient(
                    colors: [.accent, .accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .accessibilityLabel(Text(verbatim: code))
    }
}
