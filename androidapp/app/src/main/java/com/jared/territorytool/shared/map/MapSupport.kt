package com.jared.territorytool.shared.map

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.jared.territorytool.shared.models.TerritoryMapBounds
import com.jared.territorytool.shared.models.TerritoryMapCoordinate
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import org.maplibre.geojson.Polygon
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt
import kotlin.math.tan

/** Estilos vectoriales de OpenFreeMap (sin clave de API). */
object MapStyles {
    fun url(dark: Boolean) = if (dark) "https://tiles.openfreemap.org/styles/dark" else "https://tiles.openfreemap.org/styles/liberty"
}

/** Proyección Web Mercator en metros (plano de `MKMapPoint`). */
object Mercator {
    private const val R = 6378137.0
    fun x(lon: Double) = R * lon * PI / 180
    fun y(lat: Double) = R * ln(tan(PI / 4 + lat * PI / 360))
    fun lon(x: Double) = x / R * 180 / PI
    fun lat(y: Double) = (2 * atan(exp(y / R)) - PI / 2) * 180 / PI

    /** Metros reales por metro proyectado a una latitud. */
    fun scale(lat: Double) = cos(lat * PI / 180)
}

/**
 * Redondea ligeramente las esquinas con un radio fijo pequeño (tipo "fillet"), en el
 * plano proyectado. Mismo algoritmo que la versión de iOS.
 */
fun List<TerritoryMapCoordinate>.roundedCorners(
    radiusFraction: Double = 0.16,
    segments: Int = 5,
    closed: Boolean = true,
): List<TerritoryMapCoordinate> {
    val points = map { doubleArrayOf(Mercator.x(it.longitude), Mercator.y(it.latitude)) }.toMutableList()
    if (closed && points.size > 1 && points.first()[0] == points.last()[0] && points.first()[1] == points.last()[1]) {
        points.removeAt(points.lastIndex)
    }
    val n = points.size
    if (n < 3) return this
    val spanX = points.maxOf { it[0] } - points.minOf { it[0] }
    val spanY = points.maxOf { it[1] } - points.minOf { it[1] }
    val radius = min(spanX, spanY) * radiusFraction
    if (radius <= 0) return this

    val result = mutableListOf<DoubleArray>()
    if (!closed) result += points[0]
    val range = if (closed) 0 until n else 1 until n - 1
    for (i in range) {
        val prev = points[(i - 1 + n) % n]
        val curr = points[i]
        val next = points[(i + 1) % n]
        val tpx = prev[0] - curr[0]; val tpy = prev[1] - curr[1]
        val tnx = next[0] - curr[0]; val tny = next[1] - curr[1]
        val lp = sqrt(tpx * tpx + tpy * tpy); val ln2 = sqrt(tnx * tnx + tny * tny)
        if (lp <= 0 || ln2 <= 0) { result += curr; continue }
        val d = min(radius, min(lp * 0.5, ln2 * 0.5))
        val ax = curr[0] + tpx / lp * d; val ay = curr[1] + tpy / lp * d
        val bx = curr[0] + tnx / ln2 * d; val by = curr[1] + tny / ln2 * d
        for (s in 0..segments) {
            val t = s.toDouble() / segments
            val mt = 1 - t
            val w0 = mt * mt; val w1 = 2 * mt * t; val w2 = t * t
            result += doubleArrayOf(w0 * ax + w1 * curr[0] + w2 * bx, w0 * ay + w1 * curr[1] + w2 * by)
        }
    }
    if (!closed) result += points[n - 1]
    return result.map { TerritoryMapCoordinate(Mercator.lat(it[1]), Mercator.lon(it[0])) }
}

// MARK: - GeoJSON

private fun List<TerritoryMapCoordinate>.points() = map { Point.fromLngLat(it.longitude, it.latitude) }

fun TerritoryMapGeometry.polygonFeatures(smooth: Boolean): FeatureCollection = FeatureCollection.fromFeatures(
    polygons.mapNotNull { p ->
        val coords = (if (smooth) p.coordinates.roundedCorners() else p.coordinates).points()
        if (coords.size < 3) return@mapNotNull null
        val ring = if (coords.first() == coords.last()) coords else coords + coords.first()
        Feature.fromGeometry(Polygon.fromLngLats(listOf(ring)))
    },
)

fun TerritoryMapGeometry.lineFeatures(smooth: Boolean): FeatureCollection = FeatureCollection.fromFeatures(
    polylines.mapNotNull { l ->
        val coords = (if (smooth) l.coordinates.roundedCorners(closed = false) else l.coordinates).points()
        if (coords.size < 2) null else Feature.fromGeometry(LineString.fromLngLats(coords))
    },
)

fun TerritoryMapGeometry.markerFeatures(): FeatureCollection = FeatureCollection.fromFeatures(
    markers.map { m ->
        Feature.fromGeometry(Point.fromLngLat(m.longitude, m.latitude)).apply {
            addStringProperty("title", m.title ?: "")
        }
    },
)

/** Colores ARGB resueltos para dibujar sobre el mapa. */
data class TerritoryMapColors(val stroke: Color, val fill: Color, val marker: Color)

/**
 * Añade el territorio (relleno, contorno, polilíneas y marcadores) al estilo. Lo usan tanto
 * el mapa interactivo como los snapshots, para que ambos dibujen exactamente lo mismo.
 */
