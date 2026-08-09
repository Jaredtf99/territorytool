import Foundation

/// Preprocesado geométrico del explorador de mapa, fuera del actor principal.
///
/// Antes esto vivía dentro de `TerritoriesExplorerMap` como métodos de la `View`, así que
/// corría en main desde `onAppear` y en cada cambio del conjunto de territorios. Es el
/// trabajo síncrono más pesado de la pantalla: ajusta las fronteras entre territorios
/// vecinos y calcula el punto interior donde colocar cada etiqueta.
///
/// Usa un `Point` propio en vez de `MKMapPoint` para que la frontera de concurrencia no
/// dependa de tipos de MapKit. La conversión se hace en los bordes.
nonisolated struct TerritoryMapGeometryPreprocessor: Sendable {

    struct Point: Sendable, Equatable {
        var x: Double
        var y: Double
    }

    struct Rect: Sendable {
        var minX: Double
        var minY: Double
        var maxX: Double
        var maxY: Double

        func intersects(_ other: Rect) -> Bool {
            minX <= other.maxX && maxX >= other.minX && minY <= other.maxY && maxY >= other.minY
        }

        func expanded(by amount: Double) -> Rect {
            Rect(minX: minX - amount, minY: minY - amount, maxX: maxX + amount, maxY: maxY + amount)
        }

        static func bounding(_ points: [Point]) -> Rect {
            guard let first = points.first else {
                return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0)
            }
            var rect = Rect(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
            for point in points.dropFirst() {
                rect.minX = Swift.min(rect.minX, point.x)
                rect.minY = Swift.min(rect.minY, point.y)
                rect.maxX = Swift.max(rect.maxX, point.x)
                rect.maxY = Swift.max(rect.maxY, point.y)
            }
            return rect
        }
    }

    /// Entrada: un polígono o polilínea de un territorio, ya proyectado.
    struct Feature: Sendable {
        let territoryID: Int
        let id: String
        var points: [Point]

        var isClosed: Bool {
            guard let first = points.first, let last = points.last else { return false }
            return abs(first.x - last.x) < 0.001 && abs(first.y - last.y) < 0.001
        }
    }

    struct LabelPlacement: Sendable {
        let point: Point
        let polygon: [Point]
        let bounds: Rect
    }

    struct Output: Sendable {
        var polygonsByTerritory: [Int: [Feature]] = [:]
        var polylinesByTerritory: [Int: [Feature]] = [:]
        var labelPlacements: [Int: LabelPlacement] = [:]
    }

    /// Cancelación cooperativa: comprobar `Task.isCancelled` sólo entre fases no bastaría,
    /// porque cancelar la `Task` no detiene por sí solo el bucle síncrono que ya está en
    /// marcha. Aquí se comprueba dentro de los bucles.
    static func process(
        polygons: [Feature],
        polylines: [Feature],
        isCancelled: () -> Bool = { Task.isCancelled }
    ) -> Output? {
        var output = Output()

        let bounds = polygons.map { Rect.bounding($0.points) }
        let grid = SpatialGrid(features: polygons, bounds: bounds)

        for (index, polygon) in polygons.enumerated() {
            if isCancelled() { return nil }

            var adjusted = polygon
            adjusted.points = adjustedPoints(
                of: polygon,
                index: index,
                polygons: polygons,
                bounds: bounds,
                grid: grid,
                isCancelled: isCancelled
            )
            guard !adjusted.points.isEmpty else { return nil }
            output.polygonsByTerritory[polygon.territoryID, default: []].append(adjusted)
        }

        for polyline in polylines {
            if isCancelled() { return nil }
            output.polylinesByTerritory[polyline.territoryID, default: []].append(polyline)
        }

        // Una etiqueta por territorio, en su polígono de mayor área.
        var largestByTerritory: [Int: (points: [Point], area: Double)] = [:]
        for polygon in polygons where polygon.points.count >= 3 {
            if isCancelled() { return nil }
            let area = abs(projectedArea(polygon.points))
            if let existing = largestByTerritory[polygon.territoryID], existing.area >= area {
                continue
            }
            largestByTerritory[polygon.territoryID] = (polygon.points, area)
        }

        for (territoryID, candidate) in largestByTerritory {
            if isCancelled() { return nil }
            if let placement = polylabel(candidate.points, isCancelled: isCancelled) {
                output.labelPlacements[territoryID] = placement
            }
        }

        return output
    }

    // MARK: - Ajuste de fronteras entre vecinos

    /// Cuando un vértice de un territorio cae dentro de otro, se mueve a medio camino hacia
    /// el borde del vecino. En el caso habitual de dos fronteras casi paralelas que se
    /// solapan, ambos lados convergen hacia la línea media sin tocar la geometría guardada.
    private static func adjustedPoints(
        of polygon: Feature,
        index: Int,
        polygons: [Feature],
        bounds: [Rect],
        grid: SpatialGrid,
        isCancelled: () -> Bool
    ) -> [Point] {
        guard polygons.count > 1 else { return polygon.points }

        var result = polygon.points
        let closed = polygon.isClosed
        let lastIndex = result.count - 1

        for pointIndex in result.indices {
            if isCancelled() { return [] }

            // En un anillo cerrado el último punto es el primero: se copia al final.
            if closed, pointIndex == lastIndex { continue }

            result[pointIndex] = adjustedPoint(
                result[pointIndex],
                ownerIndex: index,
                polygons: polygons,
                bounds: bounds,
                grid: grid
            )
        }

        if closed, let first = result.first, lastIndex >= 0 {
            result[lastIndex] = first
        }
        return result
    }

    private static func adjustedPoint(
        _ point: Point,
        ownerIndex: Int,
        polygons: [Feature],
        bounds: [Rect],
        grid: SpatialGrid
    ) -> Point {
        var nearest: (point: Point, distanceSquared: Double)?
        let ownerTerritory = polygons[ownerIndex].territoryID

        // La rejilla acota los candidatos a los vecinos reales; antes se comparaba contra
        // todos los polígonos de todos los demás territorios.
        for candidateIndex in grid.candidates(for: point) {
            let candidate = polygons[candidateIndex]
            guard candidate.territoryID != ownerTerritory else { continue }
            guard bounds[candidateIndex].expanded(by: 1).contains(point) else { continue }
            guard signedDistance(from: point, to: candidate.points) > 0 else { continue }
            guard let boundary = closestBoundaryPoint(to: point, in: candidate.points) else { continue }

            if nearest == nil || boundary.distanceSquared < nearest!.distanceSquared {
                nearest = boundary
            }
        }

        guard let nearest else { return point }
        return Point(x: (point.x + nearest.point.x) / 2, y: (point.y + nearest.point.y) / 2)
    }

    // MARK: - Polylabel

    /// Punto interior más alejado del borde, para colocar la etiqueta.
    ///
    /// La versión anterior elegía la siguiente celda con `cells.indices.max(by:)`, que es
    /// O(n) por iteración y hasta 12.000 iteraciones. Aquí es un heap binario: O(log n).
    static func polylabel(
        _ polygon: [Point],
        precisionFactor: Double = 100,
        isCancelled: () -> Bool = { Task.isCancelled }
    ) -> LabelPlacement? {
        let rect = Rect.bounding(polygon)
        let width = rect.maxX - rect.minX
        let height = rect.maxY - rect.minY
        let cellSize = min(width, height)
        guard cellSize > 0 else { return nil }

        var heap = MaxHeap()
        let half = cellSize / 2
        var x = rect.minX
        while x < rect.maxX {
            var y = rect.minY
            while y < rect.maxY {
                heap.push(Cell(x: x + half, y: y + half, half: half, polygon: polygon))
                y += cellSize
            }
            x += cellSize
        }

        var best = centroidCell(polygon)
        let boundsCell = Cell(x: rect.minX + width / 2, y: rect.minY + height / 2, half: 0, polygon: polygon)
        if boundsCell.distance > best.distance { best = boundsCell }

        let precision = max(cellSize / precisionFactor, 0.5)
        var iterations = 0

        while let cell = heap.pop(), iterations < 12_000 {
            iterations += 1
            if iterations % 256 == 0, isCancelled() { return nil }

            if cell.distance > best.distance { best = cell }

            // Si la cota superior de esta celda ya no puede superar al mejor conocido,
            // dejamos de subdividirla pero seguimos vaciando el heap: el centro de una celda
            // que no merece subdividirse puede aun así estar hasta `precision` mejor que
            // `best`. Es lo que hacía la implementación original, y drenar cuesta O(log n)
            // por celda en vez del escaneo O(n) que hacía ella.
            if cell.maximum - best.distance <= precision { continue }

            let nextHalf = cell.half / 2
            heap.push(Cell(x: cell.x - nextHalf, y: cell.y - nextHalf, half: nextHalf, polygon: polygon))
            heap.push(Cell(x: cell.x + nextHalf, y: cell.y - nextHalf, half: nextHalf, polygon: polygon))
            heap.push(Cell(x: cell.x - nextHalf, y: cell.y + nextHalf, half: nextHalf, polygon: polygon))
            heap.push(Cell(x: cell.x + nextHalf, y: cell.y + nextHalf, half: nextHalf, polygon: polygon))
        }

        return LabelPlacement(
            point: Point(x: best.x, y: best.y),
            polygon: polygon,
            bounds: rect
        )
    }

    private static func centroidCell(_ polygon: [Point]) -> Cell {
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
            return Cell(x: polygon[0].x, y: polygon[0].y, half: 0, polygon: polygon)
        }
        return Cell(x: x / (3 * area), y: y / (3 * area), half: 0, polygon: polygon)
    }

    struct Cell: Sendable {
        let x: Double
        let y: Double
        let half: Double
        let distance: Double
        /// Cota superior de la distancia alcanzable dentro de la celda.
        let maximum: Double

        init(x: Double, y: Double, half: Double, polygon: [Point]) {
            self.x = x
            self.y = y
            self.half = half
            distance = signedDistance(from: Point(x: x, y: y), to: polygon)
            maximum = distance + half * squareRootOfTwo
        }
    }

    /// Heap binario ordenado por `maximum`.
    private struct MaxHeap {
        private var storage: [Cell] = []

        mutating func push(_ cell: Cell) {
            storage.append(cell)
            var child = storage.count - 1
            while child > 0 {
                let parent = (child - 1) / 2
                guard storage[child].maximum > storage[parent].maximum else { break }
                storage.swapAt(child, parent)
                child = parent
            }
        }

        mutating func pop() -> Cell? {
            guard let top = storage.first else { return nil }
            storage.swapAt(0, storage.count - 1)
            storage.removeLast()

            var parent = 0
            while true {
                let left = 2 * parent + 1
                let right = left + 1
                var largest = parent
                if left < storage.count, storage[left].maximum > storage[largest].maximum {
                    largest = left
                }
                if right < storage.count, storage[right].maximum > storage[largest].maximum {
                    largest = right
                }
                guard largest != parent else { break }
                storage.swapAt(parent, largest)
                parent = largest
            }
            return top
        }
    }

    // MARK: - Rejilla espacial

    /// Índice por celdas para acotar los vecinos candidatos de un punto.
    private struct SpatialGrid {
        private var buckets: [GridKey: [Int]] = [:]
        private let cellSize: Double

        struct GridKey: Hashable {
            let x: Int
            let y: Int
        }

        init(features: [Feature], bounds: [Rect]) {
            // Celda del tamaño del bounding box medio: mantiene los cubos pequeños sin
            // multiplicar las inserciones de un polígono grande.
            let averageSpan = bounds.isEmpty ? 1 : bounds.reduce(0.0) {
                $0 + max($1.maxX - $1.minX, $1.maxY - $1.minY)
            } / Double(bounds.count)
            cellSize = max(averageSpan, 1)

            for index in features.indices {
                let rect = bounds[index].expanded(by: 1)
                for key in Self.keys(covering: rect, cellSize: cellSize) {
                    buckets[key, default: []].append(index)
                }
            }
        }

        func candidates(for point: Point) -> [Int] {
            buckets[Self.key(for: point, cellSize: cellSize)] ?? []
        }

        private static func key(for point: Point, cellSize: Double) -> GridKey {
            GridKey(x: Int((point.x / cellSize).rounded(.down)), y: Int((point.y / cellSize).rounded(.down)))
        }

        private static func keys(covering rect: Rect, cellSize: Double) -> [GridKey] {
            let minX = Int((rect.minX / cellSize).rounded(.down))
            let maxX = Int((rect.maxX / cellSize).rounded(.down))
            let minY = Int((rect.minY / cellSize).rounded(.down))
            let maxY = Int((rect.maxY / cellSize).rounded(.down))

            var keys: [GridKey] = []
            for x in minX...maxX {
                for y in minY...maxY {
                    keys.append(GridKey(x: x, y: y))
                }
            }
            return keys
        }
    }
}

