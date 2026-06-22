import MapKit
import SwiftUI
import UIKit

struct TerritoryMapView: View {
    let geometry: TerritoryMapGeometry
    var compact = false
    /// Oculta los marcadores y deja sólo los bordes del territorio.
    var showsMarkers = true
    /// Suaviza los picos del polígono con corner-cutting (Chaikin).
    var smoothCorners = false

    var body: some View {
        Map(
            initialPosition: .camera(geometry.camera(compact: compact)),
            interactionModes: []
        ) {
            ForEach(geometry.polygons) { polygon in
                MapPolygon(
                    coordinates: smoothCorners
                        ? polygon.mapCoordinates.roundedCorners()
                        : polygon.mapCoordinates
                )
                .foregroundStyle(Color.accent.opacity(0.14))
                .stroke(Color.accentDeep, lineWidth: compact ? 2.5 : 3)
            }

            ForEach(geometry.polylines) { polyline in
                MapPolyline(
                    coordinates: smoothCorners
                        ? polyline.mapCoordinates.roundedCorners(closed: false)
                        : polyline.mapCoordinates
                )
                .stroke(
                    Color.accentDeep,
                    style: StrokeStyle(lineWidth: compact ? 2.5 : 3, lineCap: .round, lineJoin: .round)
                )
            }

            if showsMarkers {
                ForEach(geometry.markers) { marker in
                    if compact {
                        Annotation("", coordinate: marker.mapCoordinate) {
                            Circle()
                                .fill(Color.accentColor)
                                .stroke(.white, lineWidth: 1)
                                .frame(width: 7, height: 7)
                                .shadow(radius: 1)
                        }
                        .annotationTitles(.hidden)
                    } else {
                        Marker(
                            marker.title ?? "",
                            monogram: Text(marker.title ?? "•"),
                            coordinate: marker.mapCoordinate
                        )
                        .tint(Color.accentColor)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .allowsHitTesting(false)
        .accessibilityLabel(Text("territory.detail.map"))
    }
}

/// Fondo de mapa real para tarjetas: rasteriza los tiles con `MKMapSnapshotter`
/// (imagen estática → se enmascara con antialias, a diferencia de un `Map` en vivo)
/// y dibuja encima el contorno del territorio. El territorio queda hacia la derecha,
/// con relleno y mismo aspecto que el contenedor.
struct TerritorySnapshotBackdrop: View {
    let geometry: TerritoryMapGeometry
    var stroke: Color = .accentDeep
    var fill: Color = .accent
    var centersTerritory = false
    var strokeLineWidth: CGFloat = 3
    /// Sube (>0) o baja (<0) el territorio dentro del encuadre, en fracción del
    /// alto del bounding box. 0 = centrado verticalmente.
    var verticalBias: Double = 0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var snapshot: MKMapSnapshotter.Snapshot?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let snapshot {
                    Image(uiImage: snapshot.image)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    Canvas { context, _ in
                        let project: (CLLocationCoordinate2D) -> CGPoint = { snapshot.point(for: $0) }

                        func makePath(_ coordinates: [CLLocationCoordinate2D], closed: Bool) -> Path {
                            var path = Path()
                            guard let first = coordinates.first else { return path }
                            path.move(to: project(first))
                            for coordinate in coordinates.dropFirst() {
                                path.addLine(to: project(coordinate))
                            }
                            if closed { path.closeSubpath() }
                            return path
                        }

                        for polygon in geometry.polygons {
                            let path = makePath(polygon.mapCoordinates.roundedCorners(), closed: true)
                            context.fill(path, with: .color(fill.opacity(0.16)))
                            context.stroke(
                                path,
                                with: .color(stroke),
                                style: StrokeStyle(lineWidth: strokeLineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                        for polyline in geometry.polylines {
                            let path = makePath(polyline.mapCoordinates.roundedCorners(closed: false), closed: false)
                            context.stroke(
                                path,
                                with: .color(stroke.opacity(0.85)),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Color.accent.opacity(0.06)
                }
            }
            .task(id: SnapshotKey(
                width: proxy.size.width,
                height: proxy.size.height,
                dark: colorScheme == .dark,
                centered: centersTerritory,
                bias: verticalBias
            )) {
                await loadSnapshot(size: proxy.size, dark: colorScheme == .dark)
            }
        }
        .accessibilityHidden(true)
    }

    private struct SnapshotKey: Equatable {
        let width: CGFloat
        let height: CGFloat
        let dark: Bool
        let centered: Bool
        let bias: Double
    }

    private func loadSnapshot(size: CGSize, dark: Bool) async {
        guard size.width > 1, size.height > 1 else { return }
        let cacheKey = snapshotCacheKey(size: size, dark: dark)
        if let cached = TerritorySnapshotCache.shared.snapshot(for: cacheKey) {
            snapshot = cached
            return
        }

        let options = MKMapSnapshotter.Options()
        options.camera = territoryCamera()
        options.size = size
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: dark ? .dark : .light),
            UITraitCollection(displayScale: displayScale)
        ])
        // Relieve realista (3D) + sin puntos de interés que distraigan.
        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        let snapshotter = MKMapSnapshotter(options: options)
        let result = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MKMapSnapshotter.Snapshot, Error>) in
            snapshotter.start(with: .global(qos: .userInitiated)) { snap, error in
                if let snap {
                    continuation.resume(returning: snap)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.featureUnsupported))
                }
            }
        }
        if let result {
            TerritorySnapshotCache.shared.insert(result, for: cacheKey)
            snapshot = result
        }
    }

