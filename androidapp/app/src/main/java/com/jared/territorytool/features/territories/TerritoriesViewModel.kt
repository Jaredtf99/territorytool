package com.jared.territorytool.features.territories

import android.app.Application
import android.content.Context
import android.location.Location
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.TerritoriesLaunchContext
import com.jared.territorytool.core.TerritoriesPresentation
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryMapCoordinate
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import com.jared.territorytool.shared.models.TerritoryOperationalStatus
import com.jared.territorytool.shared.models.UndoHandle
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.utils.isCancellation
import com.jared.territorytool.shared.utils.userFriendlyMessage
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import java.text.Collator
import java.text.Normalizer
import java.time.Instant

/** Listas derivadas de `territories`, materializadas juntas. */
data class TerritoriesDerivedState(
    val sorted: List<Territory> = emptyList(),
    val withGeometry: List<Territory> = emptyList(),
    val withoutGeometry: List<Territory> = emptyList(),
    val attention: List<Territory> = emptyList(),
    val statusById: Map<Int, TerritoryOperationalStatus> = emptyMap(),
    /** Cambia sólo cuando cambia el conjunto de geometrías mostradas (clave del mapa). */
    val geometryRevision: Int = 0,
    val geometrySignature: String = "",
)

@OptIn(FlowPreview::class)
class TerritoriesViewModel(app: Application) : AndroidViewModel(app) {
    private val api = DIContainer.apiService
    private val prefs = app.getSharedPreferences("settings", Context.MODE_PRIVATE)

    val territories = MutableStateFlow<List<Territory>>(emptyList())
    val isLoading = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    val searchText = MutableStateFlow("")
    val filterStatus = MutableStateFlow(TerritoryFilter.All)
    /** Filtro local sobre las entregas en curso (físico/virtual). `null` = todos. */
    val deliveryFormatFilter = MutableStateFlow<DeliveryFormat?>(null)
    val sortOption = MutableStateFlow(TerritorySortOption.Code)
    val sortAscending = MutableStateFlow(true)
    val attentionDays = MutableStateFlow(90)
    val presentation = MutableStateFlow(
        if (prefs.getString("territories.presentation", null) == "list") TerritoriesPresentation.List else TerritoriesPresentation.Map,
    )
    val selectedTerritoryId = MutableStateFlow<Int?>(null)
    val drawerDetent = MutableStateFlow(TerritoryDrawerDetent.Medium)
    var lastDeleteUndoHandle: UndoHandle? = null
        private set

    private val _derived = MutableStateFlow(TerritoriesDerivedState())
    val derived: StateFlow<TerritoriesDerivedState> = _derived
    private val _nearestFirst = MutableStateFlow<List<Territory>>(emptyList())
    val nearestFirst: StateFlow<List<Territory>> = _nearestFirst
    private var lastNearestLocation: Location? = null
    private var loadJob: Job? = null
    private val collator = Collator.getInstance().apply { strength = Collator.SECONDARY }

    init {
        viewModelScope.launch {
            combine(searchText, filterStatus) { a, b -> a to b }.debounce(350).distinctUntilChanged().drop(1).collect { reload() }
        }
        viewModelScope.launch {
            combine(searchText, sortOption, sortAscending, attentionDays, deliveryFormatFilter) { _, _, _, _, _ -> }.drop(1).collect { recompute() }
        }
        viewModelScope.launch {
            // Un territorio libre no tiene formato de entrega.
            filterStatus.collect { if (it == TerritoryFilter.Free) deliveryFormatFilter.value = null }
        }
        viewModelScope.launch {
            AppEvents.flow.collect { event ->
                when (event) {
                    AppEvent.TerritoryDeleted, AppEvent.TerritoryDataChanged -> reload()
                    AppEvent.CongregationChanged -> {
                        territories.value = emptyList()
                        selectedTerritoryId.value = null
                        recompute()
                        reload()
                    }
                    else -> Unit
                }
            }
        }
    }

    val selectedTerritory: Territory? get() = territories.value.firstOrNull { it.id == selectedTerritoryId.value }

