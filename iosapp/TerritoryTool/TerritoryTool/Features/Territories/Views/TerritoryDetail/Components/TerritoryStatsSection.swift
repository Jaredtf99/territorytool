import SwiftUI

/// Estadísticas inline del detalle de territorio. Agrupa los datos reales en
/// lecturas visuales: uso, actividad, ritmo de ciclo y alcance.
struct TerritoryStatsSection: View {
    let stats: TerritoryStatistics
    let transactions: [Transaction]

    private var uniqueUserNames: [String] {
        var seenPersonIds = Set<Int>()
        return transactions
            .sorted { $0.givenDateUtc > $1.givenDateUtc }
            .compactMap { transaction in
                guard !seenPersonIds.contains(transaction.personId) else { return nil }
                seenPersonIds.insert(transaction.personId)
                let name = transaction.personName.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(
                title: "territory.detail.stats.title",
                systemImage: "chart.bar.fill",
                tint: .accentSecondary
            )

            UsageRankCard(stats: stats)

            ActiveTimeCard(stats: stats)

            CycleRhythmCard(stats: stats)

            ReachCard(stats: stats, userNames: uniqueUserNames)
        }
    }
}

// MARK: - Uso

private struct UsageRankCard: View {
    let stats: TerritoryStatistics

    private var position: Double {
        guard stats.totalTerritories > 1 else { return 0 }
        let raw = Double(stats.usageRank - 1) / Double(stats.totalTerritories - 1)
        return min(max(raw, 0), 1)
    }

    private var statusKey: LocalizedStringKey {
        if stats.isHighUsage { return "territory.detail.stats.rotation_high" }
        if stats.isLowUsage { return "territory.detail.stats.rotation_low" }
        return "territory.detail.stats.rotation_balanced"
    }

    private var markerColor: Color {
        if stats.isHighUsage { return .accentTertiary }
        if stats.isLowUsage { return .info }
        return .accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Label("territory.detail.stats.rotation", systemImage: "arrow.triangle.2.circlepath")
                        .font(.appCaption().weight(.bold))
                        .foregroundStyle(Color.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Text(String(format: String.localized("territory.detail.stats.rank_position"), stats.usageRank))
                            .font(.appLargeTitle().weight(.heavy))
                            .monospacedDigit()
                            .foregroundStyle(Color.textPrimary)

                        Text(String(format: String.localized("territory.detail.stats.rank_of"), stats.totalTerritories))
                            .font(.appSubheadline().weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                            .minimumScaleFactor(0.8)
                    }
                }

                Spacer(minLength: AppSpacing.sm)

                Text(statusKey)
                    .font(.appCaption().weight(.bold))
                    .foregroundStyle(markerColor)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(markerColor.opacity(0.12), in: Capsule(style: .continuous))
            }

            RotationScale(position: position, markerColor: markerColor)

            HStack {
                Text("territory.detail.stats.more_rotated")
                Spacer()
                Text("territory.detail.stats.less_rotated")
            }
            .font(.appCaption().weight(.semibold))
            .foregroundStyle(Color.textSecondary)
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg, fill: .surfaceRaised)
        .statsExplanation(
            title: "territory.detail.stats.rotation",
            message: "territory.stats.rank_desc"
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RotationScale: View {
    let position: Double
    let markerColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let markerX = width * position

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentTertiary.opacity(0.78),
                                Color.accent.opacity(0.78),
                                Color.info.opacity(0.70)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)
                    .overlay(alignment: .center) {
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { _ in
                                Rectangle()
                                    .fill(.white.opacity(0.34))
                                    .frame(width: 1, height: 14)
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                    }

                Circle()
                    .fill(markerColor)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.surface, lineWidth: 4))
                    .shadow(color: markerColor.opacity(0.35), radius: 6, x: 0, y: 3)
                    .offset(x: min(max(markerX - 13, 0), max(width - 26, 0)))
            }
        }
        .frame(height: 28)
    }
}

// MARK: - Uso

private struct ActiveTimeCard: View {
    let stats: TerritoryStatistics

    var body: some View {
        MetricBarCard(
            title: "territory.detail.stats.activity",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .accent,
            valueText: percentText(stats.assignedTimePercentage),
            subtitle: "territory.stats.active_time",
            value: stats.assignedTimePercentage,
            average: stats.globalAverageAssignedTimePercentage,
            maxValue: 100,
            barColor: .accent,
            averageText: String(format: String.localized("territory.detail.stats.avg_value"), percentText(stats.globalAverageAssignedTimePercentage)),
            explanation: "territory.stats.active_time_desc"
        )
    }
}

