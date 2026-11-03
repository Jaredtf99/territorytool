package com.jared.territorytool.features.territories.map

import android.graphics.Paint
import android.graphics.Typeface
import androidx.core.content.res.ResourcesCompat
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CloseFullscreen
import androidx.compose.material.icons.rounded.LocationDisabled
import androidx.compose.material.icons.rounded.LocationSearching
import androidx.compose.material.icons.rounded.MyLocation
import androidx.compose.material.icons.rounded.OpenInFull
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.features.territories.TerritoriesViewModel
import com.jared.territorytool.features.territories.TerritoryDrawerDetent
import com.jared.territorytool.features.territories.TerritoryLocationService
import com.jared.territorytool.shared.components.openAppSettings
import com.jared.territorytool.shared.map.LiveMapView
import com.jared.territorytool.shared.map.MapStyles
import com.jared.territorytool.shared.map.Mercator
import com.jared.territorytool.shared.map.zoomFor
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryOperationalStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
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
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max

private typealias P = TerritoryMapGeometryPreprocessor.Point

private data class LabelPlacement(
    val coordinate: LatLng,
    val polygon: List<P>,
    val bounds: TerritoryMapGeometryPreprocessor.Rect,
    val textWidthDp: Float,
    val textHeightDp: Float,
)

private data class PreparedGeometry(val polygons: List<List<LatLng>>, val polylines: List<List<LatLng>>, val projected: List<List<P>>)

private const val MAP_PITCH = 38.0