    /** Estado operacional cacheado (evita recalcular fechas por render). */
    fun status(territory: Territory): TerritoryOperationalStatus =
        _derived.value.statusById[territory.id] ?: territory.operationalStatus(attentionDays.value)

    /** Recalcula el orden por cercanía si procede; barato cuando no hay cambios. */
    fun updateNearestOrder(location: Location?) {
        if (sortOption.value != TerritorySortOption.Nearest || location == null) {
            if (_nearestFirst.value.isNotEmpty()) _nearestFirst.value = emptyList()
            lastNearestLocation = null
            return
        }
        val last = lastNearestLocation
        if (last != null && last.distanceTo(location) < 25 && _nearestFirst.value.size == _derived.value.withGeometry.size) return
        lastNearestLocation = location
        _nearestFirst.value = _derived.value.withGeometry.sortedBy { distance(location, it) }
    }

    fun drawerTerritories(derived: TerritoriesDerivedState, nearest: List<Territory>, sort: TerritorySortOption): List<Territory> =
        if (sort == TerritorySortOption.Nearest && nearest.isNotEmpty()) nearest else derived.withGeometry

    private fun distance(location: Location, territory: Territory): Float {
        val c = territory.mapGeometry?.representativeCoordinate ?: return Float.MAX_VALUE
        val result = FloatArray(1)
        Location.distanceBetween(location.latitude, location.longitude, c.latitude, c.longitude, result)
        return result[0]
    }

    /** Conmutable: volver a elegir el formato activo lo desactiva. */
    fun toggleDeliveryFormatFilter(format: DeliveryFormat) {
        val next = if (deliveryFormatFilter.value == format) null else format
        if (next != null && filterStatus.value == TerritoryFilter.Free) filterStatus.value = TerritoryFilter.InUse
        deliveryFormatFilter.value = next
    }

    private fun filtered(): List<Territory> {
        val format = deliveryFormatFilter.value
        val values = if (format == null) territories.value
        else territories.value.filter { it.personName != null && it.deliveryFormat == format }
        val query = searchText.value.trim()
        if (!isCodeQuery(query)) return values
        return values.filter { normalized(it.code).contains(normalized(query)) }
    }

    private fun recompute() {
        val now = Instant.now()
        val statuses = territories.value.associate { it.id to it.operationalStatus(attentionDays.value, now) }
        val sortedValues = sorted(filtered())
        val withGeometry = sortedValues.filter { it.mapGeometry != null }
        val signature = withGeometry.sortedBy { it.id }.joinToString("|") { "${it.id}:${it.mapGeometry?.snapshotFingerprint ?: ""}" }
        val previous = _derived.value
        _derived.value = TerritoriesDerivedState(
            sorted = sortedValues,
            withGeometry = withGeometry,
            withoutGeometry = sortedValues.filter { it.mapGeometry == null },
            attention = sortedValues.filter { statuses[it.id] is TerritoryOperationalStatus.Attention },
            statusById = statuses,
            geometryRevision = if (signature != previous.geometrySignature) previous.geometryRevision + 1 else previous.geometryRevision,
            geometrySignature = signature,
        )
    }

    fun setPresentation(value: TerritoriesPresentation, persist: Boolean = true) {
        presentation.value = value
        if (persist) prefs.edit().putString("territories.presentation", if (value == TerritoriesPresentation.Map) "map" else "list").apply()
    }

    fun select(territory: Territory?) {
        selectedTerritoryId.value = territory?.id
        // Al seleccionar, el drawer se compacta para mostrar SOLO ese territorio.
        if (territory != null) drawerDetent.value = TerritoryDrawerDetent.Collapsed
    }

    fun reload(): Job {
        loadJob?.cancel()
        return viewModelScope.launch { loadTerritories() }.also { loadJob = it }
    }

    suspend fun loadTerritories() {
        isLoading.value = true
        errorMessage.value = null
        try {
            val term = searchText.value.trim()
            val result = api.territoryExplorer(term.ifEmpty { null }, filterStatus.value, attentionDays.value)
            territories.value = result
            val selected = selectedTerritoryId.value
            if (selected != null && result.none { it.id == selected }) selectedTerritoryId.value = null
            recompute()
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = e.localizedMessage
        } finally {
            isLoading.value = false
        }
    }

