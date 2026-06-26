import SwiftUI

enum TerritoryStatusIndicatorSize {
    case compact
    case regular

    var iconSize: CGFloat {
        switch self {
        case .compact: 24
        case .regular: 28
        }
    }

    var iconFont: Font {
        switch self {
        case .compact: .caption2.weight(.bold)
        case .regular: .caption2.weight(.bold)
        }
    }

    var titleFont: Font {
        switch self {
        case .compact: .appCaption().weight(.bold)
        case .regular: .appSubheadline().weight(.bold)
        }
    }

    var detailFont: Font {
        switch self {
        case .compact: .system(.caption2, design: .rounded).weight(.medium)
        case .regular: .appCaption().weight(.medium)
        }
    }
}

struct TerritoryStatusIcon: View {
    let presentation: TerritoryStatusPresentation
    var size: TerritoryStatusIndicatorSize = .regular

    var body: some View {
        Image(systemName: presentation.icon)
            .font(size.iconFont)
            .foregroundStyle(.white)
            .frame(width: size.iconSize, height: size.iconSize)
            .background(
                LinearGradient(
                    colors: [presentation.color, presentation.color.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: presentation.color.opacity(0.35), radius: 5, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

struct TerritoryStatusIndicator: View {
    let presentation: TerritoryStatusPresentation
    var detail: LocalizedStringKey?
    var size: TerritoryStatusIndicatorSize = .regular

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            TerritoryStatusIcon(presentation: presentation, size: size)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(size.titleFont)
                    .foregroundStyle(presentation.color)
                    .lineLimit(1)

                if let detail {
                    Text(detail)
                        .font(size.detailFont)
                        .foregroundStyle(presentation.color)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.title)
    }
}

struct TerritoryStatusPresentation {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let icon: String
    let color: Color

    init(_ status: TerritoryOperationalStatus) {
        switch status {
        case .available:
            title = "territory.status.available"
            detail = "territories.status.available_now"
            icon = "checkmark"
            color = .accent
        case .assigned(let days):
            title = "territory.status.assigned"
            detail = LocalizedStringKey(String(format: String.localized("territories.status.days_assigned"), days))
            icon = "person.crop.circle.fill"
            color = .accentSecondary
        case .attention(let days):
            title = "territories.filter.attention"
            detail = LocalizedStringKey(String(format: String.localized("territories.status.days_assigned"), days))
            icon = "exclamationmark.triangle.fill"
            color = .accentTertiary
        }
    }
}
