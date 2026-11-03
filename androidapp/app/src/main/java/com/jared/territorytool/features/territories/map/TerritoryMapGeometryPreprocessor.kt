package com.jared.territorytool.features.territories.map

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Preprocesado geométrico del explorador de mapa (fuera del hilo principal): ajusta las
 * fronteras entre territorios vecinos y calcula el punto interior de cada etiqueta.
 * Trabaja en coordenadas Web Mercator (metros proyectados). Port directo de iOS.
 */
object TerritoryMapGeometryPreprocessor {

    data class Point(val x: Double, val y: Double)

    data class Rect(val minX: Double, val minY: Double, val maxX: Double, val maxY: Double) {
        fun intersects(o: Rect) = minX <= o.maxX && maxX >= o.minX && minY <= o.maxY && maxY >= o.minY
        fun expanded(by: Double) = Rect(minX - by, minY - by, maxX + by, maxY + by)
        fun contains(p: Point) = p.x in minX..maxX && p.y in minY..maxY

        companion object {
            fun bounding(points: List<Point>): Rect {
                if (points.isEmpty()) return Rect(0.0, 0.0, 0.0, 0.0)
                var r = Rect(points[0].x, points[0].y, points[0].x, points[0].y)
                for (p in points) r = Rect(min(r.minX, p.x), min(r.minY, p.y), max(r.maxX, p.x), max(r.maxY, p.y))
                return r
            }
        }
    }

    data class Feature(val territoryId: Int, val id: String, val points: List<Point>) {
        val isClosed: Boolean
            get() {
                val f = points.firstOrNull() ?: return false
                val l = points.last()
                return abs(f.x - l.x) < 0.001 && abs(f.y - l.y) < 0.001
            }
    }

    data class LabelPlacement(val point: Point, val polygon: List<Point>, val bounds: Rect)

    data class Output(
        val polygonsByTerritory: Map<Int, List<Feature>>,
        val polylinesByTerritory: Map<Int, List<Feature>>,
        val labelPlacements: Map<Int, LabelPlacement>,
    )

    fun process(polygons: List<Feature>, polylines: List<Feature>, isCancelled: () -> Boolean): Output? {
        val bounds = polygons.map { Rect.bounding(it.points) }
        val grid = SpatialGrid(bounds)
        val polygonsByTerritory = mutableMapOf<Int, MutableList<Feature>>()
        for ((index, polygon) in polygons.withIndex()) {
            if (isCancelled()) return null
            val adjusted = adjustedPoints(polygon, index, polygons, bounds, grid, isCancelled) ?: return null
            polygonsByTerritory.getOrPut(polygon.territoryId) { mutableListOf() } += polygon.copy(points = adjusted)
        }
        val polylinesByTerritory = polylines.groupBy { it.territoryId }

        // Una etiqueta por territorio, en su polígono de mayor área.
        val largest = mutableMapOf<Int, Pair<List<Point>, Double>>()
        for (polygon in polygons) {
            if (polygon.points.size < 3) continue
            if (isCancelled()) return null
            val area = abs(projectedArea(polygon.points))
            val existing = largest[polygon.territoryId]
            if (existing != null && existing.second >= area) continue
            largest[polygon.territoryId] = polygon.points to area
        }
        val placements = mutableMapOf<Int, LabelPlacement>()
        for ((id, candidate) in largest) {
            if (isCancelled()) return null
            polylabel(candidate.first, isCancelled = isCancelled)?.let { placements[id] = it }
        }
        return Output(polygonsByTerritory, polylinesByTerritory, placements)
    }

