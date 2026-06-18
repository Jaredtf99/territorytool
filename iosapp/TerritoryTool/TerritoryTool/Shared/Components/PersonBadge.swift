import SwiftUI

struct PersonBadge: View {
    let personName: String

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: "person.fill")
                .font(.caption2)
            Text(personName)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.accent, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}
