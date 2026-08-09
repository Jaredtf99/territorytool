@preconcurrency import MapKit
import SwiftUI
import UIKit

struct TerritoryMapView: View {
    let geometry: TerritoryMapGeometry
    var compact = false
    /// Oculta los marcadores y deja sólo los bordes del territorio.
    var showsMarkers = true
    /// Suaviza los picos del polígono con corner-cutting (Chaikin).
    var smoothCorners = false
    /// Permite pan/zoom (mapa a pantalla completa); por defecto es estático.
    var interactive = false

    var body: some View {
        Map(
            initialPosition: .camera(geometry.camera(compact: compact)),
            interactionModes: interactive ? [.pan, .zoom, .rotate] : []
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
        .allowsHitTesting(interactive)
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
    /// Multiplicador de distancia de cámara (más = territorio más pequeño).
    /// `nil` usa el valor histórico (2.4, o 2.0 centrado).
    var distanceMultiplier: Double? = nil
    /// Desplazamiento del centro de cámara hacia el oeste, en fracción del
    /// ancho del bounding box (el territorio se va a la derecha). `nil` usa
    /// el histórico (0.5, o 0 centrado).
    var horizontalShift: Double? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var snapshotImage: UIImage?
    @State private var displayedCacheKey: String?

    var body: some View {
        GeometryReader { proxy in
            let cacheKey = snapshotCacheKey(size: proxy.size, dark: colorScheme == .dark)

            ZStack {
                if let snapshotImage, displayedCacheKey == cacheKey {
                    Image(uiImage: snapshotImage)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Color.accent.opacity(0.06)
                }
            }
            .task(id: cacheKey) {
                await loadSnapshotImage(size: proxy.size, dark: colorScheme == .dark)
            }
        }
        .accessibilityHidden(true)
    }

    private func loadSnapshotImage(size: CGSize, dark: Bool) async {
        guard size.width > 1, size.height > 1 else { return }
        let cacheKey = snapshotCacheKey(size: size, dark: dark)
        // La lectura de disco y la descompresión ocurren en el worker; aquí sólo se espera.
        if let cached = await TerritorySnapshotCache.shared.image(for: cacheKey) {
            guard !Task.isCancelled else { return }
            snapshotImage = cached
            displayedCacheKey = cacheKey
            return
        }
        guard !Task.isCancelled else { return }

        let traitCollection = snapshotTraitCollection(dark: dark)
        let options = MKMapSnapshotter.Options()
        options.camera = territoryCamera()
        options.size = size
        options.traitCollection = traitCollection
        // Relieve realista (3D) + sin puntos de interés que distraigan.
        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        let snapshotter = MKMapSnapshotter(options: options)
        let result = try? await withTaskCancellationHandler {
            try await snapshotter.start()
        } onCancel: {
            snapshotter.cancel()
        }
        guard let result,
              !Task.isCancelled,
              snapshotCacheKey(size: size, dark: colorScheme == .dark) == cacheKey else { return }

        let image = renderedSnapshotImage(from: result, size: size, traitCollection: traitCollection)
        TerritorySnapshotCache.shared.insert(image, for: cacheKey)
        snapshotImage = image
        displayedCacheKey = cacheKey
    }

    private func renderedSnapshotImage(
        from snapshot: MKMapSnapshotter.Snapshot,
        size: CGSize,
        traitCollection: UITraitCollection
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        format.opaque = true

        let strokeColor = UIColor(stroke).resolvedColor(with: traitCollection)
        let fillColor = UIColor(fill).resolvedColor(with: traitCollection)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            snapshot.image.draw(in: CGRect(origin: .zero, size: size))

            func makePath(_ coordinates: [CLLocationCoordinate2D], closed: Bool) -> UIBezierPath {
                let path = UIBezierPath()
                guard let first = coordinates.first else { return path }
                path.move(to: snapshot.point(for: first))
                for coordinate in coordinates.dropFirst() {
                    path.addLine(to: snapshot.point(for: coordinate))
                }
                if closed { path.close() }
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                return path
            }

            for polygon in geometry.polygons {
                let path = makePath(polygon.mapCoordinates.roundedCorners(), closed: true)
                fillColor.withAlphaComponent(0.16).setFill()
                path.fill()
                strokeColor.setStroke()
                path.lineWidth = strokeLineWidth
                path.stroke()
            }

            for polyline in geometry.polylines {
                let path = makePath(polyline.mapCoordinates.roundedCorners(closed: false), closed: false)
                strokeColor.withAlphaComponent(0.85).setStroke()
                path.lineWidth = 2.5
                path.stroke()
            }
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
        let shift = horizontalShift ?? (centersTerritory ? 0 : 0.5)
        let multiplier = distanceMultiplier ?? (centersTerritory ? 2.0 : 2.4)
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: (bounds.east + bounds.west) / 2 - lonSpan * shift
        )

        return MKMapCamera(
            lookingAtCenter: center,
            fromDistance: max(footprintMeters * multiplier, centersTerritory ? 180 : 260),
            pitch: centersTerritory ? 48 : 45,
            heading: 0
        )
    }

    private func snapshotCacheKey(size: CGSize, dark: Bool) -> String {
        let bounds = geometry.bounds
        let traitCollection = snapshotTraitCollection(dark: dark)
        return [
            // v3: cambió el algoritmo de `snapshotFingerprint`, así que las entradas
            // antiguas del disco ya no se pueden alcanzar y las retira la poda por edad.
            "v3",
            geometry.snapshotFingerprint,
            String(format: "%.6f", bounds.south),
            String(format: "%.6f", bounds.west),
            String(format: "%.6f", bounds.north),
            String(format: "%.6f", bounds.east),
            "\(geometry.version)",
            "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(String(format: "%.1f", displayScale))",
            dark ? "dark" : "light",
            centersTerritory ? "center" : "trailing",
            String(format: "%.2f", verticalBias),
            String(format: "%.2f", distanceMultiplier ?? -1),
            String(format: "%.2f", horizontalShift ?? -1),
            String(format: "%.1f", strokeLineWidth),
            stroke.snapshotColorKey(using: traitCollection),
            fill.snapshotColorKey(using: traitCollection)
        ].joined(separator: "|")
    }

    private func snapshotTraitCollection(dark: Bool) -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: dark ? .dark : .light),
            UITraitCollection(displayScale: displayScale)
        ])
    }
}

private extension Color {
    func snapshotColorKey(using traitCollection: UITraitCollection) -> String {
        UIColor(self).resolvedColor(with: traitCollection).snapshotColorKey
    }
}

private extension UIColor {
    var snapshotColorKey: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return String(format: "%.3f,%.3f,%.3f,%.3f", red, green, blue, alpha)
        }
        return cgColor.components?.map { String(format: "%.3f", $0) }.joined(separator: ",") ?? "\(hash)"
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
