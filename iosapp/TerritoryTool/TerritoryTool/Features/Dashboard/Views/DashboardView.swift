import Charts
import MapKit
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
                onFree: { router.openTerritories(.free) },
                onGiven: { showGivenActivity = true },
                onInUse: { router.openTerritories(.inUse) }
            )
            .appear(index: 2)

            HStack(alignment: .top, spacing: AppSpacing.sm) {
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

                Button {
                    router.openTerritories(.attentionMap)
                } label: {
                    GeographicAttentionCard(
                        territories: snapshot.attentionTerritories,
                        clusters: viewModel.geographicClusters
                    )
                }
                .buttonStyle(.plain)
            }
            .appear(index: 3)

            if let latest = snapshot.latestEvent {
                NavigationLink {
                    WeeklyActivityView(events: snapshot.weeklyEvents, viewModel: viewModel)
                } label: {
                    LatestMovementTicker(movement: latest)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if viewModel.canEditTransactions {
                        Button {
                            editingEvent = latest.transactionEvent
                        } label: {
                            Label("common.edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            eventToDelete = latest.transactionEvent
                            showDeleteConfirmation = true
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
                .appear(index: 4)
            } else {
                CartoEmptyState(
                    systemImage: "checkmark.seal.fill",
                    message: "dashboard.no_weekly_activity",
                    tint: .accent
                )
                .appear(index: 4)
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

/// Avatar circular con iniciales y gradiente de acento.
private struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.accentDeep)
            .frame(width: size, height: size)
            .background(Color.accent.opacity(0.14), in: Circle())
            .overlay(Circle().strokeBorder(Color.accent.opacity(0.28), lineWidth: 1))
            .accessibilityHidden(true)
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
                    message: "dashboard.priority.all_available",
                    tint: .accent
                )
            }
        }
    }

    private func cardContent(_ priority: DashboardPriority) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                priorityLabel

                Text(
                    String(
                        format: String(localized: "dashboard.priority.headline"),
                        priority.code,
                        days
                    )
                )
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.accentDeep)
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
        .overlay(alignment: .topTrailing) { detailChevron(priority) }
        .compositingGroup()
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
    }

    // MARK: Piezas

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

    private func detailChevron(_ priority: DashboardPriority) -> some View {
        NavigationLink {
            TerritoryDetailView(
                territoryId: priority.territoryId,
                territoryName: priority.name
            )
        } label: {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 30, height: 30)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .padding(AppSpacing.sm)
    }

    /// Mapa real (rasterizado) como fondo de la tarjeta: el bounding box queda
    /// hacia la derecha (zona nítida) y se desvanece hacia la izquierda. Al ser
    /// imagen + vector, las esquinas se enmascaran con antialias (sin pixelado).
    @ViewBuilder
    private func mapBleed(_ priority: DashboardPriority) -> some View {
        if let geometry = priority.mapGeometry {
            TerritorySnapshotBackdrop(geometry: geometry)
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
    let onFree: () -> Void
    let onGiven: () -> Void
    let onInUse: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                FlowMetric(value: totals.free, label: "dashboard.flow.free", tint: .accentDeep, action: onFree)
                FlowMetric(value: totals.givenThisWeek, label: "dashboard.flow.given", tint: .accentSecondary, action: onGiven)
                FlowMetric(value: totals.inUse, label: "dashboard.flow.in_use", tint: .accentTertiary, action: onInUse)
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
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Vía continua con tres iconos conectados por una línea: arranca antes del
/// primer icono y continúa tras el último, con tres puntos entre cada par.
private struct FlowTrack: View {
    private let tints: [Color] = [.accentDeep, .accentSecondary, .accentTertiary]
    private let icons = ["leaf.fill", "gift.fill", "person.3.fill"]

    var body: some View {
        HStack(spacing: 0) {
            FlowLine(colors: [tints[0], tints[0]])
            FlowGlowIcon(systemImage: icons[0], tint: tints[0])
            FlowConnector(from: tints[0], to: tints[1])
            FlowGlowIcon(systemImage: icons[1], tint: tints[1])
            FlowConnector(from: tints[1], to: tints[2])
            FlowGlowIcon(systemImage: icons[2], tint: tints[2])
            FlowLine(colors: [tints[2], tints[2]])
        }
        .accessibilityHidden(true)
    }
}

/// Tramo de línea (sin puntos) para los extremos de la vía.
private struct FlowLine: View {
    let colors: [Color]

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: colors.map { $0.opacity(0.5) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 3)
            .frame(maxWidth: .infinity)
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
                        LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: tint.opacity(0.28), radius: 4, x: 0, y: 2)
    }
}

