import SwiftUI

// MARK: - Piezas de la ficha de hermano (tema "Cartográfico cálido").

// MARK: Cabecera

/// Avatar grande con halo (si tiene territorios), nombre y estado.
struct BrotherDetailHeader: View {
    let detail: PersonDetail

    private var tint: Color {
        Person(id: detail.person.id, name: detail.person.name, enabled: detail.person.enabled, territoriesInUse: nil).avatarTint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    if detail.summary.activeAssignments > 0 && detail.person.enabled {
                        BreathingHalo(tint: tint)
                    }
                    InitialsAvatar(name: detail.person.name, size: 84, tint: tint)
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(detail.person.name)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)

                    statusChip
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusChip: some View {
        let (title, color): (String, Color) = {
            if !detail.person.enabled { return (String.localized("brothers.status.inactive"), .textSecondary) }
            let active = detail.summary.activeAssignments
            if active == 0 { return (String.localized("brother.detail.status.available"), .accent) }
            return (String(format: String.localized("brother.detail.status.with_territories"), active), .accentSecondary)
        }()

        return HStack(spacing: AppSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.appCaption().weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.10)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }
}

/// Halo que se expande y desvanece en bucle (hermano con territorios en curso).
private struct BreathingHalo: View {
    let tint: Color
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .stroke(tint.opacity(0.55), lineWidth: 2)
            .frame(width: 84, height: 84)
            .scaleEffect(animate ? 1.28 : 1)
            .opacity(animate ? 0 : 0.7)
            .onAppear {
                guard !reduceMotion else { return }
                // Pulso finito (antes infinito): evitaba que la pantalla quedase en reposo.
                withAnimation(.easeOut(duration: 1.8).repeatCount(3, autoreverses: false).delay(0.4)) {
                    animate = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: En curso

/// Tarjeta de un territorio en curso: silueta del mapa, código, nombre, días
/// (rampa de urgencia) y barra frente a la media de la congregación.
struct BrotherCurrentCard: View {
    let assignment: PersonCurrentAssignment
    let averageDays: Double?
    let onOpen: () -> Void

    @State private var progressShown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { Color.urgency(forDays: assignment.days) }

    private var progress: Double {
        let reference = max(averageDays ?? 120, 1)
        return min(Double(assignment.days) / reference, 1)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: AppSpacing.sm) {
                mapPreview
                    .frame(width: 84, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(assignment.territoryCode)
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.accentDeep)
                        if assignment.deliveryFormat == .virtual {
                            DeliveryFormatBadge(format: .virtual)
                        }
                        Spacer(minLength: 0)
                        Text(String(format: String.localized("brothers.days_format"), assignment.days))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.13), in: Capsule())
                    }

                    if assignment.territoryName != assignment.territoryCode {
                        Text(assignment.territoryName)
                            .font(.appSubheadline())
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.hairline.opacity(0.6))
                            Capsule()
                                .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * progressShown)
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)

                    HStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 9, weight: .semibold))
                        Text(assignment.givenAt, style: .date)
                        if let by = assignment.givenBy {
                            Text("· \(by)")
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(AppSpacing.sm)
            .paperCard(cornerRadius: AppRadius.lg)
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: AppRadius.lg, bottomLeadingRadius: AppRadius.lg)
                    .fill(tint)
                    .frame(width: 4)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            guard !reduceMotion else { progressShown = progress; return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.25)) {
                progressShown = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { progressShown = newValue }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("brothers.territory.open_hint"))
    }

    @ViewBuilder
    private var mapPreview: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
        Group {
            if let geometry = assignment.mapGeometry {
                TerritorySnapshotBackdrop(geometry: geometry, stroke: tint, fill: tint, centersTerritory: true)
            } else {
                Color.secondary.opacity(0.1)
                    .overlay(
                        Image(systemName: "map.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.textSecondary.opacity(0.35))
                    )
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(tint.opacity(0.28), lineWidth: 1))
    }
}

// MARK: Actividad

/// Barras de entregas/devoluciones de los últimos 12 meses. Tocar un mes lo
/// selecciona y muestra su resumen.
struct BrotherActivityChart: View {
    let activity: [PersonMonthlyActivity]

    @State private var grown = false
    @State private var selected: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxValue: Int {
        max(activity.flatMap { [$0.givenCount, $0.returnedCount] }.max() ?? 1, 1)
    }

    private var total: Int { activity.reduce(0) { $0 + $1.givenCount } }

    /// Alto de la zona de barras (sin la fila de meses): eje y rejilla lo comparten.
    private let plotHeight: CGFloat = 116

    /// Paso "redondo" del eje Y: como mucho ~4 divisiones, siempre enteras.
    private var axisStep: Int { max(1, Int((Double(maxValue) / 4).rounded(.up))) }

