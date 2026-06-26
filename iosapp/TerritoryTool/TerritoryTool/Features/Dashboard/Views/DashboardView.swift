import Charts
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DIContainer.shared.makeDashboardViewModel()
    @ObservedObject private var router = AppRouter.shared
    @State private var editingEvent: TransactionEvent?
    @State private var eventToDelete: TransactionEvent?
    @State private var showDeleteConfirmation = false
    @State private var showGivenActivity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                DashboardHeader(
                    greetingKey: viewModel.greetingKey,
                    userName: viewModel.userName
                )
                .appear(index: 0)

                content
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackgroundView() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CongregationSwitcher()
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("settings.title"))
            }
        }
        .refreshable { await viewModel.loadDashboard() }
        .task { await viewModel.loadDashboard() }
        .task { await CongregationStore.shared.refresh() }
        .sheet(item: $editingEvent) { event in
            EditTransactionSheet(
                transactionEvent: event,
                isPresented: Binding(
                    get: { editingEvent != nil },
                    set: { if !$0 { editingEvent = nil } }
                ),
                onComplete: { await viewModel.loadDashboard() }
            )
        }
        .alert(
            "common.delete_confirmation",
            isPresented: $showDeleteConfirmation,
            presenting: eventToDelete
        ) { event in
            Button("common.delete", role: .destructive) {
                Task { await viewModel.deleteTransaction(event: event) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("dashboard.delete_transaction_message")
        }
        .navigationDestination(isPresented: $showGivenActivity) {
            if let snapshot = viewModel.snapshot {
                WeeklyActivityView(
                    events: snapshot.weeklyEvents,
                    viewModel: viewModel,
                    initialFilter: .given
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.snapshot == nil {
            DashboardLoadingView()
        } else if let error = viewModel.errorMessage, viewModel.snapshot == nil {
            ContentUnavailableView {
                Label("common.error", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("common.retry") {
                    Task { await viewModel.loadDashboard() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: 380)
        } else if let snapshot = viewModel.snapshot {
            DailyPriorityCard(
                priority: snapshot.priority,
                days: viewModel.priorityDays
            )
            .appear(index: 1)

            TerritoryFlowView(
                totals: snapshot.totals,
                attentionCount: snapshot.attentionTerritories.count,
                onFree: { router.openTerritories(.free) },
                onGiven: { showGivenActivity = true },
                onInUse: { router.openTerritories(.inUse) },
                onAttention: { router.openTerritories(.attention) }
            )
            .appear(index: 2)

            NavigationLink {
                WeeklyActivityView(events: snapshot.weeklyEvents, viewModel: viewModel)
            } label: {
                WeeklyActivityChart(
                    activity: snapshot.activity,
                    givenTotal: viewModel.totalGivenThisWeek,
                    returnedTotal: viewModel.totalReturnedThisWeek
                )
            }
            .buttonStyle(.plain)
            .appear(index: 3)

            RecentMovementsSection(
                movements: snapshot.recentEvents,
                showsSeeAll: snapshot.hasMoreRecentEvents,
                actionViewModel: viewModel,
                onEdit: { editingEvent = $0.transactionEvent },
                onDelete: {
                    eventToDelete = $0.transactionEvent
                    showDeleteConfirmation = true
                }
            )
            .appear(index: 4)
        }
    }
}

private struct RecentMovementsSection: View {
    let movements: [DashboardMovement]
    let showsSeeAll: Bool
    @ObservedObject var actionViewModel: DashboardViewModel
    let onEdit: (DashboardMovement) -> Void
    let onDelete: (DashboardMovement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Label("dashboard.recent_movements", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if showsSeeAll {
                    NavigationLink {
                        MovementHistoryView(actionViewModel: actionViewModel)
                    } label: {
                        Text("dashboard.see_all")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if movements.isEmpty {
                CartoEmptyState(
                    systemImage: "checkmark.seal.fill",
                    message: "dashboard.no_movements",
                    tint: .accent
                )
            } else {
                List {
                    ForEach(movements) { movement in
                        MovementRow(movement: movement)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 2,
                                    leading: 0,
                                    bottom: 2,
                                    trailing: 0
                                )
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(allowsFullSwipe: false) {
                                if actionViewModel.canEditTransactions {
                                    Button(role: .destructive) {
                                        onDelete(movement)
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }

                                    Button {
                                        onEdit(movement)
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }
                                    .tint(.accent)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(0)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(movements.count) * 80)
            }
        }
    }
}

private struct DashboardHeader: View {
    let greetingKey: String
    let userName: String

    private var greeting: String {
        let greeting = NSLocalizedString(greetingKey, comment: "")
        let firstName = userName.split(separator: " ").first.map(String.init) ?? ""
        return firstName.isEmpty ? greeting : "\(greeting), \(firstName)"
    }

    var body: some View {
        Text(greeting)
            .font(.system(.title, design: .rounded).weight(.bold))
            .foregroundStyle(Color.accentDeep)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}


private struct DailyPriorityCard: View {
    let priority: DashboardPriority?
    let days: Int

    /// Resalte ámbar/dorado del mockup (independiente de la urgencia, que ya
    /// queda reflejada en el número de días del titular).
    private let highlight = Color.accentSecondary

    var body: some View {
        if let priority {
            cardContent(priority)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                priorityLabel
                CartoEmptyState(
                    systemImage: "checkmark.seal.fill",
                    message: "dashboard.priority.none_overdue",
                    tint: .accent
                )
            }
        }
    }

    private func cardContent(_ priority: DashboardPriority) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                priorityLabel

                Text(headline(code: priority.code))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.xs) {
                    InitialsAvatar(name: priority.personName, size: 36)
                    Text(priority.personName)
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
            }
            // Deja libre el flanco derecho para que el territorio se vea sin estorbos.
            .padding(.trailing, 104)

            HStack(spacing: AppSpacing.sm) {
                NavigationLink {
                    TerritoryDetailView(
                        territoryId: priority.territoryId,
                        territoryName: priority.name
                    )
                } label: {
                    Label("dashboard.priority.view", systemImage: "map.fill")
                        .font(.appSubheadline().weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.accentDeep)

                NavigationLink {
                    TerritoryReturnView(territory: priority.territory)
                } label: {
                    Label("territory.detail.return", systemImage: "tray.and.arrow.down.fill")
                        .font(.appSubheadline().weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .tint(.accentDeep)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) { mapBleed(priority) }
        .background {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color.surface)
        }
        .overlay { glassBorder }
        .compositingGroup()
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
    }

    // MARK: Piezas

    /// Titular "AVxxx lleva N días asignado" con el tramo "N días" resaltado
    /// (color ámbar + peso fuerte) para que la vista vaya directa a la antigüedad.
    private func headline(code: String) -> AttributedString {
        let full = String(
            format: String(localized: "dashboard.priority.headline"),
            code,
            days
        )
        var attributed = AttributedString(full)
        attributed.foregroundColor = .accentDeep
        attributed.font = .system(.title2, design: .rounded).weight(.bold)

        if let numberRange = attributed.range(of: "\(days)") {
            let characters = attributed.characters
            var end = numberRange.upperBound
            // Salta el espacio y abarca la palabra de unidad ("días"/"days").
            while end < attributed.endIndex, characters[end] == " " {
                end = characters.index(after: end)
            }
            while end < attributed.endIndex, characters[end] != " " {
                end = characters.index(after: end)
            }
            let highlightRange = numberRange.lowerBound..<end
            attributed[highlightRange].foregroundColor = highlight
            attributed[highlightRange].font = .system(.title2, design: .rounded).weight(.heavy)
        }
        return attributed
    }

    private var priorityLabel: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "star.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(
                        colors: [highlight, highlight.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: highlight.opacity(0.5), radius: 5, x: 0, y: 2)
            Text("dashboard.priority.title")
                .font(.appSubheadline().weight(.bold))
                .foregroundStyle(highlight)
        }
    }

    /// Borde tipo cristal: trazo ámbar con degradado (más intenso arriba y en
    /// las esquinas) y un reflejo blanco superior sutil.
    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [highlight.opacity(0.9), highlight.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    /// Mapa real (rasterizado) como fondo de la tarjeta: el bounding box queda
    /// hacia la derecha (zona nítida) y se desvanece hacia la izquierda. Al ser
    /// imagen + vector, las esquinas se enmascaran con antialias (sin pixelado).
    @ViewBuilder
    private func mapBleed(_ priority: DashboardPriority) -> some View {
        if let geometry = priority.mapGeometry {
            TerritorySnapshotBackdrop(geometry: geometry, verticalBias: 0.22)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black.opacity(0.5), location: 0.30),
                            .init(color: .black, location: 0.55),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                )
        }
    }
}

private struct TerritoryFlowView: View {
    let totals: DashboardTotals
    let attentionCount: Int
    let onFree: () -> Void
    let onGiven: () -> Void
    let onInUse: () -> Void
    let onAttention: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                FlowMetric(value: totals.free, label: "dashboard.flow.free", tint: .accentDeep, action: onFree)
                FlowMetric(value: totals.givenThisWeek, label: "dashboard.flow.given", tint: .accentSecondary, action: onGiven)
                FlowMetric(value: totals.inUse, label: "dashboard.flow.in_use", tint: .accentTertiary, action: onInUse)
                FlowMetric(value: attentionCount, label: "dashboard.flow.attention", tint: .danger, action: onAttention)
            }

            FlowTrack()
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.xl)
    }
}

private struct FlowMetric: View {
    let value: Int
    let label: LocalizedStringKey
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Vía continua con cuatro iconos conectados por una línea, alineados con las
/// cuatro métricas mostradas encima.
private struct FlowTrack: View {
    private let tints: [Color] = [.accentDeep, .accentSecondary, .accentTertiary, .danger]
    private let icons = ["leaf.fill", "gift.fill", "person.3.fill", "exclamationmark.triangle.fill"]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let y = geo.size.height / 2
            let centers = (0..<tints.count).map { index in
                w * (CGFloat(index) + 0.5) / CGFloat(tints.count)
            }
            ZStack {
                FlowSegment(x0: 0, x1: centers[0], y: y, from: tints[0], to: tints[0], dots: false)
                ForEach(0..<(tints.count - 1), id: \.self) { index in
                    FlowSegment(
                        x0: centers[index],
                        x1: centers[index + 1],
                        y: y,
                        from: tints[index],
                        to: tints[index + 1],
                        dots: true
                    )
                }
                FlowSegment(
                    x0: centers[centers.count - 1],
                    x1: w,
                    y: y,
                    from: tints[tints.count - 1],
                    to: tints[tints.count - 1],
                    dots: false
                )

                ForEach(0..<tints.count, id: \.self) { index in
                    FlowGlowIcon(systemImage: icons[index], tint: tints[index])
                        .position(x: centers[index], y: y)
                }
            }
        }
        .frame(height: 54)
        .accessibilityHidden(true)
    }
}

/// Un tramo de la vía: línea con degradado de color origen→destino y, opcional,
/// tres puntos opacos que transicionan entre ambos colores.
private struct FlowSegment: View {
    let x0: CGFloat
    let x1: CGFloat
    let y: CGFloat
    let from: Color
    let to: Color
    var dots: Bool

    var body: some View {
        let width = max(x1 - x0, 0)
        let midX = (x0 + x1) / 2

        ZStack {
            Capsule()
                .fill(
                    LinearGradient(colors: [from, to], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: width, height: 3)
                .position(x: midX, y: y)

            if dots {
                HStack(spacing: 7) {
                    Circle().fill(from.blended(with: to, amount: 0.25)).frame(width: 6, height: 6)
                    Circle().fill(from.blended(with: to, amount: 0.5)).frame(width: 6, height: 6)
                    Circle().fill(from.blended(with: to, amount: 0.75)).frame(width: 6, height: 6)
                }
                .fixedSize()
                .position(x: midX, y: y)
            }
        }
    }
}

private struct FlowGlowIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(
                Circle()
                    .fill(
                        // Degradado opaco (oscurece en vez de bajar alpha) para que
                        // la línea de la vía no se transparente a través del círculo.
                        LinearGradient(
                            colors: [tint, tint.blended(with: .black, amount: 0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: tint.opacity(0.28), radius: 4, x: 0, y: 2)
    }
}

private struct WeeklyActivityChart: View {
    let activity: [DashboardDailyActivity]
    let givenTotal: Int
    let returnedTotal: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated = false

    private static let givenColor = Color.accent
    private static let returnedColor = Color.accentSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("dashboard.week.title", systemImage: "waveform.path.ecg")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.md) {
                    ActivityLegend(value: givenTotal, label: "dashboard.week.given", color: Self.givenColor)
                    ActivityLegend(value: returnedTotal, label: "dashboard.week.returned", color: Self.returnedColor)
                }

                Chart(activity) { day in
                    AreaMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Given", animated ? day.givenCount : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Self.givenColor.opacity(0.25), Self.givenColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Returned", animated ? day.returnedCount : 0),
                        series: .value("Series", "returned")
                    )
                    .foregroundStyle(Self.returnedColor)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Given", animated ? day.givenCount : 0),
                        series: .value("Series", "given")
                    )
                    .foregroundStyle(Self.givenColor)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 104)
                .accessibilityLabel(Text("dashboard.week.accessibility"))
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(AppSpacing.md)
            .paperCard(cornerRadius: AppRadius.xl)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            guard !reduceMotion else { animated = true; return }
            withAnimation(.easeOut(duration: 0.8)) { animated = true }
        }
    }
}