// MARK: - Geometría de apoyo

private let squareRootOfTwo = 2.0.squareRoot()

extension TerritoryMapGeometryPreprocessor.Rect {
    func contains(_ point: TerritoryMapGeometryPreprocessor.Point) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

/// Positiva dentro del polígono, negativa fuera; el valor absoluto es la distancia al borde.
func signedDistance(
    from point: TerritoryMapGeometryPreprocessor.Point,
    to polygon: [TerritoryMapGeometryPreprocessor.Point]
) -> Double {
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

func projectedArea(_ points: [TerritoryMapGeometryPreprocessor.Point]) -> Double {
    var area = 0.0
    for index in points.indices {
        let next = points[(index + 1) % points.count]
        area += points[index].x * next.y - next.x * points[index].y
    }
    return area / 2
}

private func squaredSegmentDistance(
    _ point: TerritoryMapGeometryPreprocessor.Point,
    _ start: TerritoryMapGeometryPreprocessor.Point,
    _ end: TerritoryMapGeometryPreprocessor.Point
) -> Double {
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

func closestBoundaryPoint(
    to point: TerritoryMapGeometryPreprocessor.Point,
    in polygon: [TerritoryMapGeometryPreprocessor.Point]
) -> (point: TerritoryMapGeometryPreprocessor.Point, distanceSquared: Double)? {
    guard polygon.count > 1 else { return nil }

    var closest: (point: TerritoryMapGeometryPreprocessor.Point, distanceSquared: Double)?
    var previous = polygon.count - 1
    for current in polygon.indices {
        let candidate = closestPointOnSegment(point, polygon[current], polygon[previous])
        if closest == nil || candidate.distanceSquared < closest!.distanceSquared {
            closest = candidate
        }
        previous = current
    }
    return closest
}

private func closestPointOnSegment(
    _ point: TerritoryMapGeometryPreprocessor.Point,
    _ start: TerritoryMapGeometryPreprocessor.Point,
    _ end: TerritoryMapGeometryPreprocessor.Point
) -> (point: TerritoryMapGeometryPreprocessor.Point, distanceSquared: Double) {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let candidate: TerritoryMapGeometryPreprocessor.Point

    if dx == 0 && dy == 0 {
        candidate = start
    } else {
        let rawT = ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)
        let t = min(1, max(0, rawT))
        candidate = TerritoryMapGeometryPreprocessor.Point(x: start.x + dx * t, y: start.y + dy * t)
    }

    let pointDX = point.x - candidate.x
    let pointDY = point.y - candidate.y
    return (candidate, pointDX * pointDX + pointDY * pointDY)
}
