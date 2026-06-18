import SwiftUI

struct CompactTerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(territory.code)
                .font(.caption.weight(.bold))
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: AppRadius.sm))
                .foregroundStyle(Color.accent)

            Text(territory.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
    }
}