    /**
     * Cuando un vértice cae dentro de otro territorio, se mueve a medio camino hacia el
     * borde del vecino: dos fronteras casi paralelas convergen a la línea media.
     */
    private fun adjustedPoints(
        polygon: Feature,
        index: Int,
        polygons: List<Feature>,
        bounds: List<Rect>,
        grid: SpatialGrid,
        isCancelled: () -> Boolean,
    ): List<Point>? {
        if (polygons.size <= 1) return polygon.points
        val result = polygon.points.toMutableList()
        val closed = polygon.isClosed
        val lastIndex = result.lastIndex
        for (i in result.indices) {
            if (isCancelled()) return null
            if (closed && i == lastIndex) continue
            result[i] = adjustedPoint(result[i], index, polygons, bounds, grid)
        }
        if (closed && result.isNotEmpty()) result[lastIndex] = result[0]
        return result
    }

    private fun adjustedPoint(point: Point, ownerIndex: Int, polygons: List<Feature>, bounds: List<Rect>, grid: SpatialGrid): Point {
        var nearest: Pair<Point, Double>? = null
        val owner = polygons[ownerIndex].territoryId
        for (ci in grid.candidates(point)) {
            val candidate = polygons[ci]
            if (candidate.territoryId == owner) continue
            if (!bounds[ci].expanded(1.0).contains(point)) continue
            if (signedDistance(point, candidate.points) <= 0) continue
            val boundary = closestBoundaryPoint(point, candidate.points) ?: continue
            if (nearest == null || boundary.second < nearest.second) nearest = boundary
        }
        val n = nearest ?: return point
        return Point((point.x + n.first.x) / 2, (point.y + n.first.y) / 2)
    }

    // MARK: - Polylabel

    private class Cell(val x: Double, val y: Double, val half: Double, polygon: List<Point>) {
        val distance = signedDistance(Point(x, y), polygon)
        val maximum = distance + half * sqrt(2.0)
    }

    /** Punto interior más alejado del borde, para colocar la etiqueta. */
    fun polylabel(polygon: List<Point>, precisionFactor: Double = 100.0, isCancelled: () -> Boolean = { false }): LabelPlacement? {
        val rect = Rect.bounding(polygon)
        val width = rect.maxX - rect.minX
        val height = rect.maxY - rect.minY
        val cellSize = min(width, height)
        if (cellSize <= 0) return null

        val heap = java.util.PriorityQueue<Cell>(compareByDescending { it.maximum })
        val half = cellSize / 2
        var x = rect.minX
        while (x < rect.maxX) {
            var y = rect.minY
            while (y < rect.maxY) {
                heap.add(Cell(x + half, y + half, half, polygon))
                y += cellSize
            }
            x += cellSize
        }

        var best = centroidCell(polygon)
        val boundsCell = Cell(rect.minX + width / 2, rect.minY + height / 2, 0.0, polygon)
        if (boundsCell.distance > best.distance) best = boundsCell
        val precision = max(cellSize / precisionFactor, 0.5)
        var iterations = 0
        while (heap.isNotEmpty() && iterations < 12_000) {
            val cell = heap.poll()!!
            iterations++
            if (iterations % 256 == 0 && isCancelled()) return null
            if (cell.distance > best.distance) best = cell
            if (cell.maximum - best.distance <= precision) continue
            val h = cell.half / 2
            heap.add(Cell(cell.x - h, cell.y - h, h, polygon))
            heap.add(Cell(cell.x + h, cell.y - h, h, polygon))
            heap.add(Cell(cell.x - h, cell.y + h, h, polygon))
            heap.add(Cell(cell.x + h, cell.y + h, h, polygon))
        }
        return LabelPlacement(Point(best.x, best.y), polygon, rect)
    }

    private fun centroidCell(polygon: List<Point>): Cell {
        var area = 0.0; var x = 0.0; var y = 0.0
        for (i in polygon.indices) {
            val a = polygon[i]; val b = polygon[(i + 1) % polygon.size]
            val f = a.x * b.y - b.x * a.y
            x += (a.x + b.x) * f
            y += (a.y + b.y) * f
            area += f
        }
        if (abs(area) <= Math.ulp(1.0)) return Cell(polygon[0].x, polygon[0].y, 0.0, polygon)
        return Cell(x / (3 * area), y / (3 * area), 0.0, polygon)
    }