private struct ActivityLegend: View {
    let value: Int
    let label: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(value)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
    }
}

struct MovementRow: View {
    let movement: DashboardMovement

    private var isReturn: Bool { movement.eventType == .returned }
    private var eventTint: Color { isReturn ? .accent : .accentSecondary }
    private var eventIcon: String { isReturn ? "arrow.down.left" : "arrow.up.right" }

    private var personSummary: String {
        String(
            format: String(localized: isReturn ? "movements.returned_by" : "movements.given_to"),
            movement.personName
        )
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: eventIcon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    LinearGradient(colors: [eventTint, eventTint.opacity(0.78)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: eventTint.opacity(0.35), radius: 5, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppSpacing.xs) {
                    Text(movement.territoryCode)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(eventTint)
                    Text(movement.territoryName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Text(personSummary)
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                Text(
                    String(
                        format: String(localized: "movements.recorded_by"),
                        movement.actorName
                    )
                )
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.xs)

            VStack(alignment: .trailing, spacing: 3) {
                Text(isReturn ? "movements.returned" : "movements.given")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(eventTint)
                    .textCase(.uppercase)
                Text(movement.eventDate, style: .relative)
                    .font(.appCaption().monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }
}

private struct DashboardLoadingView: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(Color.surface)
                    .frame(height: index == 0 ? 280 : 180)
                    .overlay(ProgressView().tint(.accent))
            }
        }
    }
}

