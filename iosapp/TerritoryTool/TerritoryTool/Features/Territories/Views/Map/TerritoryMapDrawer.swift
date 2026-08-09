import CoreLocation
import SwiftUI

private enum DrawerBoundary: Equatable {
    case upper
    case lower
}

struct TerritoryMapDrawer: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    @ObservedObject var locationService: TerritoryLocationService
    let availableHeight: CGFloat
    var bottomInset: CGFloat = 0
    let onSelect: (Territory) -> Void
    let onAssign: (Territory) -> Void
    let onReturn: (Territory) -> Void
    let onEdit: (Territory) -> Void
    let onDelete: (Territory) -> Void

    @State private var dragTranslation: CGFloat = 0
    @State private var reachedBoundary: DrawerBoundary?
    @State private var boundaryPulse = false
    @State private var isDragging = false
    @Namespace private var rowTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            dragZone

            ScrollViewReader { proxy in
                ScrollView {
                    relevantContent
                }
                .scrollIndicators(.hidden)
                // El scroll funciona siempre (también en compacto). Al seleccionar, el drawer
                // cae a compacto y hacemos scroll para dejar la tarjeta seleccionada arriba del todo.
                .onChange(of: viewModel.selectedTerritoryID) { _, id in
                    guard let id else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)) {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: visibleHeight, alignment: .top)
        .animation(
            isDragging ? nil : (reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.82)),
            value: visibleHeight
        )
        .glassEffect(
            .regular,
            in: UnevenRoundedRectangle(topLeadingRadius: AppRadius.xl, topTrailingRadius: AppRadius.xl)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: AppRadius.xl, topTrailingRadius: AppRadius.xl)
                .stroke(Color.hairline.opacity(0.6), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: -4)
    }

    /// Asa de arrastre sin cabecera para dejar el contenido centrado en los territorios.
    private var dragZone: some View {
        Capsule()
            .fill(Color.textSecondary.opacity(0.4))
            .frame(width: boundaryPulse ? 48 : 40, height: 5)
            .padding(.vertical, AppSpacing.sm)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.55),
                value: boundaryPulse
            )
        .frame(maxWidth: .infinity)
        .background(Color.surface.opacity(0.01))
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging { isDragging = true }
                dragTranslation = value.translation.height

                let proposedHeight = baseHeight - value.translation.height
                let boundary: DrawerBoundary? =
                    proposedHeight > mediumHeight + 6 ? .upper :
                    proposedHeight < collapsedHeight - 6 ? .lower :
                    nil

                if let boundary, boundary != reachedBoundary {
                    reachedBoundary = boundary
                    boundaryPulse = true
                    HapticManager.shared.impact(style: .soft)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        boundaryPulse = false
                    }
                } else if boundary == nil {
                    reachedBoundary = nil
                }
            }
            .onEnded { value in
                let projectedHeight = baseHeight - value.predictedEndTranslation.height
                let destination = nearestDetent(to: projectedHeight)
                isDragging = false
                dragTranslation = 0
                viewModel.drawerDetent = destination
                reachedBoundary = nil
            }
    }

    private var relevantContent: some View {
        let rows = displayedRows
        return LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(rows) { territory in
                drawerRow(territory)
                    .id(territory.id)
            }

            if !viewModel.territoriesWithoutGeometry.isEmpty {
                CartoSectionHeader(
                    title: "territories.section.no_geometry",
                    systemImage: "map.slash",
                    count: viewModel.territoriesWithoutGeometry.count,
                    tint: .textSecondary
                )
                ForEach(viewModel.territoriesWithoutGeometry) { territory in
                    drawerRow(territory)
                        .id(territory.id)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, bottomInset + 72)
    }

    /// Mantiene el orden de relevancia. La selección se revela haciendo scroll hasta
    /// su posición real en vez de alterar el orden de las filas.
    private var displayedRows: [Territory] {
        relevantTerritories
    }

    /// Tarjeta compacta que se expande en su misma posición al seleccionarse.
    /// El mapa queda a sangre por arriba, abajo e izquierda; su borde derecho
    /// conserva el radio para separarlo visualmente del contenido.
    @ViewBuilder
    private func drawerRow(_ territory: Territory) -> some View {
        let presentation = TerritoryStatusPresentation(viewModel.status(for: territory))
        let selected = viewModel.selectedTerritoryID == territory.id
        let cardShape = RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)

        HStack(spacing: 0) {
            territoryThumbnail(territory, tint: presentation.color)
                .frame(width: selected ? 116 : 96)
                .frame(maxHeight: .infinity)
                .matchedGeometryEffect(
                    id: "drawer-map-\(territory.id)",
                    in: rowTransition,
                    properties: .frame
                )

            VStack(alignment: .leading, spacing: selected ? 5 : 3) {
                Text(territory.code)
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                drawerAssignmentDetail(territory, presentation: presentation, selected: selected)

                if selected {
                    HStack(spacing: AppSpacing.xs) {
                        NavigationLink {
                            TerritoryDetailView(territoryId: territory.id, territoryName: territory.name)
                        } label: {
                            Label("territories.action.view_short", systemImage: "eye")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.glass)

                        Button {
                            territory.personName == nil ? onAssign(territory) : onReturn(territory)
                        } label: {
                            Label(
                                territory.personName == nil ? "assignment.title" : "return.title",
                                systemImage: territory.personName == nil ? "paperplane.fill" : "tray.and.arrow.down"
                            )
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(territory.personName == nil ? .accent : .accentSecondary)
                    }
                    .padding(.top, 3)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                        )
                    )
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.16)
                            : .spring(response: 0.32, dampingFraction: 0.84).delay(0.08),
                        value: selected
                    )
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .matchedGeometryEffect(
                id: "drawer-content-\(territory.id)",
                in: rowTransition,
                properties: .position,
                anchor: .leading
            )

            if !selected {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textSecondary.opacity(0.6))
                    .padding(.trailing, AppSpacing.sm)
                    .transition(.opacity)
            }
        }
        .frame(height: selected ? selectedRowHeight : 84)
        .background(
            cardShape
                .fill(selected ? presentation.color.opacity(0.10) : Color.surfaceRaised.opacity(0.82))
        )
        .overlay(
            cardShape
                .stroke(selected ? presentation.color.opacity(0.30) : Color.clear, lineWidth: 1)
        )
        .clipShape(cardShape)
        .shadow(
            color: selected ? presentation.color.opacity(0.12) : .clear,
            radius: 10,
            y: 4
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !selected else { return }
            HapticManager.shared.selection()
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.16)
                    : .spring(response: 0.32, dampingFraction: 0.84)
            ) {
                onSelect(territory)
            }
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.16)
                : .spring(response: selected ? 0.32 : 0.24, dampingFraction: 0.86),
            value: selected
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func territoryThumbnail(_ territory: Territory, tint: Color) -> some View {
        let mapShape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: AppRadius.md,
            topTrailingRadius: AppRadius.md,
            style: .continuous
        )

        if let geometry = territory.mapGeometry {
            TerritorySnapshotBackdrop(
                geometry: geometry,
                stroke: tint,
                fill: tint,
                centersTerritory: true
            )
            .clipShape(mapShape)
            .overlay(
                mapShape
                    .stroke(tint.opacity(0.32), lineWidth: 1)
            )
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, Color.surface.opacity(0.16)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 18)
            }
        } else {
            TerritoryPolygonThumbnail(geometry: nil, tint: tint)
                .clipShape(mapShape)
                .background(tint.opacity(0.08))
        }
    }

    @ViewBuilder
    private func drawerAssignmentDetail(
        _ territory: Territory,
        presentation: TerritoryStatusPresentation,
        selected: Bool
    ) -> some View {
        if let personName = territory.personName {
            HStack(spacing: AppSpacing.xs) {
                InitialsAvatar(name: personName, size: selected ? 30 : 26, tint: presentation.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(personName)
                        .font(selected ? .appSubheadline() : .appCaption().weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(assignedDetail(territory))
                        .font(.appCaption().weight(.medium))
                        .foregroundStyle(presentation.color)
                        .lineLimit(1)
                }
            }
        } else {
            TerritoryStatusIndicator(
                presentation: presentation,
                detail: availableDetail(territory),
                size: selected ? .regular : .compact
            )
        }
    }

    private func assignedDetail(_ territory: Territory) -> LocalizedStringKey {
        switch viewModel.status(for: territory) {
        case .assigned(let days), .attention(let days):
            return LocalizedStringKey(String(format: String.localized("territories.status.days_assigned"), days))
        case .available:
            return availableDetail(territory)
        }
    }

    private func availableDetail(_ territory: Territory) -> LocalizedStringKey {
        guard let lastPickedDate = territory.lastPickedDateUtc else {
            return "territories.drawer.never_picked"
        }
        let elapsedDays = days(from: lastPickedDate, to: Date())
        return LocalizedStringKey(String(format: String.localized("territories.status.days_available"), elapsedDays))
    }

    private func days(from start: Date, to end: Date) -> Int {
        max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    /// Ya viene ordenada del ViewModel. Antes esto ordenaba por distancia dentro del `body`,
    /// que el gesto de arrastre reevalúa en cada frame.
    private var relevantTerritories: [Territory] { viewModel.drawerTerritories }

    private func distance(to territory: Territory) -> String? {
        guard let location = locationService.location else { return nil }
        let meters = distance(from: location, to: territory)
        guard meters.isFinite else { return nil }
        if meters < 1_000 { return String(format: "%.0f m", meters) }
        return String(format: "%.1f km", meters / 1_000)
    }

    private func distance(from location: CLLocation, to territory: Territory) -> CLLocationDistance {
        guard let coordinate = territory.mapGeometry?.representativeCoordinate else { return .greatestFiniteMagnitude }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    /// Altura de la tarjeta de territorio según su estado (debe coincidir con el `.frame` de la fila).
    private var selectedRowHeight: CGFloat { 132 }
    private var handleZoneHeight: CGFloat { 30 }

    private var collapsedHeight: CGFloat {
        // Con un territorio seleccionado, el compacto se ajusta justo a su tarjeta expandida.
        if viewModel.selectedTerritoryID != nil {
            return handleZoneHeight + selectedRowHeight + bottomInset + 6
        }
        return 168 + bottomInset
    }
    private var mediumHeight: CGFloat { min(max(availableHeight * 0.50, 360 + bottomInset), 440 + bottomInset) }

    private var baseHeight: CGFloat {
        switch viewModel.drawerDetent {
        case .collapsed: collapsedHeight
        case .medium: mediumHeight
        }
    }

    /// Altura visible del drawer siguiendo el arrastre en tiempo real (sin recolocar el contenido).
    /// Más allá de los límites aplica una resistencia elástica (rubber band) suave.
    private var visibleHeight: CGFloat {
        let proposedHeight = baseHeight - dragTranslation
        if proposedHeight > mediumHeight {
            return mediumHeight + rubberBand(proposedHeight - mediumHeight)
        }
        if proposedHeight < collapsedHeight {
            return collapsedHeight - rubberBand(collapsedHeight - proposedHeight)
        }
        return proposedHeight
    }

    /// Resistencia elástica estilo iOS: avanza con retornos decrecientes y asíntota suave,
    /// sin tope brusco (eso era lo que daba la sensación de "pillada").
    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        let dimension: CGFloat = 110
        let constant: CGFloat = 0.55
        return (1 - 1 / (distance * constant / dimension + 1)) * dimension
    }

    private func nearestDetent(to height: CGFloat) -> TerritoryDrawerDetent {
        let options: [(TerritoryDrawerDetent, CGFloat)] = [
            (.collapsed, collapsedHeight),
            (.medium, mediumHeight)
        ]
        return options.min(by: { abs($0.1 - height) < abs($1.1 - height) })?.0 ?? .medium
    }
}
