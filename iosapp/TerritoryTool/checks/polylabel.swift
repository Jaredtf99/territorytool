import Foundation

// Golden test: el heap binario nuevo debe dar el mismo punto que el `max(by:)` original.
// Reimplementa la versión ANTIGUA aquí y la compara con la de producción.

typealias P = TerritoryMapGeometryPreprocessor.Point

struct LegacyCell {
    let x, y, half, distance, maximum: Double
    init(x: Double, y: Double, half: Double, polygon: [P]) {
        self.x = x; self.y = y; self.half = half
        distance = signedDistance(from: P(x: x, y: y), to: polygon)
        maximum = distance + half * 2.0.squareRoot()
    }
}

/// Versión original: escaneo lineal con `cells.indices.max(by:)`, O(n) por iteración.
func legacyPolylabel(_ polygon: [P]) -> (Double, Double)? {
    let minX = polygon.map(\.x).min() ?? 0, minY = polygon.map(\.y).min() ?? 0
    let maxX = polygon.map(\.x).max() ?? 0, maxY = polygon.map(\.y).max() ?? 0
    let width = maxX - minX, height = maxY - minY
    let cellSize = min(width, height)
    guard cellSize > 0 else { return nil }

    var cells: [LegacyCell] = []
    let half = cellSize / 2
    var x = minX
    while x < maxX {
        var y = minY
        while y < maxY { cells.append(LegacyCell(x: x + half, y: y + half, half: half, polygon: polygon)); y += cellSize }
        x += cellSize
    }

    var best = legacyCentroid(polygon)
    let boundsCell = LegacyCell(x: minX + width / 2, y: minY + height / 2, half: 0, polygon: polygon)
    if boundsCell.distance > best.distance { best = boundsCell }

    let precision = max(cellSize / 100, 0.5)
    var iterations = 0
    while let index = cells.indices.max(by: { cells[$0].maximum < cells[$1].maximum }), iterations < 12_000 {
        let cell = cells.remove(at: index)
        if cell.distance > best.distance { best = cell }
        if cell.maximum - best.distance <= precision { iterations += 1; continue }
        let nh = cell.half / 2
        cells.append(LegacyCell(x: cell.x - nh, y: cell.y - nh, half: nh, polygon: polygon))
        cells.append(LegacyCell(x: cell.x + nh, y: cell.y - nh, half: nh, polygon: polygon))
        cells.append(LegacyCell(x: cell.x - nh, y: cell.y + nh, half: nh, polygon: polygon))
        cells.append(LegacyCell(x: cell.x + nh, y: cell.y + nh, half: nh, polygon: polygon))
        iterations += 1
    }
    return (best.x, best.y)
}

func legacyCentroid(_ polygon: [P]) -> LegacyCell {
    var area = 0.0, x = 0.0, y = 0.0
    for i in polygon.indices {
        let n = polygon[(i + 1) % polygon.count]
        let f = polygon[i].x * n.y - n.x * polygon[i].y
        x += (polygon[i].x + n.x) * f; y += (polygon[i].y + n.y) * f; area += f
    }
    guard abs(area) > .ulpOfOne else { return LegacyCell(x: polygon[0].x, y: polygon[0].y, half: 0, polygon: polygon) }
    return LegacyCell(x: x / (3 * area), y: y / (3 * area), half: 0, polygon: polygon)
}

func runPolylabelGolden(check: (String, Bool, String) -> Void) {
    // Polígonos variados: convexo, cóncavo en L, muy alargado, y uno pseudoaleatorio.
    var shapes: [(String, [P])] = [
        ("cuadrado", [P(x: 0, y: 0), P(x: 1000, y: 0), P(x: 1000, y: 1000), P(x: 0, y: 1000)]),
        ("L cóncava", [P(x: 0, y: 0), P(x: 1000, y: 0), P(x: 1000, y: 400), P(x: 400, y: 400), P(x: 400, y: 1000), P(x: 0, y: 1000)]),
        ("alargado", [P(x: 0, y: 0), P(x: 4000, y: 0), P(x: 4000, y: 300), P(x: 0, y: 300)]),
        ("dentado", [P(x: 0, y: 0), P(x: 500, y: 200), P(x: 1000, y: 0), P(x: 900, y: 600), P(x: 1000, y: 1200), P(x: 500, y: 900), P(x: 0, y: 1200), P(x: 100, y: 600)])
    ]
    var seed: UInt64 = 12345
    func rnd() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 11) / Double(UInt64(1) << 53)
    }
    for k in 0..<6 {
        let n = 6 + k * 3
        var pts: [P] = []
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi
            let r = 400 + rnd() * 600
            pts.append(P(x: 2000 + cos(a) * r, y: 2000 + sin(a) * r))
        }
        shapes.append(("aleatorio-\(k)", pts))
    }

    for (name, shape) in shapes {
        guard let legacy = legacyPolylabel(shape),
              let modern = TerritoryMapGeometryPreprocessor.polylabel(shape, isCancelled: { false }) else {
            check("polylabel \(name)", false, "una de las dos devolvió nil"); continue
        }
        // Comparar coordenadas exactas es engañoso: en polígonos simétricos hay varios
        // óptimos equivalentes y `max(by:)` (que se queda con el primero de los empatados)
        // y el heap (que saca uno cualquiera) eligen espejos distintos. Lo que importa es
        // la métrica que el algoritmo maximiza: la distancia al borde.
        let legacyDistance = signedDistance(from: P(x: legacy.0, y: legacy.1), to: shape)
        let modernDistance = signedDistance(from: modern.point, to: shape)
        let span = max(shape.map(\.x).max()! - shape.map(\.x).min()!, shape.map(\.y).max()! - shape.map(\.y).min()!)
        let tolerance = max(span / 100, 0.5) * 2
        check("polylabel \(name) misma calidad", abs(legacyDistance - modernDistance) <= tolerance,
              "original=\(legacyDistance) nuevo=\(modernDistance)")

        // Invariante real: el punto tiene que caer DENTRO del polígono.
        check("polylabel \(name) dentro del polígono", signedDistance(from: modern.point, to: shape) > 0, "")
    }
}