fun Style.Builder.withTerritory(
    geometry: TerritoryMapGeometry,
    colors: TerritoryMapColors,
    lineWidth: Float,
    fillOpacity: Float = 0.16f,
    smooth: Boolean = true,
    markers: MarkerStyle = MarkerStyle.None,
    prefix: String = "territory",
): Style.Builder {
    withSource(GeoJsonSource("$prefix-polygons", geometry.polygonFeatures(smooth)))
    withSource(GeoJsonSource("$prefix-lines", geometry.lineFeatures(smooth)))
    withLayer(
        FillLayer("$prefix-fill", "$prefix-polygons").withProperties(
            PropertyFactory.fillColor(colors.fill.toArgb()),
            PropertyFactory.fillOpacity(fillOpacity),
        ),
    )
    withLayer(
        LineLayer("$prefix-outline", "$prefix-polygons").withProperties(
            PropertyFactory.lineColor(colors.stroke.toArgb()),
            PropertyFactory.lineWidth(lineWidth),
            PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
            PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
        ),
    )
    withLayer(
        LineLayer("$prefix-polylines", "$prefix-lines").withProperties(
            PropertyFactory.lineColor(colors.stroke.toArgb()),
            PropertyFactory.lineOpacity(0.85f),
            PropertyFactory.lineWidth(lineWidth),
            PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
            PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
        ),
    )
    if (markers != MarkerStyle.None && geometry.markers.isNotEmpty()) {
        withSource(GeoJsonSource("$prefix-markers", geometry.markerFeatures()))
        withLayer(
            CircleLayer("$prefix-marker-dots", "$prefix-markers").withProperties(
                PropertyFactory.circleColor(colors.marker.toArgb()),
                PropertyFactory.circleRadius(if (markers == MarkerStyle.Dots) 3.5f else 7f),
                PropertyFactory.circleStrokeColor(android.graphics.Color.WHITE),
                PropertyFactory.circleStrokeWidth(if (markers == MarkerStyle.Dots) 1f else 2f),
            ),
        )
        if (markers == MarkerStyle.Labeled) {
            withLayer(
                SymbolLayer("$prefix-marker-labels", "$prefix-markers").withProperties(
                    PropertyFactory.textField(Expression.get("title")),
                    PropertyFactory.textSize(12f),
                    PropertyFactory.textOffset(arrayOf(0f, 1.4f)),
                    PropertyFactory.textColor(colors.stroke.toArgb()),
                    PropertyFactory.textHaloColor(android.graphics.Color.WHITE),
                    PropertyFactory.textHaloWidth(1.5f),
                    PropertyFactory.textAllowOverlap(false),
                ),
            )
        }
    }
    return this
}

enum class MarkerStyle { None, Dots, Labeled }

// MARK: - Cámara

/**
 * Convierte la cámara de iOS (centro + distancia en metros) a zoom de MapLibre para un
 * contenedor de `widthDp` de ancho. La distancia de MapKit equivale a un ancho visible
 * de ≈ distancia·2·tan(15°).
 */
fun zoomFor(distanceMeters: Double, latitude: Double, widthDp: Float): Double {
    val visibleMeters = max(distanceMeters * 0.536, 1.0)
    val worldMeters = 40075016.686 * cos(latitude * PI / 180)
    return log2(worldMeters * widthDp / (512.0 * visibleMeters)).coerceIn(1.0, 20.0)
}

/** Huella del bounding box en metros reales. */
fun TerritoryMapBounds.footprintMeters(): Double {
    val dx = abs(Mercator.x(east) - Mercator.x(west))
    val dy = abs(Mercator.y(north) - Mercator.y(south))
    return max(dx, dy) * Mercator.scale((north + south) / 2)
}

/** Cámara del mapa del detalle (centrado, inclinado). */
fun TerritoryMapGeometry.cameraPosition(compact: Boolean, widthDp: Float): CameraPosition {
    val cx = (Mercator.x(bounds.west) + Mercator.x(bounds.east)) / 2
    val cy = (Mercator.y(bounds.north) + Mercator.y(bounds.south)) / 2
    val center = LatLng(Mercator.lat(cy), Mercator.lon(cx))
    val footprint = max(bounds.footprintMeters(), 100.0 * Mercator.scale(center.latitude))
    val distance = max(footprint * (if (compact) 2.1 else 1.75), if (compact) 180.0 else 140.0)
    return CameraPosition.Builder()
        .target(center)
        .zoom(zoomFor(distance, center.latitude, widthDp))
        .tilt(if (compact) 48.0 else 55.0)
        .bearing(0.0)
        .build()
}

/** Cámara de los snapshots de tarjetas: el territorio a la derecha o centrado. */
fun TerritoryMapGeometry.backdropCamera(
    widthDp: Float,
    centersTerritory: Boolean,
    verticalBias: Double,
    distanceMultiplier: Double?,
    horizontalShift: Double?,
): CameraPosition {
    val latSpan = bounds.north - bounds.south
    val lonSpan = bounds.east - bounds.west
    val centerLat = (bounds.north + bounds.south) / 2 - latSpan * verticalBias
    val shift = horizontalShift ?: if (centersTerritory) 0.0 else 0.5
    val multiplier = distanceMultiplier ?: if (centersTerritory) 2.0 else 2.4
    val center = LatLng(centerLat, (bounds.east + bounds.west) / 2 - lonSpan * shift)
    val distance = max(bounds.footprintMeters() * multiplier, if (centersTerritory) 180.0 else 260.0)
    return CameraPosition.Builder()
        .target(center)
        .zoom(zoomFor(distance, centerLat, widthDp))
        .tilt(if (centersTerritory) 48.0 else 45.0)
        .bearing(0.0)
        .build()
}