@Composable
fun TerritoriesExplorerMap(
    viewModel: TerritoriesViewModel,
    location: TerritoryLocationService,
    topInset: Dp,
    isFullscreen: Boolean,
    onToggleFullscreen: () -> Unit,
    onAssign: (Territory) -> Unit,
    onReturn: (Territory) -> Unit,
) {
    val context = LocalContext.current
    val colors = AppTheme.colors
    val density = LocalDensity.current
    val keyboard = LocalSoftwareKeyboardController.current
    val focus = LocalFocusManager.current
    val derived by viewModel.derived.collectAsStateWithLifecycle()
    val selectedId by viewModel.selectedTerritoryId.collectAsStateWithLifecycle()
    val detent by viewModel.drawerDetent.collectAsStateWithLifecycle()
    val currentLocation by location.location.collectAsStateWithLifecycle()
    val denied by location.isDenied.collectAsStateWithLifecycle()

    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var style by remember { mutableStateOf<Style?>(null) }
    var prepared by remember { mutableStateOf<Map<Int, PreparedGeometry>>(emptyMap()) }
    var placements by remember { mutableStateOf<Map<Int, LabelPlacement>>(emptyMap()) }
    var didFitInitial by remember { mutableStateOf(false) }
    var programmaticMove by remember { mutableStateOf(false) }

    val territories = derived.withGeometry
    val currentTerritories by rememberUpdatedState(territories)
    val currentPrepared by rememberUpdatedState(prepared)
    val currentSelected by rememberUpdatedState(selectedId)

    fun statusColor(t: Territory): Color = when (viewModel.status(t)) {
        TerritoryOperationalStatus.Available -> colors.accent
        is TerritoryOperationalStatus.Assigned -> colors.accentSecondary
        is TerritoryOperationalStatus.Attention -> colors.accentTertiary
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val widthDp = maxWidth.value
        val bottomInset = LocalTabBarPadding.current
        val mediumHeight = (maxHeight * 0.50f).coerceIn(360.dp + bottomInset, 440.dp + bottomInset)
        val collapsedHeight = if (selectedId != null) 30.dp + 132.dp + bottomInset + 6.dp else 168.dp + bottomInset
        val drawerHeight = if (detent == TerritoryDrawerDetent.Collapsed) collapsedHeight else mediumHeight
        val currentDrawerHeight by rememberUpdatedState(drawerHeight)
        val currentTopInset by rememberUpdatedState(topInset)

        fun moveTo(update: org.maplibre.android.camera.CameraUpdate, animated: Boolean) {
            val m = map ?: return
            programmaticMove = true
            if (animated) m.animateCamera(update, 400) else m.moveCamera(update)
        }

        /** Encuadra el territorio centrado en la franja visible (entre controles y drawer). */
        fun focusOn(territory: Territory, animated: Boolean, occlude: Boolean) {
            val m = map ?: return
            val b = territory.mapGeometry?.bounds ?: return
            val w = abs(Mercator.x(b.east) - Mercator.x(b.west))
            val h = abs(Mercator.y(b.north) - Mercator.y(b.south))
            val dx = max(w * 1.5, 800.0); val dy = max(h * 1.5, 800.0)
            val bounds = LatLngBounds.from(
                Mercator.lat(Mercator.y(b.north) + dy), Mercator.lon(Mercator.x(b.east) + dx),
                Mercator.lat(Mercator.y(b.south) - dy), Mercator.lon(Mercator.x(b.west) - dx),
            )
            val top = if (occlude) with(density) { currentTopInset.roundToPx() } else 0
            val bottom = if (occlude) with(density) { currentDrawerHeight.roundToPx() } else 0
            val camera = m.getCameraForLatLngBounds(bounds, intArrayOf(0, top, 0, bottom), 0.0, MAP_PITCH) ?: return
            moveTo(CameraUpdateFactory.newCameraPosition(camera), animated)
        }

        fun focusOnPrimary(animated: Boolean) {
            val first = currentTerritories.firstOrNull() ?: return
            focusOn(first, animated, occlude = false)
            didFitInitial = true
        }

        fun moveToUser() {
            val loc = location.location.value ?: return
            moveTo(
                CameraUpdateFactory.newCameraPosition(
                    CameraPosition.Builder().target(LatLng(loc.latitude, loc.longitude)).zoom(zoomFor(2400.0, loc.latitude, widthDp)).tilt(MAP_PITCH).build(),
                ),
                animated = true,
            )
        }

        fun territoryAt(point: LatLng): Territory? {
            val p = P(Mercator.x(point.longitude), Mercator.y(point.latitude))
            return currentTerritories.firstOrNull { t ->
                val polys = currentPrepared[t.id]?.projected
                    ?: t.mapGeometry?.polygons?.map { poly -> poly.coordinates.map { P(Mercator.x(it.longitude), Mercator.y(it.latitude)) } }
                    ?: emptyList()
                polys.any { it.size > 2 && signedDistance(p, it) > 0 }
            }
        }

        /** Sólo etiquetas cuya caja de texto cabe dentro del polígono a la escala actual. */
        fun refreshLabels() {
            val m = map ?: return
            val s = style ?: return
            val source = s.getSourceAs<GeoJsonSource>("explorer-labels") ?: return
            val zoom = m.cameraPosition.zoom
            val visible = m.projection.visibleRegion.latLngBounds
            val features = currentTerritories.mapNotNull { t ->
                val placement = placements[t.id] ?: return@mapNotNull null
                val lat = placement.coordinate.latitude
                // Metros proyectados por dp a este zoom (MapLibre usa teselas de 512).
                val metersPerDp = 40075016.686 / (512.0 * Math.pow(2.0, zoom))
                val selScale = if (currentSelected == t.id) 1.08 else 1.0
                val halfW = ((placement.textWidthDp / 2) + 2) * selScale * metersPerDp
                val halfH = ((placement.textHeightDp / 2) + 2) * selScale * metersPerDp
                if (!visible.contains(placement.coordinate)) {
                    val lb = placement.bounds
                    val vb = TerritoryMapGeometryPreprocessor.Rect(
                        Mercator.x(visible.longitudeWest), Mercator.y(visible.latitudeSouth), Mercator.x(visible.longitudeEast), Mercator.y(visible.latitudeNorth),
                    )
                    if (!vb.expanded((vb.maxX - vb.minX) * 0.08).intersects(lb)) return@mapNotNull null
                }
                val cx = Mercator.x(placement.coordinate.longitude); val cy = Mercator.y(lat)
                val samples = listOf(-1, 0, 1).flatMap { sx -> listOf(-1, 0, 1).map { sy -> P(cx + sx * halfW, cy + sy * halfH) } }
                val tolerance = max(halfW, halfH) * 0.08
                if (samples.all { signedDistance(it, placement.polygon) >= -tolerance }) {
                    Feature.fromGeometry(Point.fromLngLat(placement.coordinate.longitude, lat)).apply {
                        addStringProperty("name", t.name)
                        addBooleanProperty("selected", currentSelected == t.id)
                        addStringProperty("halo", statusColor(t).copy(alpha = if (currentSelected == t.id) 0.45f else 0.18f).let { "#%08X".format(it.toArgb()) })
                    }
                } else null
            }
            source.setGeoJson(FeatureCollection.fromFeatures(features))
        }

        LiveMapView(
            modifier = Modifier.fillMaxSize(),
            styleKey = colors.isDark,
            styleBuilder = {
                Style.Builder().fromUri(MapStyles.url(colors.isDark))
                    .withSource(GeoJsonSource("explorer-polygons"))
                    .withSource(GeoJsonSource("explorer-lines"))
                    .withSource(GeoJsonSource("explorer-labels"))
                    .withSource(GeoJsonSource("explorer-location"))
                    .withLayer(
                        FillLayer("explorer-fill", "explorer-polygons").withProperties(
                            PropertyFactory.fillColor(Expression.get("color")),
                            PropertyFactory.fillOpacity(Expression.get("fillOpacity")),
                        ),
                    )
                    .withLayer(
                        LineLayer("explorer-outline", "explorer-polygons").withProperties(
                            PropertyFactory.lineColor(Expression.get("color")),
                            PropertyFactory.lineOpacity(Expression.get("lineOpacity")),
                            PropertyFactory.lineWidth(Expression.get("lineWidth")),
                            PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
                        ),
                    )
                    .withLayer(
                        LineLayer("explorer-polylines", "explorer-lines").withProperties(
                            PropertyFactory.lineColor(Expression.get("color")),
                            PropertyFactory.lineOpacity(Expression.get("lineOpacity")),
                            PropertyFactory.lineWidth(Expression.get("lineWidth")),
                            PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                        ),
                    )
                    .withLayer(
                        SymbolLayer("explorer-label-layer", "explorer-labels").withProperties(
                            PropertyFactory.textField(Expression.get("name")),
                            PropertyFactory.textFont(arrayOf("Noto Sans Bold")),
                            PropertyFactory.textSize(Expression.switchCase(Expression.get("selected"), Expression.literal(16.2f), Expression.literal(15f))),
                            PropertyFactory.textMaxWidth(7.5f),
                            PropertyFactory.textColor(colors.textPrimary.toArgb()),
                            PropertyFactory.textHaloColor(android.graphics.Color.argb(242, 255, 255, 255)),
                            PropertyFactory.textHaloWidth(1.4f),
                            PropertyFactory.textAllowOverlap(true),
                            PropertyFactory.textIgnorePlacement(true),
                        ),
                    )
                    .withLayer(
                        CircleLayer("explorer-location-dot", "explorer-location").withProperties(
                            PropertyFactory.circleColor(colors.info.toArgb()),
                            PropertyFactory.circleRadius(9f),
                            PropertyFactory.circleStrokeColor(android.graphics.Color.WHITE),
                            PropertyFactory.circleStrokeWidth(3f),
                        ),
                    )
            },
            camera = null,
            interactive = true,
            onMap = { m, s ->
                val firstTime = map == null
                map = m
                style = s
                if (!firstTime) return@LiveMapView
                m.uiSettings.isRotateGesturesEnabled = true
                m.addOnMapClickListener { latLng ->
                    keyboard?.hide(); focus.clearFocus()
                    val hit = territoryAt(latLng)
                    if (hit != null) {
                        HapticManager.impact(HapticManager.Impact.Light)
                        viewModel.select(hit)
                    } else {
                        // Toque en zona vacía: deselecciona y compacta el drawer.
                        if (viewModel.selectedTerritoryId.value != null) viewModel.select(null)
                        viewModel.drawerDetent.value = TerritoryDrawerDetent.Collapsed
                    }
                    true
                }
                m.addOnCameraMoveStartedListener { reason ->
                    // Gesto real del usuario: cierra teclado y compacta el drawer al empezar.
                    if (reason == MapLibreMap.OnCameraMoveStartedListener.REASON_API_GESTURE) {
                        keyboard?.hide(); focus.clearFocus()
                        if (viewModel.drawerDetent.value != TerritoryDrawerDetent.Collapsed) {
                            viewModel.drawerDetent.value = TerritoryDrawerDetent.Collapsed
                        }
                    }
                }
                m.addOnCameraIdleListener {
                    programmaticMove = false
                    refreshLabels()
                }
            },
        )

        // Preprocesado geométrico fuera del hilo principal, por conjunto de geometrías.
        LaunchedEffect(derived.geometryRevision) {
            val list = territories
            val typeface = ResourcesCompat.getFont(context, R.font.nunito)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = 15f
                this.typeface = Typeface.create(typeface, Typeface.BOLD)
            }
            val result = withContext(Dispatchers.Default) {
                val polygons = mutableListOf<TerritoryMapGeometryPreprocessor.Feature>()
                val polylines = mutableListOf<TerritoryMapGeometryPreprocessor.Feature>()
                for (t in list) {
                    val g = t.mapGeometry ?: continue
                    g.polygons.forEach { poly ->
                        val pts = poly.coordinates.map { P(Mercator.x(it.longitude), Mercator.y(it.latitude)) }
                        if (pts.size >= 3) polygons += TerritoryMapGeometryPreprocessor.Feature(t.id, poly.id, pts)
                    }
                    g.polylines.forEach { line ->
                        polylines += TerritoryMapGeometryPreprocessor.Feature(t.id, line.id, line.coordinates.map { P(Mercator.x(it.longitude), Mercator.y(it.latitude)) })
                    }
                }
                val output = TerritoryMapGeometryPreprocessor.process(polygons, polylines) { !isActive } ?: return@withContext null
                fun ll(p: P) = LatLng(Mercator.lat(p.y), Mercator.lon(p.x))
                val geometries = list.associate { t ->
                    val polys = output.polygonsByTerritory[t.id].orEmpty()
                    t.id to PreparedGeometry(
                        polys.map { f -> f.points.map(::ll) },
                        output.polylinesByTerritory[t.id].orEmpty().map { f -> f.points.map(::ll) },
                        polys.map { it.points },
                    )
                }
                val labels = output.labelPlacements.mapNotNull { (id, placement) ->
                    val name = list.firstOrNull { it.id == id }?.name ?: return@mapNotNull null
                    val raw = paint.measureText(name)
                    val lines = ceil(raw / 106f).coerceIn(1f, 3f)
                    id to LabelPlacement(ll(placement.point), placement.polygon, placement.bounds, minOf(raw, 106f), minOf(lines * 20f, 80f))
                }.toMap()
                geometries to labels
            } ?: return@LaunchedEffect
            prepared = result.first
            placements = result.second
        }

        // Pinta polígonos con estilo según estado/selección.
        LaunchedEffect(style, prepared, selectedId, derived) {
            val s = style ?: return@LaunchedEffect
            val polygonFeatures = mutableListOf<Feature>()
            val lineFeatures = mutableListOf<Feature>()
            for (t in territories) {
                val g = prepared[t.id] ?: continue
                val selected = selectedId == t.id
                val dimmed = selectedId != null && !selected
                val color = "#%06X".format(statusColor(t).toArgb() and 0xFFFFFF)
                val isAttention = viewModel.status(t) is TerritoryOperationalStatus.Attention
                g.polygons.forEach { ring ->
                    val pts = ring.map { Point.fromLngLat(it.longitude, it.latitude) }
                    if (pts.size < 3) return@forEach
                    val closed = if (pts.first() == pts.last()) pts else pts + pts.first()
                    polygonFeatures += Feature.fromGeometry(Polygon.fromLngLats(listOf(closed))).apply {
                        addStringProperty("color", color)
                        addNumberProperty("fillOpacity", if (selected) 0.58 else if (dimmed) 0.08 else 0.22)
                        addNumberProperty("lineOpacity", if (dimmed) 0.38 else 1.0)
                        addNumberProperty("lineWidth", if (selected) 5.0 else if (dimmed) 1.25 else if (isAttention) 3.0 else 2.0)
                    }
                }
                g.polylines.forEach { line ->
                    if (line.size < 2) return@forEach
                    lineFeatures += Feature.fromGeometry(LineString.fromLngLats(line.map { Point.fromLngLat(it.longitude, it.latitude) })).apply {
                        addStringProperty("color", color)
                        addNumberProperty("lineOpacity", if (dimmed) 0.35 else 1.0)
                        addNumberProperty("lineWidth", if (selected) 4.0 else 2.5)
                    }
                }
            }
            s.getSourceAs<GeoJsonSource>("explorer-polygons")?.setGeoJson(FeatureCollection.fromFeatures(polygonFeatures))
            s.getSourceAs<GeoJsonSource>("explorer-lines")?.setGeoJson(FeatureCollection.fromFeatures(lineFeatures))
            refreshLabels()
        }

        LaunchedEffect(placements, style) { refreshLabels() }

        // Sólo se encuadra en la primera carga; las búsquedas no mueven la cámara.
        LaunchedEffect(map, derived.geometryRevision) {
            if (map != null && !didFitInitial) focusOnPrimary(animated = didFitInitial)
        }

        LaunchedEffect(style, currentLocation) {
            val s = style ?: return@LaunchedEffect
            val loc = currentLocation
            s.getSourceAs<GeoJsonSource>("explorer-location")?.setGeoJson(
                FeatureCollection.fromFeatures(if (loc == null) emptyList() else listOf(Feature.fromGeometry(Point.fromLngLat(loc.longitude, loc.latitude)))),
            )
            if (loc != null) moveToUser()
        }

        Column(
            Modifier.align(Alignment.TopStart).padding(start = AppSpacing.md, top = topInset + AppSpacing.xs),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        ) {
            GlassIconButton(
                when {
                    denied -> Icons.Rounded.LocationDisabled
                    currentLocation == null -> Icons.Rounded.LocationSearching
                    else -> Icons.Rounded.MyLocation
                },
                stringResource(if (denied) R.string.territories_location_settings else R.string.territories_location_button),
                {
                    if (denied) context.openAppSettings() else location.requestLocation()
                    moveToUser()
                },
                tint = colors.accentDeep,
            )
            GlassIconButton(
                if (isFullscreen) Icons.Rounded.CloseFullscreen else Icons.Rounded.OpenInFull,
                stringResource(if (isFullscreen) R.string.territories_map_exit_fullscreen else R.string.territories_map_fullscreen),
                onToggleFullscreen,
                tint = colors.accentDeep,
            )
        }

        Box(Modifier.align(Alignment.BottomCenter).navigationBarsPadding()) {
            TerritoryMapDrawer(
                viewModel = viewModel,
                collapsedHeight = collapsedHeight,
                mediumHeight = mediumHeight,
                bottomInset = bottomInset,
                onSelect = { territory ->
                    viewModel.select(territory)
                    focusOn(territory, animated = true, occlude = true)
                },
                onAssign = onAssign,
                onReturn = onReturn,
            )
        }
    }
}