    fun applyLaunchContext(context: TerritoriesLaunchContext) {
        attentionDays.value = context.attentionDays
        filterStatus.value = context.filter
        deliveryFormatFilter.value = null
        setPresentation(context.presentation, persist = false)
        sortOption.value = if (context.filter == TerritoryFilter.Attention) TerritorySortOption.GivenDate else TerritorySortOption.Code
        sortAscending.value = true
        selectedTerritoryId.value = null
    }

    suspend fun deleteTerritory(territory: Territory): Boolean {
        errorMessage.value = null
        return try {
            lastDeleteUndoHandle = api.deleteTerritoryUndoable(territory.id).handle(UndoHandleKind.Domain)
            // La fila sólo desaparece después de que Supabase confirme el borrado.
            territories.value = territories.value.filterNot { it.id == territory.id }
            if (selectedTerritoryId.value == territory.id) selectedTerritoryId.value = null
            recompute()
            AppEvents.post(AppEvent.TerritoryDeleted)
            true
        } catch (e: Exception) {
            lastDeleteUndoHandle = null
            errorMessage.value = e.userFriendlyMessage
            false
        }
    }

    private fun sorted(values: List<Territory>): List<Territory> {
        val comparator = Comparator<Territory> { l, r -> compare(l, r) }
        return values.sortedWith(if (sortAscending.value) comparator else comparator.reversed())
    }

    private fun isCodeQuery(query: String): Boolean =
        query.isNotEmpty() && query.none { it.isWhitespace() } && query.any { it.isLetter() } && query.any { it.isDigit() }

    private fun normalized(value: String): String =
        Normalizer.normalize(value, Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").lowercase().filter { it.isLetterOrDigit() }

    /** Orden "natural" (como `localizedStandardCompare`): los números se comparan por valor. */
    private fun naturalCompare(a: String, b: String): Int {
        val ra = Regex("\\d+|\\D+").findAll(a).map { it.value }.toList()
        val rb = Regex("\\d+|\\D+").findAll(b).map { it.value }.toList()
        for (i in 0 until minOf(ra.size, rb.size)) {
            val x = ra[i]; val y = rb[i]
            val c = if (x[0].isDigit() && y[0].isDigit()) x.toBigInteger().compareTo(y.toBigInteger()) else collator.compare(x, y)
            if (c != 0) return c
        }
        return ra.size - rb.size
    }

    private fun compare(l: Territory, r: Territory): Int = when (sortOption.value) {
        TerritorySortOption.Name -> naturalCompare(l.name, r.name).takeIf { it != 0 } ?: l.id.compareTo(r.id)
        TerritorySortOption.Code, TerritorySortOption.Nearest -> naturalCompare(l.code, r.code).takeIf { it != 0 } ?: l.id.compareTo(r.id)
        // Inicio del estado actual: entrega si está asignado, última devolución si está libre.
        TerritorySortOption.GivenDate -> currentStateStart(l).compareTo(currentStateStart(r)).takeIf { it != 0 } ?: l.id.compareTo(r.id)
    }

    private fun currentStateStart(t: Territory): Instant =
        (if (t.personName == null) t.lastPickedDateUtc else t.givenDateUtc) ?: Instant.MIN
}

/** Centroide del polígono más grande, o el centro de los bounds. */
val TerritoryMapGeometry.representativeCoordinate: TerritoryMapCoordinate
    get() {
        val largest = polygons.maxByOrNull { it.coordinates.size }
        if (largest != null && largest.coordinates.isNotEmpty()) {
            val n = largest.coordinates.size.toDouble()
            return TerritoryMapCoordinate(largest.coordinates.sumOf { it.latitude } / n, largest.coordinates.sumOf { it.longitude } / n)
        }
        return TerritoryMapCoordinate((bounds.north + bounds.south) / 2, (bounds.east + bounds.west) / 2)
    }
