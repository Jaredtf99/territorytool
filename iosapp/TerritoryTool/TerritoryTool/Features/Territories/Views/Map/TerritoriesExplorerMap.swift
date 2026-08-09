import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct TerritoriesExplorerMap: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    @ObservedObject var locationService: TerritoryLocationService
    var topInset: CGFloat = 0
    @Binding var isFullscreen: Bool
    let onAssign: (Territory) -> Void
    let onReturn: (Territory) -> Void
    let onEdit: (Territory) -> Void
    let onDelete: (Territory) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var didFitInitialResults = false
    @State private var visibleMapRect: MKMapRect?
    @State private var mapViewportSize: CGSize = .zero
    @State private var labelPlacements: [Int: TerritoryLabelPlacement] = [:]
    @State private var visibleLabelIDs = Set<Int>()
    @State private var preparedGeometries: [Int: TerritoryPreparedMapGeometry] = [:]
    /// Verdadero mientras se ejecuta un movimiento de cámara hecho por código, para
    /// no confundirlo con un desplazamiento manual del usuario (que compacta el drawer).
    @State private var isProgrammaticMove = false
    @State private var programmaticMoveToken = 0

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let topSafe = proxy.safeAreaInsets.top
            ZStack(alignment: .bottom) {
                map
                    .overlay(alignment: .topLeading) {
                        mapControls
                            .padding(.leading, AppSpacing.md)
                            .padding(.top, topSafe + topInset + AppSpacing.xs)
                    }

                TerritoryMapDrawer(
                    viewModel: viewModel,
                    locationService: locationService,
                    availableHeight: proxy.size.height + bottomInset,
                    bottomInset: bottomInset,
                    onSelect: { territory in
                        viewModel.select(territory)
                        focus(
                            on: territory,
                            animated: true,
                            fullHeight: proxy.size.height + topSafe + bottomInset,
                            topOcclusion: topSafe + topInset,
                            bottomOcclusion: drawerHeight(
                                availableHeight: proxy.size.height + bottomInset,
                                bottomInset: bottomInset
                            )
                        )
                    },
                    onAssign: onAssign,
                    onReturn: onReturn,
                    onEdit: onEdit,
                    onDelete: onDelete
                )
            }
            .ignoresSafeArea()
            .onAppear {
                mapViewportSize = proxy.size
                updateVisibleLabels()
            }
            .onChange(of: proxy.size) { _, size in
                mapViewportSize = size
                updateVisibleLabels()
            }
        }
        // El buscador está arriba; sin esto, el teclado encoge el GeometryReader y
        // empuja el drawer (anclado abajo) hacia arriba.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // `.task(id:)` cancela sola la pasada anterior cuando cambia el conjunto de
        // geometrías, que es justo lo que hace falta al teclear en el buscador.
        .task(id: viewModel.geometryRevision) {
            await updateMapCaches()
        }
        .onAppear {
            focusOnPrimary(animated: false)
        }
        .onChange(of: viewModel.geometryRevision) { _, _ in
            // Solo encuadramos en la primera carga. Las búsquedas no mueven la cámara;
            // el mapa solo se desplaza al seleccionar un territorio en el drawer.
            if !didFitInitialResults {
                focusOnPrimary(animated: true)
            }
        }
        .onChange(of: viewModel.selectedTerritoryID) { _, _ in
            updateVisibleLabels()
        }
        .onChange(of: locationService.location?.coordinate.latitude) { _, _ in
            guard let location = locationService.location else { return }
            beginProgrammaticMove()
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: location.coordinate,
                        distance: 2_400,
                        heading: 0,
                        pitch: mapPitch
                    )
                )
            }
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                ForEach(viewModel.territoriesWithGeometry) { territory in
                    if let geometry = preparedGeometries[territory.id] {
                        let territoryStyle = style(for: territory)
                        let selected = viewModel.selectedTerritoryID == territory.id
                        let dimmed = viewModel.selectedTerritoryID != nil && !selected

                        ForEach(geometry.polygons) { polygon in
                            MapPolygon(coordinates: polygon.coordinates)
                                .foregroundStyle(
                                    territoryStyle.color.opacity(selected ? 0.58 : dimmed ? 0.08 : 0.22)
                                )
                                .stroke(
                                    territoryStyle.color.opacity(dimmed ? 0.38 : 1),
                                    lineWidth: selected ? 5 : dimmed ? 1.25 : territoryStyle.lineWidth
                                )
                        }
                        ForEach(geometry.polylines) { polyline in
                            MapPolyline(coordinates: polyline.coordinates)
                                .stroke(
                                    territoryStyle.color.opacity(dimmed ? 0.35 : 1),
                                    lineWidth: selected ? 4 : 2.5
                                )
                        }
                    }
                }

                ForEach(viewModel.territoriesWithGeometry) { territory in
                    if let placement = labelPlacements[territory.id],
                       visibleLabelIDs.contains(territory.id) {
                        Annotation("", coordinate: placement.coordinate) {
                            TerritoryMapNameLabel(
                                territory: territory,
                                status: viewModel.status(for: territory),
                                isSelected: viewModel.selectedTerritoryID == territory.id
                            )
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if let location = locationService.location {
                    Annotation("", coordinate: location.coordinate) {
                        Circle()
                            .fill(Color.info)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 4)
                            .accessibilityLabel(Text("territories.location.current"))
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in
                let rect = mapRect(for: context.region)
                visibleMapRect = rect
                updateVisibleLabels(in: rect)
                // Si este evento es el final de un encuadre programático, lo consumimos
                // y no tocamos el drawer. Si fue gesto del usuario, cerramos teclado y compactamos.
                if isProgrammaticMove {
                    isProgrammaticMove = false
                } else {
                    dismissKeyboard()
                    if viewModel.drawerDetent != .collapsed {
                        viewModel.drawerDetent = .collapsed
                    }
                }
            }
            .onTapGesture { point in
                handleMapTap(point, proxy: proxy)
            }
            // Compacta el drawer EN CUANTO el usuario empieza a arrastrar el mapa (no al
            // soltar). Solo se dispara con gestos reales, así que no necesita el guard
            // de movimientos programáticos. El pinch/zoom lo cubre `onMapCameraChange`.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in collapseDrawerForUserInteraction() }
            )
            .accessibilityLabel(Text("territories.map.accessibility"))
        }
    }

    private func collapseDrawerForUserInteraction() {
        dismissKeyboard()
        guard viewModel.drawerDetent != .collapsed else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            viewModel.drawerDetent = .collapsed
        }
    }

    /// Selecciona el territorio cuyo polígono contiene el punto tocado.
    private func handleMapTap(_ point: CGPoint, proxy: MapProxy) {
        dismissKeyboard()
        guard let coordinate = proxy.convert(point, from: .local) else { return }
        if let territory = territory(containing: coordinate) {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                viewModel.select(territory)
            }
        } else {
            // Toque en zona vacía: deselecciona y compacta el drawer.
            withAnimation(.easeInOut(duration: 0.25)) {
                if viewModel.selectedTerritoryID != nil { viewModel.select(nil) }
                viewModel.drawerDetent = .collapsed
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Marca un movimiento de cámara como programático. El flag lo consume el siguiente
    /// `onMapCameraChange` (el final de ese movimiento), así que no depende de tiempos.
    /// El temporizador es solo una red de seguridad por si el movimiento no genera evento.
    private func beginProgrammaticMove() {
        programmaticMoveToken += 1
        let token = programmaticMoveToken
        isProgrammaticMove = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if programmaticMoveToken == token { isProgrammaticMove = false }
        }
    }

    private func territory(containing coordinate: CLLocationCoordinate2D) -> Territory? {
        viewModel.territoriesWithGeometry.first { territory in
            if let preparedGeometry = preparedGeometries[territory.id] {
                return preparedGeometry.polygons.contains { polygon in
                    pointInPolygon(coordinate, polygon.coordinates)
                }
            }

            return territory.mapGeometry?.polygons.contains { polygon in
                pointInPolygon(coordinate, polygon.coordinates)
            } ?? false
        }
    }

    private func pointInPolygon(_ point: CLLocationCoordinate2D, _ coordinates: [TerritoryMapCoordinate]) -> Bool {
        pointInPolygon(point, coordinates.map(\.clCoordinate))
    }

    private func pointInPolygon(_ point: CLLocationCoordinate2D, _ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count > 2 else { return false }
        var inside = false
        var j = coordinates.count - 1
        for i in 0..<coordinates.count {
            let yi = coordinates[i].latitude, xi = coordinates[i].longitude
            let yj = coordinates[j].latitude, xj = coordinates[j].longitude
            if ((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    private var mapControls: some View {
        VStack(spacing: AppSpacing.xs) {
            locationButton
            fullscreenButton
        }
        .foregroundStyle(Color.accentDeep)
    }

    private var locationButton: some View {
        Button {
            if locationService.isDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } else {
                locationService.requestLocation()
            }
            if let location = locationService.location {
                beginProgrammaticMove()
                withAnimation {
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: location.coordinate,
                            distance: 2_400,
                            heading: 0,
                            pitch: mapPitch
                        )
                    )
                }
            }
        } label: {
            Image(systemName: locationService.isDenied ? "location.slash" : locationService.location == nil ? "location" : "location.fill")
                .font(.appSubheadline().weight(.semibold))
                .frame(width: 40, height: 40)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(locationService.isDenied ? "territories.location.settings" : "territories.location.button"))
    }

    private var fullscreenButton: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                isFullscreen.toggle()
                viewModel.drawerDetent = isFullscreen ? .collapsed : .medium
            }
        } label: {
            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.appSubheadline().weight(.semibold))
                .frame(width: 40, height: 40)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(isFullscreen ? "territories.map.exit_fullscreen" : "territories.map.fullscreen"))
    }

    private func style(for territory: Territory) -> (color: Color, lineWidth: CGFloat) {
        switch viewModel.status(for: territory) {
        case .available: (.accent, 2)
        case .assigned: (.accentSecondary, 2)
        case .attention: (.accentTertiary, 3)
        }
    }

    /// Encuadra el primer territorio de "Cerca y relevante" en la carga inicial.
    private func focusOnPrimary(animated: Bool) {
        guard let territory = viewModel.territoriesWithGeometry.first else { return }
        focus(on: territory, animated: animated)
        didFitInitialResults = true
    }

    private func focus(
        on territory: Territory,
        animated: Bool,
        fullHeight: CGFloat = 0,
        topOcclusion: CGFloat = 0,
        bottomOcclusion: CGFloat = 0
    ) {
        guard let geometry = territory.mapGeometry else { return }
        let bounds = geometry.bounds
        let northWest = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west))
        let southEast = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east))
        let rect = MKMapRect(
            x: min(northWest.x, southEast.x),
            y: min(northWest.y, southEast.y),
            width: abs(southEast.x - northWest.x),
            height: abs(southEast.y - northWest.y)
        )
        // Margen alrededor del territorio (controla el zoom). Más margen => más alejado.
        var padded = rect.insetBy(dx: -max(rect.width * 1.5, 800), dy: -max(rect.height * 1.5, 800))

        // Centrar el territorio en la franja visible, excluyendo toolbar/filtros (arriba)
        // y el drawer (abajo), usando la altura completa de pantalla.
        if fullHeight > 0, topOcclusion + bottomOcclusion < fullHeight {
            let visibleCenter = topOcclusion + (fullHeight - topOcclusion - bottomOcclusion) / 2
            let screenShift = visibleCenter - fullHeight / 2
            let dy = -screenShift * (padded.height / fullHeight)
            padded = padded.offsetBy(dx: 0, dy: dy)
        }

        beginProgrammaticMove()
        let update = { cameraPosition = .camera(camera(for: padded)) }
        if animated { withAnimation(.easeInOut(duration: 0.4), update) } else { update() }
    }

    private func drawerHeight(availableHeight: CGFloat, bottomInset: CGFloat) -> CGFloat {
        switch viewModel.drawerDetent {
        case .collapsed:
            return 168 + bottomInset
        case .medium:
            return min(max(availableHeight * 0.50, 360 + bottomInset), 440 + bottomInset)
        }
    }

    private func fitResults(animated: Bool) {
        let coordinates = viewModel.territoriesWithGeometry.compactMap { $0.mapGeometry?.representativeCoordinate }
        guard !coordinates.isEmpty else { return }
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        let padded = rect.insetBy(dx: -max(rect.width * 0.14, 500), dy: -max(rect.height * 0.22, 500))
        beginProgrammaticMove()
        let update = { cameraPosition = .camera(camera(for: padded)) }
        if animated { withAnimation(.easeInOut(duration: 0.35), update) } else { update() }
        didFitInitialResults = true
    }

    private var mapPitch: Double { 38 }

    private func camera(for rect: MKMapRect) -> MapCamera {
        let centerPoint = MKMapPoint(x: rect.midX, y: rect.midY)
        let center = centerPoint.coordinate
        let footprintMeters = max(rect.width, rect.height) * MKMetersPerMapPointAtLatitude(center.latitude)
        return MapCamera(
            centerCoordinate: center,
            distance: max(footprintMeters * 1.05, 260),
            heading: 0,
            pitch: mapPitch
        )
    }

    private func labelFits(_ territory: Territory, placement: TerritoryLabelPlacement, in mapRect: MKMapRect) -> Bool {
        guard mapViewportSize.width > 0, mapViewportSize.height > 0 else {
            return true
        }
        let paddedViewport = mapRect.insetBy(dx: -mapRect.width * 0.08, dy: -mapRect.height * 0.08)
        guard paddedViewport.intersects(placement.bounds) else { return false }

        let scaleX = mapViewportSize.width / mapRect.width
        let scaleY = mapViewportSize.height / mapRect.height
        let selectionScale = viewModel.selectedTerritoryID == territory.id ? 1.08 : 1
        let halfWidth = ((placement.textSize.width / 2) + 2) * selectionScale / scaleX
        let halfHeight = ((placement.textSize.height / 2) + 2) * selectionScale / scaleY
        let center = MKMapPoint(placement.coordinate)

        // Comprueba la caja real que ocupa el texto, no un círculo basado en su
        // dimensión mayor. Esto conserva las etiquetas en territorios alargados.
        typealias Point = TerritoryMapGeometryPreprocessor.Point
        let samples = [
            Point(x: center.x - halfWidth, y: center.y - halfHeight),
            Point(x: center.x, y: center.y - halfHeight),
            Point(x: center.x + halfWidth, y: center.y - halfHeight),
            Point(x: center.x - halfWidth, y: center.y),
            Point(x: center.x, y: center.y),
            Point(x: center.x + halfWidth, y: center.y),
            Point(x: center.x - halfWidth, y: center.y + halfHeight),
            Point(x: center.x, y: center.y + halfHeight),
            Point(x: center.x + halfWidth, y: center.y + halfHeight)
        ]

        // Un pequeño margen negativo evita parpadeos por redondeo justo en el borde.
        let tolerance = max(halfWidth, halfHeight) * 0.08
        return samples.allSatisfy {
            signedDistance(from: $0, to: placement.polygon) >= -tolerance
        }
    }

    /// Prepara la geometría del mapa **fuera del actor principal**.
    ///
    /// Es el trabajo síncrono más pesado de la pantalla: ajusta las fronteras entre
    /// territorios vecinos y busca el punto interior de cada etiqueta. Antes corría entero
    /// en main desde `onAppear` y desde el `onChange` del conjunto de territorios.
    ///
    /// La proyección a espacio de mapa se hace aquí (es barata) para que lo único que cruce
    /// la frontera sean valores `Sendable`; el cálculo va en una tarea aparte.
    private func updateMapCaches() async {
        let territories = viewModel.territoriesWithGeometry

        var polygonFeatures: [TerritoryMapGeometryPreprocessor.Feature] = []
        var polylineFeatures: [TerritoryMapGeometryPreprocessor.Feature] = []
        var textSizes: [Int: CGSize] = [:]

        for territory in territories {
            guard let geometry = territory.mapGeometry else { continue }
            textSizes[territory.id] = labelTextSize(for: territory.name)

            for polygon in geometry.polygons {
                let points = polygon.coordinates.map(Self.preprocessorPoint)
                guard points.count >= 3 else { continue }
                polygonFeatures.append(
                    .init(territoryID: territory.id, id: polygon.id, points: points)
                )
            }
            for polyline in geometry.polylines {
                polylineFeatures.append(
                    .init(
                        territoryID: territory.id,
                        id: polyline.id,
                        points: polyline.coordinates.map(Self.preprocessorPoint)
                    )
                )
            }
        }

        let work = Task.detached(priority: .userInitiated) {
            TerritoryMapGeometryPreprocessor.process(
                polygons: polygonFeatures,
                polylines: polylineFeatures
            )
        }
        // `Task.detached` no hereda la cancelación del `.task(id:)`, así que se propaga a mano.
        let output = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }

        guard let output, !Task.isCancelled else { return }

        var geometries: [Int: TerritoryPreparedMapGeometry] = [:]
        var placements: [Int: TerritoryLabelPlacement] = [:]

        for territory in territories {
            geometries[territory.id] = TerritoryPreparedMapGeometry(
                polygons: (output.polygonsByTerritory[territory.id] ?? []).map(Self.preparedFeature),
                polylines: (output.polylinesByTerritory[territory.id] ?? []).map(Self.preparedFeature)
            )

            if let placement = output.labelPlacements[territory.id] {
                placements[territory.id] = TerritoryLabelPlacement(
                    coordinate: MKMapPoint(x: placement.point.x, y: placement.point.y).coordinate,
                    polygon: placement.polygon,
                    bounds: MKMapRect(
                        x: placement.bounds.minX,
                        y: placement.bounds.minY,
                        width: placement.bounds.maxX - placement.bounds.minX,
                        height: placement.bounds.maxY - placement.bounds.minY
                    ),
                    textSize: textSizes[territory.id] ?? .zero
                )
            }
        }

        preparedGeometries = geometries
        labelPlacements = placements
        visibleLabelIDs = calculateVisibleLabelIDs(in: visibleMapRect, placements: placements)
    }

    private static func preprocessorPoint(
        _ coordinate: TerritoryMapCoordinate
    ) -> TerritoryMapGeometryPreprocessor.Point {
        let mapPoint = MKMapPoint(
            CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
        return .init(x: mapPoint.x, y: mapPoint.y)
    }

    private static func preparedFeature(
        _ feature: TerritoryMapGeometryPreprocessor.Feature
    ) -> TerritoryPreparedMapFeature {
        TerritoryPreparedMapFeature(
            id: feature.id,
            coordinates: feature.points.map { MKMapPoint(x: $0.x, y: $0.y).coordinate }
        )
    }

    private func labelTextSize(for name: String) -> CGSize {
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = UIFont.systemFont(ofSize: font.pointSize, weight: .bold)
        let bounds = (name as NSString).boundingRect(
            with: CGSize(width: 106, height: 80),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: boldFont],
            context: nil
        )
        return CGSize(width: min(ceil(bounds.width), 106), height: min(ceil(bounds.height), 80))
    }

    private func updateVisibleLabels(in mapRect: MKMapRect? = nil) {
        visibleLabelIDs = calculateVisibleLabelIDs(
            in: mapRect ?? visibleMapRect,
            placements: labelPlacements
        )
    }

    private func calculateVisibleLabelIDs(
        in mapRect: MKMapRect?,
        placements: [Int: TerritoryLabelPlacement]
    ) -> Set<Int> {
        guard let mapRect else { return Set(placements.keys) }
        return Set(
            viewModel.territoriesWithGeometry.compactMap { territory in
                guard let placement = placements[territory.id],
                      labelFits(territory, placement: placement, in: mapRect) else {
                    return nil
                }
                return territory.id
            }
        )
    }

    private func mapRect(for region: MKCoordinateRegion) -> MKMapRect {
        let northWest = MKMapPoint(
            CLLocationCoordinate2D(
                latitude: region.center.latitude + region.span.latitudeDelta / 2,
                longitude: region.center.longitude - region.span.longitudeDelta / 2
            )
        )
        let southEast = MKMapPoint(
            CLLocationCoordinate2D(
                latitude: region.center.latitude - region.span.latitudeDelta / 2,
                longitude: region.center.longitude + region.span.longitudeDelta / 2
            )
        )
        return MKMapRect(
            x: min(northWest.x, southEast.x),
            y: min(northWest.y, southEast.y),
            width: abs(southEast.x - northWest.x),
            height: abs(southEast.y - northWest.y)
        )
    }
}

