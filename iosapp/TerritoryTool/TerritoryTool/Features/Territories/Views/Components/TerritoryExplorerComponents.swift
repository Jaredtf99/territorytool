import CoreLocation
import SwiftUI

struct TerritoryExplorerControls: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    let locationService: TerritoryLocationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                searchField
                sortMenu
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(TerritoryFilter.allCases) { filter in
                        filterChip(filter)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            TextField("territories.search_explorer", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityLabel(Text("common.clear"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(minHeight: 50)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var sortMenu: some View {
        Menu {
            Picker("territories.sort.title", selection: Binding(
                get: { viewModel.sortOption },
                set: { newValue, _ in
                    viewModel.sortOption = newValue
                    if newValue == .nearest { locationService.requestLocation() }
                }
            )) {
                ForEach(TerritorySortOption.allCases) {
                    Text($0.localizedName).tag($0)
                }
            }
            Button {
                viewModel.sortAscending.toggle()
            } label: {
                Label(
                    viewModel.sortAscending ? "territories.sort.ascending" : "territories.sort.descending",
                    systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                )
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.appHeadline())
                .foregroundStyle(Color.accentDeep)
                .frame(width: 50, height: 50)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel(Text("territories.sort.title"))
    }

    @ViewBuilder
    private func filterChip(_ filter: TerritoryFilter) -> some View {
        let selected = viewModel.filterStatus == filter
        Button {
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78)) {
                viewModel.filterStatus = filter
                viewModel.select(nil)
            }
        } label: {
            HStack(spacing: 6) {
                filterIndicator(filter, selected: selected)
                Text(filter.localizedName)
                    .font(.appSubheadline())
                    .foregroundStyle(selected ? .white : Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 44)
        }
        .glassEffect(
            selected ? .regular.tint(.accent).interactive() : .regular.interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func filterIndicator(_ filter: TerritoryFilter, selected: Bool) -> some View {
        if filter == .all {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(selected ? .white : Color.accent)
        } else {
            Circle()
                .fill(selected ? Color.white : filter.dotColor)
                .frame(width: 9, height: 9)
        }
    }
}

extension TerritoryFilter {
    /// Punto de color del chip según el estado que representa.
    var dotColor: Color {
        switch self {
        case .all, .free: .accent
        case .inUse: .accentSecondary
        case .attention: .accentTertiary
        }
    }
}

struct TerritoryExplorerList: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    let locationService: TerritoryLocationService
    var topInset: CGFloat = 0
    let onAssign: (Territory) -> Void
    let onReturn: (Territory) -> Void
    let onEdit: (Territory) -> Void
    let onDelete: (Territory) -> Void
    @ObservedObject private var permissionManager = PermissionManager.shared

    var body: some View {
        List {
            resultsHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                section("territories.section.results", icon: "magnifyingglass", tint: .accent, territories: ordered(viewModel.displayedTerritories))
            } else {
                section("territories.section.attention", icon: "exclamationmark.triangle.fill", tint: .accentTertiary, territories: ordered(viewModel.attentionTerritories))
                section("territories.section.available", icon: "checkmark.circle.fill", tint: .accent, territories: ordered(viewModel.availableTerritories))
                section("territories.section.assigned", icon: "person.crop.circle.fill", tint: .accentSecondary, territories: ordered(viewModel.assignedTerritories))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, topInset, for: .scrollContent)
        .contentMargins(.bottom, AppSpacing.xl)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: viewModel.sortedTerritories)
        .refreshable {
            await viewModel.loadTerritories()
            HapticManager.shared.notification(type: .success)
        }
    }

    private var resultsHeader: some View {
        HStack {
            Text(String(format: String.localized("territories.summary"), viewModel.displayedTerritories.count, viewModel.attentionTerritories.count))
                .font(.appSubheadline())
                .foregroundStyle(Color.textSecondary)
                .contentTransition(.numericText())
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xs)
    }

    @ViewBuilder
    private func section(
        _ title: LocalizedStringKey,
        icon: String,
        tint: Color,
        territories: [Territory]
    ) -> some View {
        if !territories.isEmpty {
            Section {
                ForEach(territories) { territory in
                    NavigationLink {
                        TerritoryDetailView(territoryId: territory.id, territoryName: territory.name)
                    } label: {
                        TerritoryExplorerRow(territory: territory, attentionDays: viewModel.attentionDays)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: AppSpacing.xxs, leading: AppSpacing.md, bottom: AppSpacing.xxs, trailing: AppSpacing.md))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if territory.personName == nil {
                            Button { onAssign(territory) } label: {
                                Label("assignment.title", systemImage: "person.badge.plus")
                            }
                            .tint(.accent)
                        } else {
                            Button { onReturn(territory) } label: {
                                Label("return.title", systemImage: "tray.and.arrow.down")
                            }
                            .tint(.accentSecondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if permissionManager.canManageTerritories {
                            Button(role: .destructive) { onDelete(territory) } label: {
                                Label("territory.detail.delete", systemImage: "trash")
                            }
                            Button { onEdit(territory) } label: {
                                Label("territory.detail.edit", systemImage: "pencil")
                            }
                            .tint(.accent)
                        }
                    }
                    .contextMenu {
                        Button { territory.personName == nil ? onAssign(territory) : onReturn(territory) } label: {
                            Label(
                                territory.personName == nil ? "assignment.title" : "return.title",
                                systemImage: territory.personName == nil ? "person.badge.plus" : "tray.and.arrow.down"
                            )
                        }
                        if permissionManager.canManageTerritories {
                            Button { onEdit(territory) } label: {
                                Label("territory.detail.edit", systemImage: "pencil")
                            }
                        }
                    } preview: {
                        TerritoryExplorerRow(territory: territory, attentionDays: viewModel.attentionDays)
                            .frame(width: 340)
                            .padding()
                            .background(Color.appBackground)
                    }
                }
            } header: {
                CartoSectionHeader(title: title, systemImage: icon, count: territories.count, tint: tint)
                    .textCase(nil)
                    .padding(.horizontal, AppSpacing.xxs)
            }
        }
    }

    private func ordered(_ territories: [Territory]) -> [Territory] {
        guard viewModel.sortOption == .nearest, let location = locationService.location else { return territories }
        return territories.sorted {
            distance(from: location, to: $0) < distance(from: location, to: $1)
        }
    }

    private func distance(from location: CLLocation, to territory: Territory) -> CLLocationDistance {
        guard let coordinate = territory.mapGeometry?.representativeCoordinate else { return .greatestFiniteMagnitude }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

struct TerritoryExplorerRow: View {
    let territory: Territory
    let attentionDays: Int

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            TerritoryPolygonThumbnail(geometry: territory.mapGeometry, tint: status.color)
                            .frame(width: 54, height: 54)
            
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(territory.code)
                        .font(.appCaption().weight(.bold))
                        .foregroundStyle(status.color)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 3)
                        .background(status.color.opacity(0.12), in: .capsule)
                    Text(territory.name)
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                if let personName = territory.personName {
                    Text(personName)
                        .font(.appSubheadline())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                Label(status.detail, systemImage: status.icon)
                    .font(.appCaption())
                    .foregroundStyle(status.color)
            }
            Spacer(minLength: AppSpacing.xxs)
        }
        .padding(AppSpacing.sm)
        .paperCard(cornerRadius: AppRadius.lg)
        .accessibilityElement(children: .combine)
    }

    private var status: TerritoryStatusPresentation {
        TerritoryStatusPresentation(territory.operationalStatus(attentionDays: attentionDays))
    }
}

struct TerritoryPolygonThumbnail: View {
    let geometry: TerritoryMapGeometry?
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard let geometry, let polygon = geometry.polygons.max(by: { $0.coordinates.count < $1.coordinates.count }),
                  !polygon.coordinates.isEmpty else {
                context.draw(
                    Text(Image(systemName: "map")).font(.title2).foregroundStyle(tint),
                    at: CGPoint(x: size.width / 2, y: size.height / 2)
                )
                return
            }
            let points = polygon.coordinates
            let minLat = points.map(\.latitude).min() ?? 0
            let maxLat = points.map(\.latitude).max() ?? 1
            let minLon = points.map(\.longitude).min() ?? 0
            let maxLon = points.map(\.longitude).max() ?? 1
            let latSpan = max(maxLat - minLat, 0.000001)
            let lonSpan = max(maxLon - minLon, 0.000001)
            var path = Path()
            for (index, point) in points.enumerated() {
                let x = 7 + ((point.longitude - minLon) / lonSpan) * (size.width - 14)
                let y = 7 + (1 - (point.latitude - minLat) / latSpan) * (size.height - 14)
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
            context.fill(path, with: .color(tint.opacity(0.16)))
            context.stroke(path, with: .color(tint), lineWidth: 2)
        }
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Conmutador flotante Mapa / Lista que se superpone al contenido (estilo mockup).
struct PresentationToggle: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            segment(.map, title: "territories.presentation.map")
            segment(.list, title: "territories.presentation.list")
        }
        .padding(4)
        .contentShape(Capsule())
        .glassEffect(.regular, in: .capsule)
    }

    private func segment(_ value: TerritoriesPresentation, title: LocalizedStringKey) -> some View {
        let selected = viewModel.presentation == value
        return Button {
            guard !selected else { return }
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.84)) {
                viewModel.setPresentation(value)
            }
        } label: {
            Text(title)
                .font(.appSubheadline().weight(.semibold))
                .foregroundStyle(selected ? .white : Color.textPrimary)
                .frame(minWidth: 72, minHeight: 40)
                .contentShape(Rectangle())
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.accent)
                            .matchedGeometryEffect(id: "presentation.segment", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            icon = "checkmark.circle.fill"
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
