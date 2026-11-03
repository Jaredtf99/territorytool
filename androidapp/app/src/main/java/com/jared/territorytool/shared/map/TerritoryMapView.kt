package com.jared.territorytool.shared.map

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.snapshotter.MapSnapshotter
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import kotlin.coroutines.resume

/**
 * Mapa en vivo de un territorio (equivale a `TerritoryMapView` con MapKit).
 * Por defecto es estático; `interactive` permite pan/zoom/rotación.
 */
@Composable
fun TerritoryMapView(
    geometry: TerritoryMapGeometry,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    showsMarkers: Boolean = true,
    smoothCorners: Boolean = false,
    interactive: Boolean = false,
    contentDescription: String? = null,
) {
    val colors = AppTheme.colors
    val dark = colors.isDark
    val mapColors = TerritoryMapColors(colors.accentDeep, colors.accent, colors.accent)
    BoxWithConstraints(modifier.semantics { if (contentDescription != null) this.contentDescription = contentDescription }) {
        val widthDp = maxWidth.value
        LiveMapView(
            modifier = Modifier.fillMaxSize(),
            styleKey = listOf(geometry.snapshotFingerprint, dark, showsMarkers, smoothCorners, compact).joinToString("|"),
            styleBuilder = {
                Style.Builder().fromUri(MapStyles.url(dark)).withTerritory(
                    geometry,
                    mapColors,
                    lineWidth = if (compact) 2.5f else 3f,
                    fillOpacity = 0.14f,
                    smooth = smoothCorners,
                    markers = if (!showsMarkers) MarkerStyle.None else if (compact) MarkerStyle.Dots else MarkerStyle.Labeled,
                )
            },
            camera = geometry.cameraPosition(compact, widthDp),
            interactive = interactive,
        )
    }
}

/**
 * `MapView` de MapLibre gestionado por el ciclo de vida de Compose. `onMap` permite a
 * pantallas más complejas (explorador) controlar el mapa directamente.
 */
@SuppressLint("ClickableViewAccessibility")
@Composable
fun LiveMapView(
    modifier: Modifier,
    styleKey: Any,
    styleBuilder: () -> Style.Builder,
    camera: CameraPosition?,
    interactive: Boolean,
    showsAttribution: Boolean = interactive,
    onMap: ((MapLibreMap, Style) -> Unit)? = null,
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val mapView = remember {
        MapView(context).apply { onCreate(null) }
    }
    var map by remember { mutableStateOf<MapLibreMap?>(null) }

    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) mapView.onStart()
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) mapView.onResume()
        mapView.getMapAsync { map = it }
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }

    LaunchedEffect(map, styleKey) {
        val m = map ?: return@LaunchedEffect
        m.uiSettings.apply {
            setAllGesturesEnabled(interactive)
            isLogoEnabled = false
            isAttributionEnabled = showsAttribution
            isCompassEnabled = interactive
        }
        if (camera != null) m.cameraPosition = camera
        m.setStyle(styleBuilder()) { style -> onMap?.invoke(m, style) }
    }

    AndroidView({ mapView }, modifier)
}

// MARK: - Snapshots de tarjetas

/**
 * Caché de snapshots de mapa: memoria limitada por bytes y disco (JPEG) con tope de
 * 50 MB y caducidad de 30 días. Equivale a `TerritorySnapshotCache` de iOS.
 */