/// Nombre integrado directamente dentro del área del territorio, sin pill.
/// La selección se hace tocando cualquier punto del polígono.
private struct TerritoryMapNameLabel: View {
    let territory: Territory
    let status: TerritoryOperationalStatus
    let isSelected: Bool

    var body: some View {
        Text(territory.name)
            .font(.appSubheadline().weight(.bold))
            .foregroundStyle(Color.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: 118)
            .padding(6)
            .scaleEffect(isSelected ? 1.08 : 1)
            .shadow(color: .white.opacity(0.95), radius: 1)
            .shadow(color: presentation.color.opacity(isSelected ? 0.45 : 0.18), radius: isSelected ? 5 : 2)
            .allowsHitTesting(false)
            .accessibilityLabel(Text("\(territory.code), \(territory.name)"))
            .accessibilityValue(presentation.title)
    }

    private var presentation: TerritoryStatusPresentation {
        TerritoryStatusPresentation(status)
    }
}

private extension TerritoryMapCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct TerritoryLabelPlacement {
    let coordinate: CLLocationCoordinate2D
    let polygon: [TerritoryMapGeometryPreprocessor.Point]
    let bounds: MKMapRect
    let textSize: CGSize

    func withTextSize(_ textSize: CGSize) -> TerritoryLabelPlacement {
        TerritoryLabelPlacement(
            coordinate: coordinate,
            polygon: polygon,
            bounds: bounds,
            textSize: textSize
        )
    }
}

private struct TerritoryPreparedMapGeometry {
    let polygons: [TerritoryPreparedMapFeature]
    let polylines: [TerritoryPreparedMapFeature]
}

private struct TerritoryPreparedMapFeature: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
}

private extension Array where Element == MKMapPoint {
    var mapRect: MKMapRect {
        guard let first else { return .null }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in dropFirst() {
            minX = Swift.min(minX, point.x)
            maxX = Swift.max(maxX, point.x)
            minY = Swift.min(minY, point.y)
            maxY = Swift.max(maxY, point.y)
        }

        return MKMapRect(
            x: minX,
            y: minY,
            width: Swift.max(maxX - minX, 1),
            height: Swift.max(maxY - minY, 1)
        )
    }

    func closedWithFirstPoint() -> [MKMapPoint] {
        guard let first else { return self }
        var values = self
        if values.indices.contains(values.count - 1) {
            values[values.count - 1] = first
        }
        return values
    }
}