private struct FlowConnector: View {
    let from: Color
    let to: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [from.opacity(0.5), to.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.textSecondary.opacity(0.45))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accent)
                Text("dashboard.week.title")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
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
            .frame(minHeight: 96, maxHeight: .infinity)
            .accessibilityLabel(Text("dashboard.week.accessibility"))
        }
        .frame(maxWidth: .infinity, minHeight: 232, alignment: .topLeading)
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.xl)
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

private struct GeographicAttentionCard: View {
    let territories: [DashboardAttentionTerritory]
    let clusters: [DashboardGeographicCluster]

    private var headline: String {
        if clusters.isEmpty {
            return String(
                format: String(localized: "dashboard.geography.no_geometry"),
                territories.count
            )
        }
        return String(
            format: String(localized: "dashboard.geography.summary"),
            clusters.count,
            territories.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if territories.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentTertiary)
                    Text("dashboard.geography.title")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer(minLength: 0)
                Label("dashboard.geography.empty", systemImage: "checkmark.seal.fill")
                    .font(.appSubheadline())
                    .foregroundStyle(Color.accent)
                Spacer(minLength: 0)
            } else {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentTertiary)
                    Text(headline)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if clusters.isEmpty {
                    Spacer(minLength: 0)
                } else {
                    attentionMap
                }

                HStack(spacing: AppSpacing.xxs) {
                    Text("dashboard.geography.cta")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.accentTertiary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(Color.accentTertiary.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 232, alignment: .topLeading)
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.xl)
    }

    private var attentionMap: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            ForEach(clusters) { cluster in
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(
                        latitude: cluster.latitude,
                        longitude: cluster.longitude
                    )
                ) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.accentTertiary.opacity(0.5), .clear],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.accentTertiary)
                            .background(Circle().fill(.white).padding(2))
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .clipShape(.rect(cornerRadius: AppRadius.lg))
        .allowsHitTesting(false)
    }
}

private struct LatestMovementTicker: View {
    let movement: DashboardMovement
    var showsChevron = true

    private var isReturn: Bool { movement.eventType == .returned }
    private var eventTint: Color { isReturn ? .accentTertiary : .accentSecondary }
    private var eventIcon: String { isReturn ? "tray.and.arrow.down.fill" : "gift.fill" }

    private var summary: String {
        String(
            format: String(localized: isReturn ? "dashboard.latest.returned_by" : "dashboard.latest.given_to"),
            movement.territoryCode,
            movement.personName
        )
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.accent, in: Circle())

            InitialsAvatar(name: movement.personName, size: 34)

            Image(systemName: eventIcon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(eventTint)
                .frame(width: 30, height: 30)
                .background(eventTint.opacity(0.14), in: Circle())

            Text(summary)
                .font(.appSubheadline())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Spacer(minLength: AppSpacing.xs)

            Text(movement.eventDate, style: .relative)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(AppSpacing.sm)
        .paperCard(cornerRadius: AppRadius.xl)
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
                    LatestMovementTicker(movement: movement, showsChevron: false)
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

private extension DashboardMovement {
    var transactionEvent: TransactionEvent {
        TransactionEvent(
            txnId: transactionId,
            type: eventType == .given ? .given : .returned,
            date: eventDate,
            transaction: transaction
        )
    }
}