object TerritorySnapshotCache {
    private val memory = object : LruCache<String, Bitmap>(48 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private const val CAPACITY = 50L * 1024 * 1024
    private const val MAX_AGE = 30L * 24 * 60 * 60 * 1000
    private var writes = 0

    private fun dir(context: Context) = File(context.cacheDir, "TerritorySnapshots").apply { mkdirs() }
    private fun file(context: Context, key: String): File {
        val digest = MessageDigest.getInstance("SHA-256").digest(key.toByteArray()).joinToString("") { "%02x".format(it) }
        return File(dir(context), "$digest.jpg")
    }

    fun memoryImage(key: String): Bitmap? = memory.get(key)

    suspend fun image(context: Context, key: String): Bitmap? {
        memory.get(key)?.let { return it }
        return withContext(Dispatchers.IO) {
            val f = file(context, key)
            if (!f.exists() || System.currentTimeMillis() - f.lastModified() > MAX_AGE) return@withContext null
            BitmapFactory.decodeFile(f.path)?.also { memory.put(key, it) }
        }
    }

    suspend fun insert(context: Context, key: String, bitmap: Bitmap) {
        memory.put(key, bitmap)
        withContext(Dispatchers.IO) {
            runCatching {
                FileOutputStream(file(context, key)).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 82, it) }
                if (++writes % 25 == 0) prune(context)
            }
        }
    }

    suspend fun diskSizeBytes(context: Context): Long = withContext(Dispatchers.IO) {
        dir(context).listFiles()?.sumOf { it.length() } ?: 0L
    }

    suspend fun clear(context: Context) {
        memory.evictAll()
        withContext(Dispatchers.IO) { dir(context).listFiles()?.forEach { it.delete() } }
    }

    private fun prune(context: Context) {
        val now = System.currentTimeMillis()
        val files = dir(context).listFiles()?.toMutableList() ?: return
        files.filter { now - it.lastModified() > MAX_AGE }.forEach { it.delete(); files.remove(it) }
        var total = files.sumOf { it.length() }
        for (f in files.sortedBy { it.lastModified() }) {
            if (total <= CAPACITY) break
            total -= f.length()
            f.delete()
        }
    }
}

/**
 * Fondo de mapa real para tarjetas: rasteriza los tiles con `MapSnapshotter` y dibuja el
 * contorno del territorio. Por defecto el territorio queda hacia la derecha.
 */
@Composable
fun TerritorySnapshotBackdrop(
    geometry: TerritoryMapGeometry,
    modifier: Modifier = Modifier,
    stroke: Color = AppTheme.colors.accentDeep,
    fill: Color = AppTheme.colors.accent,
    centersTerritory: Boolean = false,
    strokeLineWidth: Float = 3f,
    verticalBias: Double = 0.0,
    distanceMultiplier: Double? = null,
    horizontalShift: Double? = null,
) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val colors = AppTheme.colors
    BoxWithConstraints(modifier) {
        val w = maxWidth.value
        val h = maxHeight.value
        val key = listOf(
            "v3", geometry.snapshotFingerprint, "%.0fx%.0f@%.1f".format(w, h, density),
            if (colors.isDark) "dark" else "light", if (centersTerritory) "center" else "trailing",
            "%.2f".format(verticalBias), "%.2f".format(distanceMultiplier ?: -1.0), "%.2f".format(horizontalShift ?: -1.0),
            "%.1f".format(strokeLineWidth), stroke.toArgb(), fill.toArgb(),
        ).joinToString("|")
        var bitmap by remember(key) { mutableStateOf(TerritorySnapshotCache.memoryImage(key)) }

        LaunchedEffect(key) {
            if (bitmap != null || w < 2 || h < 2) return@LaunchedEffect
            TerritorySnapshotCache.image(context, key)?.let { bitmap = it; return@LaunchedEffect }
            val snapshot = takeSnapshot(
                context,
                width = w.toInt(),
                height = h.toInt(),
                pixelRatio = density,
                style = Style.Builder().fromUri(MapStyles.url(colors.isDark)).withTerritory(
                    geometry,
                    TerritoryMapColors(stroke, fill, stroke),
                    lineWidth = strokeLineWidth,
                    fillOpacity = 0.16f,
                    smooth = true,
                ),
                camera = geometry.backdropCamera(w, centersTerritory, verticalBias, distanceMultiplier, horizontalShift),
            ) ?: return@LaunchedEffect
            TerritorySnapshotCache.insert(context, key, snapshot)
            bitmap = snapshot
        }

        val current = bitmap
        if (current != null) {
            Image(current.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        } else {
            Box(Modifier.fillMaxSize().background(colors.accent.copy(alpha = 0.06f)))
        }
    }
}

private suspend fun takeSnapshot(
    context: Context,
    width: Int,
    height: Int,
    pixelRatio: Float,
    style: Style.Builder,
    camera: CameraPosition,
): Bitmap? = withContext(Dispatchers.Main) {
    suspendCancellableCoroutine { cont ->
        val options = MapSnapshotter.Options(width, height)
            .withPixelRatio(pixelRatio)
            .withStyleBuilder(style)
            .withCameraPosition(camera)
            .withLogo(false)
        val snapshotter = MapSnapshotter(context, options)
        snapshotter.start(
            { snapshot -> if (cont.isActive) cont.resume(snapshot.bitmap) },
            { if (cont.isActive) cont.resume(null) },
        )
        cont.invokeOnCancellation { snapshotter.cancel() }
    }
}