    /// Cámara inclinada (3D) centrada al oeste del territorio para que el bounding
    /// box quede en la mitad derecha del fotograma.
    private func territoryCamera() -> MKMapCamera {
        let bounds = geometry.bounds
        let latSpan = bounds.north - bounds.south
        // Bias positivo => centro de cámara más al sur => territorio sube en el encuadre.
        let centerLat = (bounds.north + bounds.south) / 2 - latSpan * verticalBias
        let lonSpan = bounds.east - bounds.west

        let northwest = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west))
        let southeast = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east))
        let footprintPoints = max(abs(southeast.x - northwest.x), abs(southeast.y - northwest.y))
        let metersPerPoint = MKMetersPerMapPointAtLatitude(centerLat)
        let footprintMeters = footprintPoints * metersPerPoint

        // En tarjetas grandes se desplaza al oeste para dejar espacio al texto.
        // En miniaturas se centra para aprovechar todo el encuadre.
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: (bounds.east + bounds.west) / 2 - (centersTerritory ? 0 : lonSpan * 0.5)
        )

        return MKMapCamera(
            lookingAtCenter: center,
            fromDistance: max(footprintMeters * (centersTerritory ? 2.0 : 2.4), centersTerritory ? 180 : 260),
            pitch: centersTerritory ? 48 : 45,
            heading: 0
        )
    }

    private func snapshotCacheKey(size: CGSize, dark: Bool) -> String {
        let bounds = geometry.bounds
        return [
            String(format: "%.6f", bounds.south),
            String(format: "%.6f", bounds.west),
            String(format: "%.6f", bounds.north),
            String(format: "%.6f", bounds.east),
            "\(geometry.version)",
            "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))",
            dark ? "dark" : "light",
            centersTerritory ? "center" : "trailing",
            String(format: "%.2f", verticalBias),
            String(format: "%.1f", strokeLineWidth)
        ].joined(separator: "|")
    }
}

@MainActor
private final class TerritorySnapshotCache {
    static let shared = TerritorySnapshotCache()

    private var snapshots: [String: MKMapSnapshotter.Snapshot] = [:]
    private var order: [String] = []
    private let capacity = 80

    func snapshot(for key: String) -> MKMapSnapshotter.Snapshot? {
        snapshots[key]
    }

    func insert(_ snapshot: MKMapSnapshotter.Snapshot, for key: String) {
        snapshots[key] = snapshot
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            snapshots.removeValue(forKey: oldest)
        }
    }
}

