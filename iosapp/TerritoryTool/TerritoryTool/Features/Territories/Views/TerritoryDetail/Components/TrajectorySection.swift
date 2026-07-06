import SwiftUI

/// Ciclo de asignación derivado de una transacción, para la trayectoria.
private struct TrajectoryCycle: Identifiable {
    let transaction: Transaction

    var id: Int { transaction.id }
    var personName: String { transaction.personName }
    var isCurrent: Bool { transaction.pickedDateUtc == nil }

    var days: Int {
        let end = transaction.pickedDateUtc ?? Date()
        return max(Calendar.current.dateComponents([.day], from: transaction.givenDateUtc, to: end).day ?? 0, 0)
    }
}

/// "Trayectoria": los ciclos de asignación como anillos en un carrusel
/// horizontal (el actual resaltado), con detalle expandible al tocar y un
/// banner comparando la rotación del territorio con la media.
struct TrajectorySection: View {
    let transactions: [Transaction]
    let stats: TerritoryStatistics?
    let canManage: Bool
    let onEdit: (Transaction) -> Void
    let onDelete: (Transaction) -> Void

    @State private var selectedId: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cycles: [TrajectoryCycle] {
        transactions
            .map(TrajectoryCycle.init)
            .sorted { $0.transaction.givenDateUtc > $1.transaction.givenDateUtc }
    }

    /// Escala común de los anillos: el ciclo más largo marca el 100 %.
    private var ringScale: Double {
        Double(max(cycles.map(\.days).max() ?? 1, 1))
    }

    var body: some View {
        let cycles = self.cycles

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(
                title: "territory.detail.trajectory.title",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill",
                count: cycles.isEmpty ? nil : cycles.count
            )

            if cycles.isEmpty {
                CartoEmptyState(
                    systemImage: "map",
                    message: "territory.detail.trajectory.empty"
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        ForEach(Array(cycles.enumerated()), id: \.element.id) { index, cycle in
                            cycleRing(cycle)
                                .appear(index: index, base: 0.06)
                        }
                    }
                    // Aire vertical para que el halo pulsante, la escala de
                    // selección y su sombra no se recorten en el ScrollView.
                    .padding(.vertical, AppSpacing.md)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, -AppSpacing.xs)

                if let selected = cycles.first(where: { $0.id == selectedId }) {
                    cycleDetail(selected)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .offset(y: -8))
                        )
                }

                if let stats, cycles.contains(where: { !$0.isCurrent }) {
                    insightBanner(stats: stats)
                }
            }
        }
    }

    // MARK: Anillo de ciclo

    private func cycleRing(_ cycle: TrajectoryCycle) -> some View {
        let tint: Color = cycle.isCurrent ? Color.urgency(forDays: cycle.days) : .accent
        let isSelected = selectedId == cycle.id
        let progress = min(Double(cycle.days) / ringScale, 1)

        return Button {
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                selectedId = isSelected ? nil : cycle.id
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    // El ciclo actual respira: halo pulsante en su color.
                    if cycle.isCurrent {
                        PulseHalo(tint: tint)
                    }

                    Circle()
                        .stroke(Color.hairline, lineWidth: isSelected ? 6 : 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: isSelected ? 6 : 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(cycle.days)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(cycle.isCurrent ? tint : Color.textPrimary)
                        Text("common.days")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(width: 68, height: 68)
                .scaleEffect(isSelected ? 1.08 : 1)
                .shadow(color: isSelected ? tint.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)

                // Nombre completo; el actual se marca con un punto en su color.
                HStack(spacing: 4) {
                    if cycle.isCurrent {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                    }
                    Text(cycle.personName)
                        .font(.appCaption().weight(cycle.isCurrent || isSelected ? .bold : .medium))
                        .foregroundStyle(cycle.isCurrent || isSelected ? tint : Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: 96)
            }
            .padding(.horizontal, AppSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .contextMenu {
            if canManage {
                Button { onEdit(cycle.transaction) } label: {
                    Label("common.edit", systemImage: "pencil")
                }
                Button(role: .destructive) { onDelete(cycle.transaction) } label: {
                    Label("common.delete", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel(Text("\(cycle.personName), \(cycle.days) \(String.localized("common.days"))"))
    }

    // MARK: Detalle del ciclo seleccionado

    /// Ficha del ciclo: nombre y recorrido de fechas (entrega → devolución)
    /// como una pequeña ruta cartográfica. Los días no se repiten: ya están
    /// en el anillo.
    private func cycleDetail(_ cycle: TrajectoryCycle) -> some View {
        let tint: Color = cycle.isCurrent ? Color.urgency(forDays: cycle.days) : .accent

        return HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: cycle.personName, size: 40, tint: tint)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(cycle.personName)
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                datesRoute(for: cycle, tint: tint)
            }

            Spacer(minLength: 0)

            if canManage {
                Button {
                    HapticManager.shared.selection()
                    onEdit(cycle.transaction)
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                .tint(.accentDeep)
                .accessibilityLabel(Text("common.edit"))

                Button(role: .destructive) {
                    onDelete(cycle.transaction)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                .tint(.danger)
                .accessibilityLabel(Text("common.delete"))
            }
        }
        .padding(AppSpacing.sm)
        .paperCard(cornerRadius: AppRadius.lg, fill: .surfaceRaised)
    }

    /// Ruta de fechas: punto de salida (entrega) — línea punteada — punto de
    /// llegada (devolución o "En uso").
    private func datesRoute(for cycle: TrajectoryCycle, tint: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.accentSecondary)
                    .frame(width: 7, height: 7)
                Text(cycle.transaction.givenDateUtc.formatted(date: .abbreviated, time: .omitted))
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
            }

            RouteDashes()
                .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 20, height: 1)

            HStack(spacing: 4) {
                if let picked = cycle.transaction.pickedDateUtc {
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 7, height: 7)
                    Text(picked.formatted(date: .abbreviated, time: .omitted))
                        .font(.appCaption())
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Circle()
                        .strokeBorder(tint, lineWidth: 2)
                        .frame(width: 8, height: 8)
                    Text("territory.detail.trajectory.ongoing")
                        .font(.appCaption().weight(.semibold))
                        .foregroundStyle(tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Halo que se expande y desvanece en bucle alrededor del anillo actual.
    private struct PulseHalo: View {
        let tint: Color

        @State private var animate = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Circle()
                .stroke(tint.opacity(0.55), lineWidth: 2)
                .scaleEffect(animate ? 1.32 : 1)
                .opacity(animate ? 0 : 0.7)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(0.6)) {
                        animate = true
                    }
                }
                .accessibilityHidden(true)
        }
    }

    private struct RouteDashes: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }

    // MARK: Comparativa con la media

    private func insightBanner(stats: TerritoryStatistics) -> some View {
        let delta = Int((stats.averageHoldingTime - stats.globalAverageHoldingTime).rounded())
        let (icon, tint, message): (String, Color, String) = {
            if delta >= 3 {
                return (
                    "chart.line.uptrend.xyaxis",
                    .accentTertiary,
                    String(format: String.localized("territory.detail.trajectory.slower"), delta)
                )
            } else if delta <= -3 {
                return (
                    "chart.line.downtrend.xyaxis",
                    .accent,
                    String(format: String.localized("territory.detail.trajectory.faster"), -delta)
                )
            }
            return ("checkmark.seal.fill", .accent, String.localized("territory.detail.trajectory.on_track"))
        }()

        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.78)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: tint.opacity(0.35), radius: 4, x: 0, y: 2)

            Text(message)
                .font(.appSubheadline())
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}