    // MARK: - Rejilla espacial

    private class SpatialGrid(bounds: List<Rect>) {
        private val buckets = HashMap<Long, MutableList<Int>>()
        private val cellSize: Double = max(
            if (bounds.isEmpty()) 1.0 else bounds.sumOf { max(it.maxX - it.minX, it.maxY - it.minY) } / bounds.size,
            1.0,
        )

        init {
            bounds.forEachIndexed { index, b ->
                val r = b.expanded(1.0)
                for (gx in cell(r.minX)..cell(r.maxX)) for (gy in cell(r.minY)..cell(r.maxY)) {
                    buckets.getOrPut(key(gx, gy)) { mutableListOf() } += index
                }
            }
        }

        private fun cell(v: Double) = floor(v / cellSize).toInt()
        private fun key(x: Int, y: Int) = (x.toLong() shl 32) or (y.toLong() and 0xffffffffL)
        fun candidates(p: Point): List<Int> = buckets[key(cell(p.x), cell(p.y))] ?: emptyList()
    }
}

/** Positiva dentro del polígono, negativa fuera; el valor absoluto es la distancia al borde. */
fun signedDistance(point: TerritoryMapGeometryPreprocessor.Point, polygon: List<TerritoryMapGeometryPreprocessor.Point>): Double {
    var inside = false
    var minSq = Double.MAX_VALUE
    var prev = polygon.size - 1
    for (cur in polygon.indices) {
        val a = polygon[cur]; val b = polygon[prev]
        if ((a.y > point.y) != (b.y > point.y) && point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) inside = !inside
        minSq = min(minSq, squaredSegmentDistance(point, a, b))
        prev = cur
    }
    val d = sqrt(minSq)
    return if (inside) d else -d
}

fun projectedArea(points: List<TerritoryMapGeometryPreprocessor.Point>): Double {
    var area = 0.0
    for (i in points.indices) {
        val n = points[(i + 1) % points.size]
        area += points[i].x * n.y - n.x * points[i].y
    }
    return area / 2
}

private fun squaredSegmentDistance(p: TerritoryMapGeometryPreprocessor.Point, s: TerritoryMapGeometryPreprocessor.Point, e: TerritoryMapGeometryPreprocessor.Point): Double {
    var x = s.x; var y = s.y
    val dx = e.x - x; val dy = e.y - y
    if (dx != 0.0 || dy != 0.0) {
        val t = ((p.x - x) * dx + (p.y - y) * dy) / (dx * dx + dy * dy)
        if (t > 1) { x = e.x; y = e.y } else if (t > 0) { x += dx * t; y += dy * t }
    }
    val px = p.x - x; val py = p.y - y
    return px * px + py * py
}

fun closestBoundaryPoint(
    point: TerritoryMapGeometryPreprocessor.Point,
    polygon: List<TerritoryMapGeometryPreprocessor.Point>,
): Pair<TerritoryMapGeometryPreprocessor.Point, Double>? {
    if (polygon.size <= 1) return null
    var closest: Pair<TerritoryMapGeometryPreprocessor.Point, Double>? = null
    var prev = polygon.size - 1
    for (cur in polygon.indices) {
        val s = polygon[cur]; val e = polygon[prev]
        val dx = e.x - s.x; val dy = e.y - s.y
        val c = if (dx == 0.0 && dy == 0.0) s else {
            val t = (((point.x - s.x) * dx + (point.y - s.y) * dy) / (dx * dx + dy * dy)).coerceIn(0.0, 1.0)
            TerritoryMapGeometryPreprocessor.Point(s.x + dx * t, s.y + dy * t)
        }
        val d = (point.x - c.x) * (point.x - c.x) + (point.y - c.y) * (point.y - c.y)
        if (closest == null || d < closest.second) closest = c to d
        prev = cur
    }
    return closest
}
