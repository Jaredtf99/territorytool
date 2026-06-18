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
    @State private var settlingHeight: CGFloat?
    @State private var settlingGeneration = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            dragZone

            ScrollViewReader { proxy in
                ScrollView {
                    relevantContent
                }
                .scrollIndicators(.hidden)
                .onChange(of: viewModel.selectedTerritoryID) { _, id in
                    guard let id else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: visibleHeight, alignment: .top)
        .background(Color.surface, in: UnevenRoundedRectangle(topLeadingRadius: AppRadius.xl, topTrailingRadius: AppRadius.xl))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: AppRadius.xl, topTrailingRadius: AppRadius.xl)
                .stroke(Color.hairline, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.13), radius: 18, y: -4)
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
                settlingGeneration += 1
                settlingHeight = nil
                dragTranslation = value.translation.height

                let proposedHeight = baseHeight - value.translation.height
                let boundary: DrawerBoundary? =
                    proposedHeight > mediumHeight + 10 ? .upper :
                    proposedHeight < collapsedHeight - 10 ? .lower :
                    nil

                if let boundary, boundary != reachedBoundary {
                    reachedBoundary = boundary
                    boundaryPulse = true
                    HapticManager.shared.impact(style: .soft)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        boundaryPulse = false
                    }
                } else if boundary == nil {
                    reachedBoundary = nil
                }
            }
            .onEnded { value in
                settlingGeneration += 1
                let generation = settlingGeneration
                let currentHeight = visibleHeight
                let projectedHeight = baseHeight - value.predictedEndTranslation.height
                let destination = nearestDetent(to: projectedHeight)

                var transaction = SwiftUI.Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    settlingHeight = currentHeight
                    dragTranslation = 0
                    viewModel.drawerDetent = destination
                }

                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.18)
                        : .interactiveSpring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.12)
                ) {
                    settlingHeight = height(for: destination)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.52)) {
                    guard settlingGeneration == generation else { return }
                    settlingHeight = nil
                }
                reachedBoundary = nil
                boundaryPulse = false
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

    /// Fila de territorio. Al estar seleccionada cambia el fondo y muestra las
    /// acciones (Ver + Recoger/Devolver/Asignar) en la misma línea, como en el mockup.
    @ViewBuilder
    private func drawerRow(_ territory: Territory) -> some View {
        let presentation = TerritoryStatusPresentation(territory.operationalStatus(attentionDays: viewModel.attentionDays))
        let selected = viewModel.selectedTerritoryID == territory.id

        HStack(spacing: AppSpacing.sm) {
            territoryThumbnail(territory, tint: presentation.color)
                            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(territory.code)
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(rowSubtitle(territory))
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.xs)

            if selected {
                NavigationLink {
                    TerritoryDetailView(territoryId: territory.id, territoryName: territory.name)
                } label: {
                    Label("territories.action.view_short", systemImage: "eye")
                        .labelStyle(.titleAndIcon)
                        .font(.appSubheadline().weight(.semibold))
                        .frame(minHeight: 42)
                }
                .buttonStyle(.glass)
                .controlSize(.regular)

                Button {
                    territory.personName == nil ? onAssign(territory) : onReturn(territory)
                } label: {
                    Label(
                        territory.personName == nil ? "assignment.title" : "return.title",
                        systemImage: territory.personName == nil ? "person.badge.plus" : "tray.and.arrow.down"
                    )
                    .font(.appCaption().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 42)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .tint(territory.personName == nil ? .accent : .accentSecondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: selected ? 76 : 68)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(selected ? presentation.color.opacity(0.10) : Color.surfaceRaised.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(selected ? presentation.color.opacity(0.30) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !selected else { return }
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
                onSelect(territory)
            }
        }
    }
    
    @ViewBuilder
       private func territoryThumbnail(_ territory: Territory, tint: Color) -> some View {
           if let geometry = territory.mapGeometry {
               TerritorySnapshotBackdrop(
                   geometry: geometry,
                   stroke: tint,
                   fill: tint,
                   centersTerritory: true
               )
               .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
               .overlay(
                   RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                       .stroke(tint.opacity(0.45), lineWidth: 1)
               )
           } else {
               TerritoryPolygonThumbnail(geometry: nil, tint: tint)
           }
       }

    private func rowSubtitle(_ territory: Territory) -> String {
        switch territory.operationalStatus(attentionDays: viewModel.attentionDays) {
        case .available:
            if let distance = distance(to: territory) {
                return String(format: String.localized("territories.status.available_distance"), distance)
            }
            return String(localized: "territories.status.available_now")
        case .assigned(let days), .attention(let days):
            if let person = territory.personName {
                return String(format: String.localized("territories.drawer.days_person"), days, person)
            }
            return String(format: String.localized("territories.status.days_assigned"), days)
        }
    }

    private var relevantTerritories: [Territory] {
        guard let location = locationService.location else { return viewModel.territoriesWithGeometry }
        let attention = viewModel.attentionTerritories.filter { $0.mapGeometry != nil }
        let available = viewModel.availableTerritories.filter { $0.mapGeometry != nil }.sorted {
            distance(from: location, to: $0) < distance(from: location, to: $1)
        }
        return attention + available + viewModel.assignedTerritories.filter { $0.mapGeometry != nil }
    }

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

    private var collapsedHeight: CGFloat { 168 + bottomInset }
    private var mediumHeight: CGFloat { min(max(availableHeight * 0.50, 360 + bottomInset), 440 + bottomInset) }

    private var baseHeight: CGFloat {
        switch viewModel.drawerDetent {
        case .collapsed: collapsedHeight
        case .medium: mediumHeight
        }
    }

    /// Altura visible del drawer siguiendo el arrastre en tiempo real (sin recolocar el contenido).
    private var visibleHeight: CGFloat {
        if let settlingHeight { return settlingHeight }

        let proposedHeight = baseHeight - dragTranslation
        if proposedHeight > mediumHeight {
            return mediumHeight + rubberBand(proposedHeight - mediumHeight)
        }
        if proposedHeight < collapsedHeight {
            return collapsedHeight - rubberBand(collapsedHeight - proposedHeight)
        }
        return proposedHeight
    }

    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        let dimension: CGFloat = 60
        let resistance: CGFloat = 0.42
        let stretched = (1 - 1 / (distance * resistance / dimension + 1)) * dimension
        return min(stretched, 18)
    }

    private func height(for detent: TerritoryDrawerDetent) -> CGFloat {
        switch detent {
        case .collapsed: collapsedHeight
        case .medium: mediumHeight
        }
    }

    private func nearestDetent(to height: CGFloat) -> TerritoryDrawerDetent {
        let options: [(TerritoryDrawerDetent, CGFloat)] = [
            (.collapsed, collapsedHeight),
            (.medium, mediumHeight)
        ]
        return options.min(by: { abs($0.1 - height) < abs($1.1 - height) })?.0 ?? .medium
    }
}
