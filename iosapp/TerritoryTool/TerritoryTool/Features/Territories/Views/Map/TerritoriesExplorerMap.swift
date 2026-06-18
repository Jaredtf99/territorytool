import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct TerritoriesExplorerMap: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    @ObservedObject var locationService: TerritoryLocationService
    var topInset: CGFloat = 0
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
                            viewportHeight: proxy.size.height,
                            topSafeInset: topSafe,
                            drawerHeight: drawerHeight(
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
        .onAppear {
            updateMapCaches()
            focusOnPrimary(animated: false)
        }
        .onChange(of: viewModel.territoriesWithGeometry) { _, _ in
            updateMapCaches()
            if !didFitInitialResults {
                focusOnPrimary(animated: true)
            } else if !viewModel.searchText.isEmpty {
                fitResults(animated: true)
            }
        }
        .onChange(of: viewModel.selectedTerritoryID) { _, _ in
            updateVisibleLabels()
        }
        .onChange(of: locationService.location?.coordinate.latitude) { _, _ in
            guard let location = locationService.location else { return }
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
                                attentionDays: viewModel.attentionDays,
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
            }
            .onTapGesture { point in
                handleMapTap(point, proxy: proxy)
            }
            .accessibilityLabel(Text("territories.map.accessibility"))
        }
    }

    /// Selecciona el territorio cuyo polígono contiene el punto tocado.
    private func handleMapTap(_ point: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(point, from: .local) else { return }
        if let territory = territory(containing: coordinate) {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                viewModel.select(territory)
            }
        } else if viewModel.selectedTerritoryID != nil {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.select(nil)
            }
        }
    }

    private func territory(containing coordinate: CLLocationCoordinate2D) -> Territory? {
        viewModel.territoriesWithGeometry.first { territory in
            territory.mapGeometry?.polygons.contains { polygon in
                pointInPolygon(coordinate, polygon.coordinates)
            } ?? false
        }
    }

    private func pointInPolygon(_ point: CLLocationCoordinate2D, _ coordinates: [TerritoryMapCoordinate]) -> Bool {
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
        Button {
            if locationService.isDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } else {
                locationService.requestLocation()
            }
            if let location = locationService.location {
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
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(locationService.isDenied ? "territories.location.settings" : "territories.location.button"))
        .foregroundStyle(Color.accentDeep)
    }

    private func style(for territory: Territory) -> (color: Color, lineWidth: CGFloat) {
        switch territory.operationalStatus(attentionDays: viewModel.attentionDays) {
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
        viewportHeight: CGFloat? = nil,
        topSafeInset: CGFloat = 0,
        drawerHeight: CGFloat = 0
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
        var padded = rect.insetBy(dx: -max(rect.width * 1.0, 600), dy: -max(rect.height * 1.0, 600))

        if let viewportHeight, viewportHeight > 0, drawerHeight > 0 {
            let visibleTop = topSafeInset + topInset
            let visibleBottom = max(viewportHeight - drawerHeight, visibleTop)
            let desiredScreenY = (visibleTop + visibleBottom) / 2
            let screenOffset = viewportHeight / 2 - desiredScreenY
            let mapOffset = padded.height * Double(screenOffset / viewportHeight)
            padded = padded.offsetBy(dx: 0, dy: mapOffset)
        }

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
        let samples = [
            MKMapPoint(x: center.x - halfWidth, y: center.y - halfHeight),
            MKMapPoint(x: center.x, y: center.y - halfHeight),
            MKMapPoint(x: center.x + halfWidth, y: center.y - halfHeight),
            MKMapPoint(x: center.x - halfWidth, y: center.y),
            center,
            MKMapPoint(x: center.x + halfWidth, y: center.y),
            MKMapPoint(x: center.x - halfWidth, y: center.y + halfHeight),
            MKMapPoint(x: center.x, y: center.y + halfHeight),
            MKMapPoint(x: center.x + halfWidth, y: center.y + halfHeight)
        ]

        // Un pequeño margen negativo evita parpadeos por redondeo justo en el borde.
        let tolerance = max(halfWidth, halfHeight) * 0.08
        return samples.allSatisfy {
            signedDistance(from: $0, to: placement.polygon) >= -tolerance
        }
    }

    private func updateMapCaches() {
        var placements: [Int: TerritoryLabelPlacement] = [:]
        var geometries: [Int: TerritoryPreparedMapGeometry] = [:]

        for territory in viewModel.territoriesWithGeometry {
            guard let geometry = territory.mapGeometry else { continue }
            geometries[territory.id] = TerritoryPreparedMapGeometry(
                polygons: geometry.polygons.map {
                    TerritoryPreparedMapFeature(
                        id: $0.id,
                        coordinates: $0.coordinates.map(\.clCoordinate)
                    )
                },
                polylines: geometry.polylines.map {
                    TerritoryPreparedMapFeature(
                        id: $0.id,
                        coordinates: $0.coordinates.map(\.clCoordinate)
                    )
                }
            )
            if let placement = geometry.labelPlacement {
                placements[territory.id] = placement.withTextSize(labelTextSize(for: territory.name))
            }
        }

        preparedGeometries = geometries
        labelPlacements = placements
        visibleLabelIDs = calculateVisibleLabelIDs(in: visibleMapRect, placements: placements)
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
    let attentionDays: Int
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
        TerritoryStatusPresentation(territory.operationalStatus(attentionDays: attentionDays))
    }
}