    /// Tope del eje Y (múltiplo del paso); las barras se escalan contra él.
    private var axisMax: Int { axisStep * Int((Double(maxValue) / Double(axisStep)).rounded(.up)) }

    private var axisTicks: [Int] { Array(stride(from: 0, through: axisMax, by: axisStep)) }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    private static let longMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(title: "brother.detail.activity.title", systemImage: "chart.bar.xaxis", count: total > 0 ? total : nil)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                summaryLine

                HStack(alignment: .top, spacing: 6) {
                    yAxis
                        .frame(width: 18, height: plotHeight)

                    ZStack(alignment: .top) {
                        gridLines
                            .frame(height: plotHeight)

                        HStack(alignment: .top, spacing: 4) {
                            ForEach(Array(activity.enumerated()), id: \.element.id) { index, month in
                                column(month, index: index)
                            }
                        }
                    }
                }

                HStack(spacing: AppSpacing.md) {
                    legend(color: .accentSecondary, label: "brother.detail.activity.given")
                    legend(color: .accent, label: "brother.detail.activity.returned")
                }
            }
            .padding(AppSpacing.md)
            .paperCard(cornerRadius: AppRadius.lg)
        }
        .onAppear {
            guard !reduceMotion else { grown = true; return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) { grown = true }
        }
    }

    @ViewBuilder
    private var summaryLine: some View {
        if let selected, let month = activity.first(where: { $0.month == selected }) {
            HStack {
                Text(Self.longMonthFormatter.string(from: month.month).capitalized)
                    .font(.appSubheadline().weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(String(format: String.localized("brother.detail.activity.month_summary"), month.givenCount, month.returnedCount))
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
            }
            .transition(.opacity.combined(with: .offset(y: -4)))
            .id(selected)
        } else {
            Text(total == 0 ? "brother.detail.activity.empty" : "brother.detail.activity.hint")
                .font(.appCaption())
                .foregroundStyle(Color.textSecondary)
                .transition(.opacity)
        }
    }

    private func column(_ month: PersonMonthlyActivity, index: Int) -> some View {
        let isSelected = selected == month.month
        let dimmed = selected != nil && !isSelected
        return Button {
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                selected = isSelected ? nil : month.month
            }
        } label: {
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 2) {
                    bar(value: month.givenCount, color: .accentSecondary, delay: Double(index) * 0.03)
                    bar(value: month.returnedCount, color: .accent, delay: Double(index) * 0.03 + 0.015)
                }
                .frame(height: plotHeight, alignment: .bottom)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accent.opacity(0.10) : .clear)
                )

                Text(Self.monthFormatter.string(from: month.month).prefix(3).capitalized)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .opacity(dimmed ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(Self.longMonthFormatter.string(from: month.month)): \(String(format: String.localized("brother.detail.activity.month_summary"), month.givenCount, month.returnedCount))"))
    }

    private func bar(value: Int, color: Color, delay: Double) -> some View {
        GeometryReader { proxy in
            let fraction = value == 0 ? 0 : max(Double(value) / Double(axisMax), 0.04)
            VStack {
                Spacer(minLength: 0)
                UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                    .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
                    .frame(height: grown ? proxy.size.height * fraction : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.78).delay(delay), value: grown)
            }
        }
        .frame(maxWidth: 10)
    }

    /// Etiquetas del eje Y, centradas sobre su línea guía.
    private var yAxis: some View {
        GeometryReader { proxy in
            ForEach(axisTicks, id: \.self) { tick in
                Text("\(tick)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.textSecondary.opacity(0.8))
                    .frame(width: proxy.size.width, alignment: .trailing)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * (1 - CGFloat(tick) / CGFloat(axisMax)))
            }
        }
        .accessibilityHidden(true)
    }

    /// Líneas guía horizontales: la base continua, el resto punteadas.
    private var gridLines: some View {
        GeometryReader { proxy in
            ForEach(axisTicks, id: \.self) { tick in
                let y = proxy.size.height * (1 - CGFloat(tick) / CGFloat(axisMax))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(
                    tick == 0 ? Color.hairline : Color.hairline.opacity(0.7),
                    style: StrokeStyle(lineWidth: 1, dash: tick == 0 ? [] : [3, 3])
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func legend(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.appCaption())
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: Histórico

/// Histórico completo: chips de filtro con contador, buscador y línea de ruta
/// agrupada por año. Cada parada abre el territorio.
struct BrotherHistorySection: View {
    @ObservedObject var viewModel: BrotherDetailViewModel
    let onOpen: (PersonAssignment) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let groups = viewModel.historyGroups

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(
                title: "brother.detail.history.title",
                systemImage: "clock.arrow.circlepath",
                count: viewModel.detail?.history.isEmpty == false ? viewModel.detail?.history.count : nil
            )

            if viewModel.detail?.history.isEmpty == false {
                filters
                searchField
            }

            if groups.isEmpty {
                CartoEmptyState(
                    systemImage: "map",
                    message: viewModel.detail?.history.isEmpty == false ? "brother.detail.history.empty_filtered" : "brother.detail.history.empty"
                )
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(groups) { group in
                        yearHeader(group.year)
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                BrotherHistoryRow(
                                    item: item,
                                    isFirst: index == 0,
                                    isLast: index == group.items.count - 1
                                ) { onOpen(item) }
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
                            }
                        }
                        .padding(.vertical, AppSpacing.xxs)
                        .paperCard(cornerRadius: AppRadius.lg)
                    }

                    if viewModel.remainingHistoryCount > 0 {
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                                viewModel.showMoreHistory()
                            }
                        } label: {
                            Label(
                                String(format: String.localized("brother.detail.history.show_more"), viewModel.remainingHistoryCount),
                                systemImage: "chevron.down"
                            )
                            .font(.appSubheadline().weight(.semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .tint(.accentDeep)
                        .controlSize(.large)
                        .padding(.top, AppSpacing.xs)
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: viewModel.historyFilter)
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(BrotherHistoryFilter.allCases) { filter in
                    chip(filter)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private func chip(_ filter: BrotherHistoryFilter) -> some View {
        let selected = viewModel.historyFilter == filter
        let count = viewModel.count(for: filter)
        return Button {
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.setFilter(filter)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: filter.systemImage)
                    .font(.caption2.weight(.bold))
                Text(filter.titleKey)
                    .font(.appCaption().weight(.medium))
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(selected ? Color.white.opacity(0.22) : Color.accent.opacity(0.12), in: Capsule())
            }
            .foregroundStyle(selected ? .white : Color.textPrimary)
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: 32)
        }
        .glassEffect(selected ? .regular.tint(.accent).interactive() : .regular.interactive(), in: .capsule)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .disabled(filter != .all && count == 0)
        .opacity(filter != .all && count == 0 ? 0.45 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            TextField("brother.detail.history.search", text: $viewModel.historySearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !viewModel.historySearch.isEmpty {
                Button {
                    viewModel.historySearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.clear"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
        .onChange(of: viewModel.historySearch) { _, _ in
            viewModel.historyLimit = BrotherDetailViewModel.historyPage
        }
    }

    private func yearHeader(_ year: Int) -> some View {
        Text(String(year))
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(Color.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            .padding(.top, AppSpacing.xs)
    }
}

/// Parada de la ruta: nodo (relleno = devuelto, anillo = en curso), código,
/// fechas entrega → devolución y duración teñida por antigüedad.
private struct BrotherHistoryRow: View {
    let item: PersonAssignment
    let isFirst: Bool
    let isLast: Bool
    let onOpen: () -> Void

    private var tint: Color { item.isOngoing ? Color.urgency(forDays: item.days) : .accent }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                routeNode

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(item.territoryCode)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.accentDeep)
                        if item.territoryName != item.territoryCode {
                            Text(item.territoryName)
                                .font(.appCaption())
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                        }
                        if item.deliveryFormat == .virtual {
                            Image(systemName: DeliveryFormat.virtual.systemImage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(DeliveryFormat.virtual.tint)
                                .accessibilityLabel(Text("delivery_format.virtual"))
                        }
                    }

                    HStack(spacing: 4) {
                        Text(item.givenAt.formatted(date: .abbreviated, time: .omitted))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                        if let picked = item.pickedAt {
                            Text(picked.formatted(date: .abbreviated, time: .omitted))
                        } else {
                            Text("territory.detail.trajectory.ongoing")
                                .fontWeight(.semibold)
                                .foregroundStyle(tint)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, AppSpacing.xs + 2)

                Spacer(minLength: AppSpacing.xs)

                Text(String(format: String.localized("brothers.days_format"), item.days))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(item.isOngoing ? tint : Color.textPrimary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background((item.isOngoing ? tint : Color.textSecondary).opacity(0.12), in: Capsule())
            }
            // Altura ideal del contenido: así el nodo estira sus tramos de ruta a toda la fila.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("brothers.territory.open_hint"))
    }

    /// Nodo con tramos de ruta punteada arriba y abajo que enlazan las paradas.
    private var routeNode: some View {
        VStack(spacing: 0) {
            DashedSegment()
                .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 2)
                .opacity(isFirst ? 0 : 1)
            ZStack {
                if item.isOngoing {
                    Circle().strokeBorder(tint, lineWidth: 2.5).frame(width: 12, height: 12)
                } else {
                    Circle().fill(tint).frame(width: 10, height: 10)
                }
            }
            .frame(width: 14, height: 14)
            DashedSegment()
                .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 2)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 14)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private struct DashedSegment: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: 0))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return p
        }
    }
}