private extension Array where Element == CLLocationCoordinate2D {
    /// Redondea ligeramente las esquinas con un radio fijo pequeño (tipo "fillet"):
    /// las aristas rectas se conservan y sólo se suaviza la punta de cada vértice,
    /// de modo que la forma sigue siendo fiel al bounding original (no se "redondea
    /// de más" como con Chaikin). Trabaja en el plano de MKMapPoint.
    ///
    /// - radiusFraction: radio como fracción de la dimensión menor del recorrido.
    /// - segments: número de tramos por esquina (más = más curva).
    func roundedCorners(
        radiusFraction: Double = 0.16,
        segments: Int = 5,
        closed: Bool = true
    ) -> [CLLocationCoordinate2D] {
        // Normaliza el cierre duplicado (primer punto == último).
        var points = map(MKMapPoint.init)
        if closed, let first = points.first, let last = points.last,
           first.x == last.x, first.y == last.y {
            points.removeLast()
        }
        let n = points.count
        guard n >= 3 else { return self }

        // Radio base a partir del tamaño del recorrido.
        let xs = points.map(\.x), ys = points.map(\.y)
        let spanX = (xs.max() ?? 0) - (xs.min() ?? 0)
        let spanY = (ys.max() ?? 0) - (ys.min() ?? 0)
        let radius = Swift.min(spanX, spanY) * radiusFraction
        guard radius > 0 else { return self }

        func sub(_ a: MKMapPoint, _ b: MKMapPoint) -> (Double, Double) { (a.x - b.x, a.y - b.y) }
        func length(_ v: (Double, Double)) -> Double { (v.0 * v.0 + v.1 * v.1).squareRoot() }

        var result: [MKMapPoint] = []
        let range = closed ? 0..<n : 1..<(n - 1)

        if !closed { result.append(points[0]) }

        for i in range {
            let prev = points[(i - 1 + n) % n]
            let curr = points[i]
            let next = points[(i + 1) % n]

            let toPrev = sub(prev, curr), toNext = sub(next, curr)
            let lenPrev = length(toPrev), lenNext = length(toNext)
            guard lenPrev > 0, lenNext > 0 else { result.append(curr); continue }

            // Limita el radio a la mitad de las aristas adyacentes.
            let d = Swift.min(radius, lenPrev * 0.5, lenNext * 0.5)
            let ax = curr.x + toPrev.0 / lenPrev * d
            let ay = curr.y + toPrev.1 / lenPrev * d
            let bx = curr.x + toNext.0 / lenNext * d
            let by = curr.y + toNext.1 / lenNext * d

            // Bézier cuadrática a→(curr)→b para redondear la punta.
            for s in 0...segments {
                let t = Double(s) / Double(segments)
                let mt = 1 - t
                let w0 = mt * mt
                let w1 = 2 * mt * t
                let w2 = t * t
                let px = w0 * ax + w1 * curr.x + w2 * bx
                let py = w0 * ay + w1 * curr.y + w2 * by
                result.append(MKMapPoint(x: px, y: py))
            }
        }

        if !closed { result.append(points[n - 1]) }

        return result.map(\.coordinate)
    }
}

private extension TerritoryMapFeature {
    var mapCoordinates: [CLLocationCoordinate2D] {
        coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}

private extension TerritoryMapMarker {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension TerritoryMapGeometry {
    func camera(compact: Bool) -> MapCamera {
        let northwest = MKMapPoint(
            CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west)
        )
        let southeast = MKMapPoint(
            CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east)
        )

        let minX = min(northwest.x, southeast.x)
        let minY = min(northwest.y, southeast.y)
        let width = max(abs(southeast.x - northwest.x), 100)
        let height = max(abs(southeast.y - northwest.y), 100)
        let centerPoint = MKMapPoint(
            x: minX + width / 2,
            y: minY + height / 2
        )
        let center = centerPoint.coordinate
        let metersPerPoint = MKMetersPerMapPointAtLatitude(center.latitude)
        let footprintMeters = max(width, height) * metersPerPoint
        let distanceMultiplier = compact ? 2.1 : 1.75

        return MapCamera(
            centerCoordinate: center,
            distance: max(footprintMeters * distanceMultiplier, compact ? 180 : 140),
            heading: 0,
            pitch: compact ? 48 : 55
        )
    }
}