private extension TerritoryMapCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct TerritoryLabelPlacement {
    let coordinate: CLLocationCoordinate2D
    let polygon: [MKMapPoint]
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

private extension TerritoryMapGeometry {
    var labelPlacement: TerritoryLabelPlacement? {
        let candidates = polygons.compactMap { polygon -> ([MKMapPoint], Double)? in
            let points = polygon.coordinates.map { MKMapPoint($0.clCoordinate) }
            guard points.count >= 3 else { return nil }
            return (points, abs(projectedArea(points)))
        }
        guard let points = candidates.max(by: { $0.1 < $1.1 })?.0 else { return nil }
        return polylabel(points)
    }

    func projectedArea(_ points: [MKMapPoint]) -> Double {
        var area = 0.0
        for index in points.indices {
            let next = points[(index + 1) % points.count]
            area += points[index].x * next.y - next.x * points[index].y
        }
        return area / 2
    }

    func polylabel(_ polygon: [MKMapPoint]) -> TerritoryLabelPlacement? {
        let minX = polygon.map(\.x).min() ?? 0
        let minY = polygon.map(\.y).min() ?? 0
        let maxX = polygon.map(\.x).max() ?? 0
        let maxY = polygon.map(\.y).max() ?? 0
        let width = maxX - minX
        let height = maxY - minY
        let cellSize = min(width, height)
        guard cellSize > 0 else { return nil }

        var cells: [LabelCell] = []
        let half = cellSize / 2
        var x = minX
        while x < maxX {
            var y = minY
            while y < maxY {
                cells.append(LabelCell(x: x + half, y: y + half, half: half, polygon: polygon))
                y += cellSize
            }
            x += cellSize
        }

        var best = centroidCell(polygon)
        let boundsCell = LabelCell(x: minX + width / 2, y: minY + height / 2, half: 0, polygon: polygon)
        if boundsCell.distance > best.distance { best = boundsCell }

        let precision = max(cellSize / 100, 0.5)
        var iterations = 0
        while let index = cells.indices.max(by: { cells[$0].maximum < cells[$1].maximum }),
              iterations < 12_000 {
            let cell = cells.remove(at: index)
            if cell.distance > best.distance { best = cell }
            if cell.maximum - best.distance <= precision {
                iterations += 1
                continue
            }
            let nextHalf = cell.half / 2
            cells.append(LabelCell(x: cell.x - nextHalf, y: cell.y - nextHalf, half: nextHalf, polygon: polygon))
            cells.append(LabelCell(x: cell.x + nextHalf, y: cell.y - nextHalf, half: nextHalf, polygon: polygon))
            cells.append(LabelCell(x: cell.x - nextHalf, y: cell.y + nextHalf, half: nextHalf, polygon: polygon))
            cells.append(LabelCell(x: cell.x + nextHalf, y: cell.y + nextHalf, half: nextHalf, polygon: polygon))
            iterations += 1
        }

        let point = MKMapPoint(x: best.x, y: best.y)
        return TerritoryLabelPlacement(
            coordinate: point.coordinate,
            polygon: polygon,
            bounds: MKMapRect(
                x: minX,
                y: minY,
                width: width,
                height: height
            ),
            textSize: .zero
        )
    }

    func centroidCell(_ polygon: [MKMapPoint]) -> LabelCell {
        var area = 0.0
        var x = 0.0
        var y = 0.0
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            let factor = polygon[index].x * next.y - next.x * polygon[index].y
            x += (polygon[index].x + next.x) * factor
            y += (polygon[index].y + next.y) * factor
            area += factor
        }
        guard abs(area) > .ulpOfOne else {
            return LabelCell(x: polygon[0].x, y: polygon[0].y, half: 0, polygon: polygon)
        }
        return LabelCell(x: x / (3 * area), y: y / (3 * area), half: 0, polygon: polygon)
    }
}

private struct LabelCell {
    let x: Double
    let y: Double
    let half: Double
    let distance: Double
    let maximum: Double

    init(x: Double, y: Double, half: Double, polygon: [MKMapPoint]) {
        self.x = x
        self.y = y
        self.half = half
        distance = signedDistance(from: MKMapPoint(x: x, y: y), to: polygon)
        maximum = distance + half * squareRootOfTwo
    }
}

private let squareRootOfTwo = 2.0.squareRoot()

private func signedDistance(from point: MKMapPoint, to polygon: [MKMapPoint]) -> Double {
    var inside = false
    var minimumSquaredDistance = Double.greatestFiniteMagnitude
    var previous = polygon.count - 1

    for current in polygon.indices {
        let a = polygon[current]
        let b = polygon[previous]
        if (a.y > point.y) != (b.y > point.y),
           point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
            inside.toggle()
        }
        minimumSquaredDistance = min(minimumSquaredDistance, squaredSegmentDistance(point, a, b))
        previous = current
    }

    let distance = minimumSquaredDistance.squareRoot()
    return inside ? distance : -distance
}

private func squaredSegmentDistance(_ point: MKMapPoint, _ start: MKMapPoint, _ end: MKMapPoint) -> Double {
    var x = start.x
    var y = start.y
    let dx = end.x - x
    let dy = end.y - y

    if dx != 0 || dy != 0 {
        let t = ((point.x - x) * dx + (point.y - y) * dy) / (dx * dx + dy * dy)
        if t > 1 {
            x = end.x
            y = end.y
        } else if t > 0 {
            x += dx * t
            y += dy * t
        }
    }

    let pointDX = point.x - x
    let pointDY = point.y - y
    return pointDX * pointDX + pointDY * pointDY
}
