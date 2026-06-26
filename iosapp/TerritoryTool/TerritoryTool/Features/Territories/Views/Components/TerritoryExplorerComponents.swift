import CoreLocation
import SwiftUI

private struct TerritoryDetailRoute: Hashable {
    let id: Int
    let name: String
}

struct TerritoryExplorerControls: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    let locationService: TerritoryLocationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                searchField
                PresentationToggle(viewModel: viewModel)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    sortMenu
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
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.clear"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        // Sin `.interactive()`: el cristal interactivo capturaba el toque del botón de limpiar.
        .glassEffect(.regular, in: .capsule)
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentDeep)
                .frame(width: 34, height: 34)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
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
                    .font(.appCaption().weight(.medium))
                    .foregroundStyle(selected ? .white : Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: 34)
        }
        .glassEffect(
            selected ? .regular.tint(.accent).interactive() : .regular.interactive(),
            in: .capsule
        )
        .frame(minHeight: 44)
        .contentShape(Rectangle())
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
    @State private var selectedTerritoryRoute: TerritoryDetailRoute?

    var body: some View {
        List {
            resultsHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.md, bottom: AppSpacing.xxs, trailing: AppSpacing.md))

            // Lista plana ordenada (por defecto, código ascendente). Sin agrupar por estado.
            ForEach(ordered(viewModel.displayedTerritories)) { territory in
                row(territory)
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
        .navigationDestination(item: $selectedTerritoryRoute) { route in
            TerritoryDetailView(territoryId: route.id, territoryName: route.name)
        }
    }

    private var resultsHeader: some View {
        HStack {
            Text(summaryText)
                .font(.appSubheadline())
                .foregroundStyle(Color.textSecondary)
                .contentTransition(.numericText())
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    /// Resumen del listado. Con el filtro de Libres se omite la parte de "requieren
    /// atención" (un territorio libre nunca la requeriría).
    private var summaryText: String {
        let total = viewModel.displayedTerritories.count
        if viewModel.filterStatus == .free {
            return String(format: String.localized("territories.summary_short"), total)
        }
        return String(format: String.localized("territories.summary"), total, viewModel.attentionTerritories.count)
    }

    @ViewBuilder
    private func row(_ territory: Territory) -> some View {
        Button {
            selectedTerritoryRoute = TerritoryDetailRoute(
                id: territory.id,
                name: territory.name
            )
        } label: {
            TerritoryExplorerRow(territory: territory, operationalStatus: viewModel.status(for: territory))
        }
        .buttonStyle(.plain)
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
            TerritoryExplorerRow(territory: territory, operationalStatus: viewModel.status(for: territory))
                .frame(width: 340)
                .padding()
                .background(Color.appBackground)
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
    let operationalStatus: TerritoryOperationalStatus

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(territory.code)
                    .font(.appTitle().weight(.bold))
                    .foregroundStyle(Color.accentDeep)

                Text(territory.name)
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }

            assignmentDetail
        }
        .padding(AppSpacing.md)
        .padding(.trailing, 104)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(alignment: .trailing) {
            mapBackdrop
        }
        .background {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [status.color.opacity(0.72), status.color.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .compositingGroup()
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var statusLabel: some View {
        TerritoryStatusIndicator(presentation: status, detail: availableDetail)
    }

    @ViewBuilder
    private var assignmentDetail: some View {
        if let personName = territory.personName {
            HStack(spacing: AppSpacing.xs) {
                InitialsAvatar(name: personName, size: 32, tint: status.color)

                VStack(alignment: .leading, spacing: 2) {
                    // Mismo diseño que el nombre en "Prioridad de hoy".
                    Text(personName)
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(status.detail)
                        .font(.appCaption().weight(.medium))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                }
            }
        } else {
            statusLabel
        }
    }

    private var availableDetail: LocalizedStringKey {
        guard let lastPickedDate = territory.lastPickedDateUtc else {
            return "territories.drawer.never_picked"
        }
        let days = max(Calendar.current.dateComponents([.day], from: lastPickedDate, to: Date()).day ?? 0, 0)
        return LocalizedStringKey(String(format: String.localized("territories.status.days_available"), days))
    }

    @ViewBuilder
    private var mapBackdrop: some View {
        if let geometry = territory.mapGeometry {
            TerritorySnapshotBackdrop(
                geometry: geometry,
                stroke: status.color,
                fill: status.color,
                verticalBias: 0.12
            )
            .mask(mapFade)
            .mask(cardShape)
        } else if let imageURL = territory.imgUrl.flatMap(URL.init(string:)) {
            CachedAsyncImage(
                url: imageURL,
                content: { image in
                    image
                        .resizable()
                        .scaledToFill()
                },
                placeholder: {
                    mapPlaceholder
                },
                errorView: {
                    mapPlaceholder
                }
            )
            .mask(mapFade)
            .mask(cardShape)
        } else {
            mapPlaceholder
                .mask(mapFade)
                .mask(cardShape)
        }
    }

    private var mapFade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(0.08), location: 0.18),
                .init(color: .black.opacity(0.38), location: 0.34),
                .init(color: .black.opacity(0.76), location: 0.52),
                .init(color: .black, location: 0.68),
                .init(color: .black, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
    }

    private var mapPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [status.color.opacity(0.03), status.color.opacity(0.18)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .trailing) {
                TerritoryPolygonThumbnail(geometry: territory.mapGeometry, tint: status.color)
                    .frame(width: 112, height: 112)
                    .padding(.trailing, AppSpacing.md)
            }
    }

    private var status: TerritoryStatusPresentation {
        TerritoryStatusPresentation(operationalStatus)
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
                .fixedSize()
                .frame(minWidth: 44, minHeight: 36)
                .padding(.horizontal, AppSpacing.xs)
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
