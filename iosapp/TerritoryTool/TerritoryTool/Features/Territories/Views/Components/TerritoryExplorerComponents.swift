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
        // Un único contenedor para todos los cristales de la barra (buscador, conmutador
        // y chips): se renderizan juntos mientras el contenido se desplaza debajo.
        GlassEffectContainer {
            controls
        }
    }

    private var controls: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                searchField
                PresentationToggle(viewModel: viewModel)
            }
            .padding(.horizontal, AppSpacing.md)

            // El scroll ocupa todo el ancho (el margen va en el contenido):
            // así los chips no se clipean en el contenedor y llegan al borde.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    sortMenu
                    statusMenu
                    deliveryFormatMenu
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 2)
            }
            // Sin recorte: el menú se despliega "creciendo" desde el chip de cristal y,
            // con el recorte del scroll, la animación de abrir/cerrar se veía cortada.
            .scrollClipDisabled()
        }
        // Separación respecto a la navigation bar: sin ella el buscador quedaba pegado
        // al borde inferior de la barra.
        .padding(.top, AppSpacing.xs)
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

    private var statusMenu: some View {
        let current = viewModel.filterStatus
        let active = current != .all
        return Menu {
            Picker("territories.filter.status", selection: Binding(
                get: { viewModel.filterStatus },
                set: { newValue in
                    HapticManager.shared.selection()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78)) {
                        viewModel.filterStatus = newValue
                        viewModel.select(nil)
                    }
                }
            )) {
                ForEach(TerritoryFilter.allCases) { filter in
                    Text(filter.localizedName).tag(filter)
                }
            }
        } label: {
            FilterMenuChipLabel(active: active, tint: .accent) {
                if active {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                }
                Text(active ? current.localizedName : String.localized("territories.filter.status"))
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("territories.filter.status"))
        .accessibilityValue(Text(current.localizedName))
    }

    /// Usa el color de la familia "formato" (no el de ningún estado) para no
    /// confundirse con el filtro de estado.
    private var deliveryFormatMenu: some View {
        let current = viewModel.deliveryFormatFilter
        return Menu {
            Picker("delivery_format.title", selection: Binding(
                get: { viewModel.deliveryFormatFilter },
                set: { newValue in
                    HapticManager.shared.selection()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78)) {
                        viewModel.deliveryFormatFilter = newValue
                        viewModel.select(nil)
                    }
                }
            )) {
                Label("delivery_format.all", systemImage: "square.stack.3d.up")
                    .tag(DeliveryFormat?.none)
                ForEach(DeliveryFormat.allCases) { format in
                    Label(format.title, systemImage: format.systemImage)
                        .tag(DeliveryFormat?.some(format))
                }
            }
        } label: {
            FilterMenuChipLabel(active: current != nil, tint: DeliveryFormat.familyTint) {
                if let current {
                    Image(systemName: current.systemImage)
                        .font(.caption2.weight(.bold))
                    Text(current.title)
                } else {
                    Text("delivery_format.title")
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("delivery_format.title"))
        .accessibilityValue(Text(current?.title ?? "delivery_format.all"))
    }
}

/// Etiqueta de un chip que abre un menú. Inactivo (valor por defecto) muestra el
/// nombre del filtro; activo se tiñe y muestra la opción elegida.
private struct FilterMenuChipLabel<Content: View>: View {
    let active: Bool
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
                .font(.appCaption().weight(.medium))
                .foregroundStyle(active ? .white : Color.textPrimary)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(active ? .white : Color.textSecondary)
        }
        .padding(.leading, AppSpacing.sm)
        .padding(.trailing, AppSpacing.sm - 2)
        .frame(height: 34)
        .glassEffect(
            active ? .regular.tint(tint).interactive() : .regular.interactive(),
            in: .capsule
        )
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
            ForEach(viewModel.displayedTerritories) { territory in
                row(territory)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, topInset, for: .scrollContent)
        .contentMargins(.bottom, AppSpacing.xl)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: viewModel.displayRevision)
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
                    Label("assignment.title", systemImage: "paperplane.fill")
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
                // No usamos `role: .destructive` aquí: dentro de un swipe SwiftUI lo
                // interpreta como borrado inmediato y retira la fila antes del alert. La
                // confirmación sí conserva el rol destructivo; aquí el rojo es explícito.
                Button { onDelete(territory) } label: {
                    Label("territory.detail.delete", systemImage: "trash")
                }
                .tint(.red)
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
                    systemImage: territory.personName == nil ? "paperplane.fill" : "tray.and.arrow.down"
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
            // Sombra en la forma del fondo, no en la tarjeta compuesta: antes
            // `compositingGroup()+shadow` forzaba un pase offscreen por fila en el scroll.
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color.surface)
                .shadow(color: Color.glassShadow, radius: 8, x: 0, y: 4)
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

                    if territory.deliveryFormat == .virtual {
                        // En línea si cabe; si no (texto grande), "Virtual" baja a su propia
                        // línea. La marca nunca se pierde ni recorta los días.
                        ViewThatFits(in: .horizontal) {
                            assignmentMeta(showsVirtual: true)
                            VStack(alignment: .leading, spacing: 2) {
                                assignmentMeta(showsVirtual: false)
                                DeliveryFormatBadge(format: .virtual)
                            }
                        }
                    } else {
                        assignmentMeta(showsVirtual: false)
                    }
                }
            }
        } else {
            statusLabel
        }
    }

    /// Línea "Desde hace X días" con la marca virtual opcional detrás.
    private func assignmentMeta(showsVirtual: Bool) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Text(status.detail)
                .font(.appCaption().weight(.medium))
                .foregroundStyle(status.color)
                .lineLimit(1)
                // En la variante en línea no se permite recortar: si no cabe entero,
                // ViewThatFits pasa a la variante en dos líneas.
                .fixedSize(horizontal: showsVirtual, vertical: false)

            if showsVirtual {
                DeliveryFormatBadge(format: .virtual, leadingSeparator: true)
            }
        }
    }

    private var availableDetail: LocalizedStringKey {
        guard let lastPickedDate = territory.lastPickedDateUtc else {
            return "territories.drawer.never_picked"
        }
        let days = max(Calendar.current.dateComponents([.day], from: lastPickedDate, to: Date()).day ?? 0, 0)
        return LocalizedStringKey(String(format: String.localized("territories.status.days_available"), days))
    }

    /// Fondo de mapa fundido hacia el papel de la tarjeta. Sin `.mask`: el degradado
    /// del color de superficie encima + `clipShape` da el mismo resultado sin offscreen.
    private var mapBackdrop: some View {
        mapBackdropContent
            .overlay { mapFade }
            .clipShape(cardShape)
    }

    @ViewBuilder
    private var mapBackdropContent: some View {
        if let geometry = territory.mapGeometry {
            TerritorySnapshotBackdrop(
                geometry: geometry,
                stroke: status.color,
                fill: status.color,
                verticalBias: 0.12
            )
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
        } else {
            mapPlaceholder
        }
    }

    private var mapFade: some View {
        SurfaceFade(stops: [
            (0, 0), (0.08, 0.18), (0.38, 0.34), (0.76, 0.52), (1, 0.68), (1, 1)
        ])
    }

    private var cardShape: RoundedRectangle {
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