enum WeeklyActivityFilter: String, CaseIterable, Identifiable {
    case all
    case given
    case returned

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "dashboard.week.filter.all"
        case .given: "dashboard.week.filter.given"
        case .returned: "dashboard.week.filter.returned"
        }
    }
}

struct WeeklyActivityView: View {
    let events: [DashboardMovement]
    @ObservedObject var viewModel: DashboardViewModel
    @State private var filter: WeeklyActivityFilter
    @State private var editingEvent: TransactionEvent?
    @State private var eventToDelete: TransactionEvent?
    @State private var showDeleteConfirmation = false

    init(
        events: [DashboardMovement],
        viewModel: DashboardViewModel,
        initialFilter: WeeklyActivityFilter = .all
    ) {
        self.events = events
        self.viewModel = viewModel
        _filter = State(initialValue: initialFilter)
    }

    private var filteredEvents: [DashboardMovement] {
        let source = viewModel.snapshot?.weeklyEvents ?? events
        return switch filter {
        case .all: source
        case .given: source.filter { $0.eventType == .given }
        case .returned: source.filter { $0.eventType == .returned }
        }
    }

    var body: some View {
        List {
            Picker("dashboard.week.filter.title", selection: $filter) {
                ForEach(WeeklyActivityFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "dashboard.no_weekly_activity",
                    systemImage: "calendar.badge.clock"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredEvents) { movement in
                    MovementRow(movement: movement)
                        .listRowInsets(
                            EdgeInsets(
                                top: AppSpacing.xs,
                                leading: AppSpacing.md,
                                bottom: AppSpacing.xs,
                                trailing: AppSpacing.md
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(allowsFullSwipe: false) {
                            if viewModel.canEditTransactions {
                                Button(role: .destructive) {
                                    eventToDelete = movement.transactionEvent
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                                Button {
                                    editingEvent = movement.transactionEvent
                                } label: {
                                    Label("common.edit", systemImage: "pencil")
                                }
                                .tint(.accent)
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { LiquidBackgroundView() }
        .navigationTitle("dashboard.week.activity")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEvent) { event in
            EditTransactionSheet(
                transactionEvent: event,
                isPresented: Binding(
                    get: { editingEvent != nil },
                    set: { if !$0 { editingEvent = nil } }
                ),
                onComplete: { await viewModel.loadDashboard() }
            )
        }
        .alert(
            "common.delete_confirmation",
            isPresented: $showDeleteConfirmation,
            presenting: eventToDelete
        ) { event in
            Button("common.delete", role: .destructive) {
                Task { await viewModel.deleteTransaction(event: event) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("dashboard.delete_transaction_message")
        }
    }
}