private struct MetricBarCard: View {
    let title: LocalizedStringKey
    let icon: String
    let iconColor: Color
    let valueText: String
    let subtitle: LocalizedStringKey
    let value: Double
    let average: Double
    let maxValue: Double
    let barColor: Color
    let averageText: String
    let explanation: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                StatIcon(systemName: icon, color: iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appCaption().weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                    Text(subtitle)
                        .font(.appSubheadline().weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer(minLength: AppSpacing.sm)

                Text(valueText)
                    .font(.appTitle().weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
            }

            ComparisonBar(
                value: value,
                average: average,
                maxValue: maxValue,
                color: barColor,
                averageText: averageText
            )

            HStack {
                Spacer()
                DeltaPill(value: value, average: average, lowerIsBetter: false)
            }
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
        .statsExplanation(title: subtitle, message: explanation)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Ritmo de ciclo

private struct CycleRhythmCard: View {
    let stats: TerritoryStatistics

    private var maxValue: Double {
        max(
            stats.averageHoldingTime,
            stats.globalAverageHoldingTime,
            stats.averageReassignmentTime,
            stats.globalAverageReassignmentTime,
            1
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                StatIcon(systemName: "point.3.connected.trianglepath.dotted", color: .accentSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("territory.detail.stats.cycle_rhythm")
                        .font(.appCaption().weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                    Text("territory.detail.stats.cycle_rhythm_subtitle")
                        .font(.appSubheadline().weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()
            }

            CycleMetricRow(
                title: "territory.detail.stats.assigned_segment",
                valueText: daysText(stats.averageHoldingTime),
                averageText: String(format: String.localized("territory.detail.stats.avg_value"), daysText(stats.globalAverageHoldingTime)),
                value: stats.averageHoldingTime,
                average: stats.globalAverageHoldingTime,
                maxValue: maxValue,
                color: .accentSecondary,
                lowerIsBetter: true
            )

            CycleMetricRow(
                title: "territory.detail.stats.wait_segment",
                valueText: daysText(stats.averageReassignmentTime),
                averageText: String(format: String.localized("territory.detail.stats.avg_value"), daysText(stats.globalAverageReassignmentTime)),
                value: stats.averageReassignmentTime,
                average: stats.globalAverageReassignmentTime,
                maxValue: maxValue,
                color: .info,
                lowerIsBetter: true
            )
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
        .statsExplanation(
            title: "territory.detail.stats.cycle_rhythm",
            message: "territory.detail.stats.cycle_rhythm_desc"
        )
        .accessibilityElement(children: .combine)
    }
}

private struct CycleMetricRow: View {
    let title: LocalizedStringKey
    let valueText: String
    let averageText: String
    let value: Double
    let average: Double
    let maxValue: Double
    let color: Color
    let lowerIsBetter: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.appCaption().weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: AppSpacing.sm)
                Text(valueText)
                    .font(.appLargeTitle().weight(.heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(Color.textPrimary)
            }

            ComparisonBar(
                value: value,
                average: average,
                maxValue: maxValue,
                color: color,
                averageText: averageText
            )

            HStack {
                Spacer()
                DeltaPill(value: value, average: average, lowerIsBetter: lowerIsBetter)
            }
        }
    }
}

// MARK: - Alcance

private struct ReachCard: View {
    let stats: TerritoryStatistics
    let userNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                StatIcon(systemName: "person.2.fill", color: .accentTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("territory.detail.stats.reach")
                        .font(.appCaption().weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                    Text("territory.stats.unique_users")
                        .font(.appSubheadline().weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Text(String(format: String.localized("territory.detail.stats.avg_value"), usersAverageText(stats.globalAverageUniqueUsersCount)))
                    .font(.appCaption().weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.surfaceRaised, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: AppSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text("\(stats.uniqueUsersCount)")
                        .font(.appLargeTitle().weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color.textPrimary)
                    Text("territory.detail.stats.users_label")
                        .font(.appSubheadline().weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer(minLength: AppSpacing.sm)

                UserDots(count: stats.uniqueUsersCount, names: userNames)
            }
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
        .statsExplanation(
            title: "territory.stats.unique_users",
            message: "territory.stats.unique_users_desc"
        )
        .accessibilityElement(children: .combine)
    }
}

private struct UserDots: View {
    let count: Int
    let names: [String]

    private var visibleCount: Int {
        min(count, 4)
    }

    var body: some View {
        Group {
            if count == 0 {
                Text("—")
                    .font(.appSubheadline().weight(.heavy))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 30, height: 30)
            } else {
                HStack(spacing: -8) {
                    ForEach(0..<visibleCount, id: \.self) { index in
                        if count > 4 && index == 3 {
                            CollapsedUsersDot(hiddenCount: count - 3)
                                .zIndex(Double(visibleCount - index))
                        } else {
                            InitialsAvatar(
                                name: name(for: index),
                                size: 30,
                                tint: dotColor(index)
                            )
                            .overlay(Circle().stroke(Color.surface, lineWidth: 2))
                            .zIndex(Double(visibleCount - index))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.surfaceRaised, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }

    private func dotColor(_ index: Int) -> Color {
        let colors: [Color] = [.accent, .accentSecondary, .accentTertiary, .info]
        return colors[index % colors.count]
    }

    private func name(for index: Int) -> String {
        guard names.indices.contains(index) else { return "?" }
        return names[index]
    }
}

private struct CollapsedUsersDot: View {
    let hiddenCount: Int

    var body: some View {
        Text("+\(hiddenCount)")
            .font(.appCaption().weight(.heavy))
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.textSecondary)
            .frame(width: 30, height: 30)
            .background(Color.surfaceRaised, in: Circle())
            .overlay(Circle().stroke(Color.surface, lineWidth: 2))
    }
}

// MARK: - Elementos comunes

private struct ComparisonBar: View {
    let value: Double
    let average: Double
    let maxValue: Double
    let color: Color
    let averageText: String

    private var valueProgress: Double {
        normalized(value)
    }

    private var averageProgress: Double {
        normalized(average)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let markerWidth = min(max(width * 0.34, 78), 116)
            let valueWidth = width * valueProgress
            let markerX = width * averageProgress
            let markerLineX = min(max(markerX - 1, 0), max(width - 2, 0))
            let markerOffset = min(max(markerX - markerWidth / 2, 0), max(width - markerWidth, 0))

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.hairline.opacity(0.65))
                        .frame(height: 16)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.72), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(valueWidth, 8))
                        .frame(height: 16)
                }
                .offset(y: 8)

                Rectangle()
                    .fill(Color.textPrimary.opacity(0.72))
                    .frame(width: 2, height: 26)
                    .clipShape(Capsule(style: .continuous))
                    .offset(x: markerLineX, y: 3)

                Text(averageText)
                    .font(.appCaption().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: markerWidth, alignment: .center)
                    .offset(x: markerOffset, y: 32)
            }
        }
        .frame(height: 46)
    }

    private func normalized(_ metric: Double) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(max(metric / maxValue, 0), 1)
    }
}

private struct DeltaPill: View {
    let value: Double
    let average: Double
    let lowerIsBetter: Bool

    private var delta: Double {
        value - average
    }

    private var isNeutral: Bool {
        abs(delta) <= max(average * 0.05, 0.5)
    }

    private var isGood: Bool {
        guard !isNeutral else { return true }
        return lowerIsBetter ? delta < 0 : delta > 0
    }

    private var color: Color {
        isNeutral ? .textSecondary : (isGood ? .success : .warning)
    }

    private var icon: String {
        isNeutral ? "minus" : (delta > 0 ? "arrow.up" : "arrow.down")
    }

    var body: some View {
        Label(deltaText, systemImage: icon)
            .font(.appCaption().weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(color.opacity(0.10), in: Capsule(style: .continuous))
    }

    private var deltaText: String {
        if isNeutral { return String.localized("territory.detail.stats.on_average") }
        if abs(delta) >= 10 {
            return String(format: "%+.0f", delta)
        }
        return String(format: "%+.1f", delta)
    }
}

private struct StatIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)
    }
}

private struct StatExplanationModifier: ViewModifier {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    @State private var showInfo = false

    func body(content: Content) -> some View {
        Button {
            HapticManager.shared.selection()
            showInfo = true
        } label: {
            content
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .alert(title, isPresented: $showInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

private extension View {
    func statsExplanation(title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        modifier(StatExplanationModifier(title: title, message: message))
    }
}

private func percentText(_ value: Double) -> String {
    String(format: String.localized("territory.stats.percentage"), value)
}

private func daysText(_ value: Double) -> String {
    String(format: String.localized("territory.stats.days"), value)
}

private func usersAverageText(_ value: Double) -> String {
    String(format: String.localized("territory.detail.stats.users_average"), value)
}
