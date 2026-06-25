import SwiftUI

struct TerritoryCard: View {
    let territory: Territory

    /// Días desde la última asignación (si la hay).
    private var daysSinceGiven: Int? {
        guard let date = territory.givenDateUtc else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }

    /// Color de antigüedad según umbrales (tokenizado, nunca solo color).
    private func ageColor(_ days: Int) -> Color {
        if days > 120 { return .danger }
        if days > 90 { return .warning }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabecera con imagen
            ZStack(alignment: .topLeading) {
                mapImage
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()

                TerritoryCodeBadge(code: territory.code)
                    .padding(AppSpacing.sm)
            }

            // Contenido
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Text(territory.name)
                        .font(.appHeadline())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    if let person = territory.personName {
                        PersonBadge(personName: person)
                    } else {
                        StatusBadge(isAssigned: false)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Label {
                            Text("dashboard.last_assigned")
                                .font(.appCaption())
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(territory.givenDateUtc?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                            .font(.appCaption().weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    if let days = daysSinceGiven {
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption2)
                            Text(String(format: String.localized("dashboard.days_ago"), days))
                                .font(.appCaption().weight(.bold))
                        }
                        .foregroundStyle(ageColor(days))
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(ageColor(days).opacity(0.12), in: .rect(cornerRadius: AppRadius.sm))
                    }
                }
            }
            .padding(AppSpacing.sm)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .paperCard(cornerRadius: AppRadius.lg)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var mapImage: some View {
        if let geometry = territory.mapGeometry {
            TerritorySnapshotBackdrop(
                geometry: geometry,
                centersTerritory: true,
                strokeLineWidth: 2.5
            )
        } else if let imgUrl = territory.imgUrl, let url = URL(string: imgUrl) {
            CachedAsyncImage(
                url: url,
                content: { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                },
                placeholder: {
                    Color.secondary.opacity(0.1)
                        .overlay(ProgressView())
                },
                errorView: {
                    mapPlaceholder
                }
            )
        } else {
            mapPlaceholder
        }
    }

    private var mapPlaceholder: some View {
        Color.secondary.opacity(0.1)
            .overlay(
                Image(systemName: "map.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.3))
            )
    }
}
