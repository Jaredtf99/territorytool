import CryptoKit
import ImageIO
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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let snapshotImage {
                    Image(uiImage: snapshotImage)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Color.accent.opacity(0.06)
                }
            }
            .task(id: snapshotCacheKey(size: proxy.size, dark: colorScheme == .dark)) {
                await loadSnapshotImage(size: proxy.size, dark: colorScheme == .dark)
            }
        }
        .accessibilityHidden(true)
    }

    private func loadSnapshotImage(size: CGSize, dark: Bool) async {
        guard size.width > 1, size.height > 1 else { return }
        let cacheKey = snapshotCacheKey(size: size, dark: dark)
        if let cached = TerritorySnapshotCache.shared.image(for: cacheKey) {
            snapshotImage = cached
            return
        }

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
            let image = renderedSnapshotImage(from: result, size: size, traitCollection: traitCollection)
            TerritorySnapshotCache.shared.insert(image, for: cacheKey)
            snapshotImage = image
        }
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
            "v2",
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

@MainActor
final class TerritorySnapshotCache {
    static let shared = TerritorySnapshotCache()

    private var images: [String: UIImage] = [:]
    private var order: [String] = []
    private let capacity = 80
    private let diskCapacityBytes = 50 * 1024 * 1024
    private let maxDiskAge: TimeInterval = 30 * 24 * 60 * 60
    private let fileManager = FileManager.default
    private let directory: URL

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = caches.appendingPathComponent("TerritorySnapshotCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func image(for key: String) -> UIImage? {
        if let image = images[key] {
            markRecentlyUsed(key)
            return image
        }

        for url in fileURLs(for: key) {
            if isExpired(url) {
                try? fileManager.removeItem(at: url)
                continue
            }

            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                continue
            }

            insertInMemory(image, for: key)
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            return image
        }

        return nil
    }

    func insert(_ image: UIImage, for key: String) {
        insertInMemory(image, for: key)

        if let encoded = encodedData(for: image) {
            try? encoded.data.write(to: fileURL(for: key, extension: encoded.fileExtension), options: [.atomic])
            removeAlternativeFormats(for: key, keeping: encoded.fileExtension)
            pruneDiskCacheIfNeeded()
        }
    }

    func diskSizeBytes() -> Int64 {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return urls.reduce(into: Int64(0)) { total, url in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]) else { return }
            total += Int64(values.fileSize ?? 0)
        }
    }

    func clear() {
        images.removeAll()
        order.removeAll()

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls {
            try? fileManager.removeItem(at: url)
        }
    }

    private func insertInMemory(_ image: UIImage, for key: String) {
        images[key] = image
        markRecentlyUsed(key)
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            images.removeValue(forKey: oldest)
        }
    }

    private func markRecentlyUsed(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    private func fileURLs(for key: String) -> [URL] {
        [
            fileURL(for: key, extension: "heic"),
            fileURL(for: key, extension: "jpg"),
            fileURL(for: key, extension: "png")
        ]
    }

    private func fileURL(for key: String, extension fileExtension: String) -> URL {
        directory.appendingPathComponent(key.sha256Hex).appendingPathExtension(fileExtension)
    }

    private func removeAlternativeFormats(for key: String, keeping fileExtension: String) {
        for url in fileURLs(for: key) where url.pathExtension != fileExtension {
            try? fileManager.removeItem(at: url)
        }
    }

    private func encodedData(for image: UIImage) -> (data: Data, fileExtension: String)? {
        if let heicData = image.heicData(compressionQuality: 0.38) {
            return (heicData, "heic")
        }

        if let jpegData = image.jpegData(compressionQuality: 0.88) {
            return (jpegData, "jpg")
        }

        return image.pngData().map { ($0, "png") }
    }

    private func isExpired(_ url: URL, now: Date = Date()) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else {
            return false
        }
        return now.timeIntervalSince(modified) > maxDiskAge
    }

    private func pruneDiskCacheIfNeeded() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var entries: [(url: URL, modified: Date, size: Int)] = []
        var totalSize = 0
        let now = Date()

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                continue
            }
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > maxDiskAge {
                try? fileManager.removeItem(at: url)
                continue
            }
            let size = values.fileSize ?? 0
            totalSize += size
            entries.append((url, modified, size))
        }

        guard totalSize > diskCapacityBytes else { return }

        for entry in entries.sorted(by: { $0.modified < $1.modified }) {
            try? fileManager.removeItem(at: entry.url)
            totalSize -= entry.size
            if totalSize <= diskCapacityBytes { break }
        }
    }
}

private extension Color {
    func snapshotColorKey(using traitCollection: UITraitCollection) -> String {
        UIColor(self).resolvedColor(with: traitCollection).snapshotColorKey
    }
}

private extension UIImage {
    func heicData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage else { return nil }
        let imageToEncode = opaqueRGBCGImage ?? cgImage

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary

        CGImageDestinationAddImage(destination, imageToEncode, options)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }

    private var opaqueRGBCGImage: CGImage? {
        guard let cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
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

private extension String {
    var sha256Hex: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension TerritoryMapGeometry {
    var snapshotFingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(self) {
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }

        let boundsKey = [
            String(format: "%.6f", bounds.south),
            String(format: "%.6f", bounds.west),
            String(format: "%.6f", bounds.north),
            String(format: "%.6f", bounds.east)
        ].joined(separator: ",")
        return "\(version)|\(boundsKey)|p:\(polygons.count)|l:\(polylines.count)|m:\(markers.count)"
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
