package com.jared.territorytool.features.brothers

import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.features.quickaction.activeTerritoryCount
import com.jared.territorytool.features.quickaction.daysHeld
import com.jared.territorytool.features.quickaction.hasActiveTerritory
import com.jared.territorytool.features.quickaction.maxDaysHeld
import com.jared.territorytool.features.territories.TerritoryFilter
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Filtro operativo: disponible = activo sin territorios, con territorios = activo con ≥1. */
enum class BrotherFilter(@StringRes val title: Int) {
    All(R.string.brothers_filter_all),
    Available(R.string.brothers_filter_available),
    WithTerritories(R.string.brothers_filter_with_territories),
    Inactive(R.string.brothers_filter_inactive),
}

enum class BrotherSortOption(@StringRes val title: Int) {
    Name(R.string.brothers_sort_name),
    Territories(R.string.brothers_sort_territories),
    Seniority(R.string.brothers_sort_days),
}

/** Derivados de `brothers`, calculados juntos en una sola pasada. */
data class BrothersDerivedState(
    val display: List<Person> = emptyList(),
    val filterCounts: Map<BrotherFilter, Int> = emptyMap(),
    val holderCount: Int = 0,
    val enabledCount: Int = 0,
    val assignmentDays: List<Int> = emptyList(),
)

class BrothersViewModel(private val api: ApiService = DIContainer.apiService) : ViewModel() {
    val brothers = MutableStateFlow<List<Person>>(emptyList())
    val searchText = MutableStateFlow("")
    val filter = MutableStateFlow(BrotherFilter.All)
    val sortOption = MutableStateFlow(BrotherSortOption.Name)
    val sortAscending = MutableStateFlow(true)
    val isLoading = MutableStateFlow(true)
    val errorMessage = MutableStateFlow<String?>(null)
    val expandedIds = MutableStateFlow<Set<Int>>(emptySet())
    val territoryGeometries = MutableStateFlow<Map<Int, TerritoryMapGeometry>>(emptyMap())
    val territoryImageUrls = MutableStateFlow<Map<Int, String>>(emptyMap())
    private var previewsJob: Job? = null

    val derived: StateFlow<BrothersDerivedState> = combine(brothers, searchText, filter, sortOption, sortAscending) { list, search, f, sort, asc ->
        recompute(list, search, f, sort, asc)
    }.stateIn(viewModelScope, SharingStarted.Eagerly, BrothersDerivedState())

    init {
        viewModelScope.launch {
            AppEvents.flow.collect { event ->
                when (event) {
                    AppEvent.CongregationChanged -> {
                        brothers.value = emptyList()
                        territoryGeometries.value = emptyMap()
                        territoryImageUrls.value = emptyMap()
                        fetchBrothers()
                    }
                    AppEvent.TerritoryDataChanged -> fetchBrothers()
                    else -> Unit
                }
            }
        }
        viewModelScope.launch { fetchBrothers() }
    }

    private fun recompute(list: List<Person>, search: String, f: BrotherFilter, sort: BrotherSortOption, asc: Boolean): BrothersDerivedState {
        val searched = if (search.isEmpty()) list else list.filter { it.name.contains(search, ignoreCase = true) }
        val available = searched.filter { it.enabled && !it.hasActiveTerritory }
        val withTerritories = searched.filter { it.enabled && it.hasActiveTerritory }
        val inactive = searched.filter { !it.enabled }
        val base = when (f) {
            BrotherFilter.All -> searched
            BrotherFilter.Available -> available
            BrotherFilter.WithTerritories -> withTerritories
            BrotherFilter.Inactive -> inactive
        }
        val sorted = when (sort) {
            BrotherSortOption.Name -> base
            BrotherSortOption.Territories -> base.sortedBy { it.activeTerritoryCount }
            BrotherSortOption.Seniority -> base.sortedBy { it.maxDaysHeld ?: -1 }
        }
        val enabled = list.filter { it.enabled }
        return BrothersDerivedState(
            display = if (asc) sorted else sorted.reversed(),
            filterCounts = mapOf(
                BrotherFilter.All to searched.size,
                BrotherFilter.Available to available.size,
                BrotherFilter.WithTerritories to withTerritories.size,
                BrotherFilter.Inactive to inactive.size,
            ),
            // El resumen es global: no depende de búsqueda ni de filtro.
            holderCount = enabled.count { it.hasActiveTerritory },
            enabledCount = enabled.size,
            assignmentDays = enabled.flatMap { it.territoriesInUse.orEmpty() }.map { it.daysHeld() }.sortedDescending(),
        )
    }

    fun toggleExpanded(id: Int) {
        val current = expandedIds.value
        if (id in current) {
            expandedIds.value = current - id
        } else {
            expandedIds.value = current + id
            loadTerritoryPreviewsIfNeeded()
        }
    }

    /** Previews de mapa del panel expandido: una sola petición al explorador, perezosa. */
    private fun loadTerritoryPreviewsIfNeeded() {
        if (territoryGeometries.value.isNotEmpty() || territoryImageUrls.value.isNotEmpty() || previewsJob != null) return
        previewsJob = viewModelScope.launch {
            try {
                val result = api.territoryExplorer(null, TerritoryFilter.All, 90)
                territoryGeometries.value = result.mapNotNull { t -> t.mapGeometry?.let { t.id to it } }.toMap()
                territoryImageUrls.value = result.mapNotNull { t -> t.imgUrl?.let { t.id to it } }.toMap()
            } catch (_: Exception) {
                // Silencioso a propósito: el preview es un extra visual.
            } finally {
                previewsJob = null
            }
        }
    }

    suspend fun fetchBrothers() {
        isLoading.value = true
        errorMessage.value = null
        try {
            brothers.value = api.getPersonsWithAssignments(null).sortedBy { it.name }
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = e.localizedMessage
        }
        isLoading.value = false
    }

    suspend fun addBrother(name: String): Boolean {
        isLoading.value = true
        errorMessage.value = null
        return try {
            val handle = api.addPersonUndoable(name).handle(UndoHandleKind.Domain)
            ToastManager.show("brothers.add_success", ToastStyle.Success, handle, handle.toastDurationMillis)
            fetchBrothers()
            true
        } catch (e: Exception) {
            var message = e.localizedMessage ?: ""
            if (message.contains("ALREADY_EXISTS", ignoreCase = true)) message = Strings.get(R.string.brothers_error_exists)
            errorMessage.value = message
            ToastManager.show(message, ToastStyle.Error)
            isLoading.value = false
            false
        }
    }

    suspend fun updateBrother(person: Person, newName: String, enabled: Boolean): Boolean {
        isLoading.value = true
        errorMessage.value = null
        return try {
            val handle = api.updatePersonUndoable(person.id, newName, enabled).handle(UndoHandleKind.Domain)
            ToastManager.show("brothers.update_success", ToastStyle.Success, handle, handle.toastDurationMillis)
            fetchBrothers()
            true
        } catch (e: Exception) {
            var message = e.localizedMessage ?: ""
            if (message.contains("already exists", true) || message.contains("ya existe", true)) {
                message = Strings.get(R.string.brothers_error_exists)
            } else if (message.contains("not found", true) || message.contains("no encontrada", true)) {
                message = Strings.get(R.string.brothers_error_not_found)
            }
            errorMessage.value = message
            ToastManager.show(message, ToastStyle.Error)
            isLoading.value = false
            false
        }
    }

    suspend fun deleteBrother(person: Person) {
        isLoading.value = true
        errorMessage.value = null
        try {
            val handle = api.deletePersonUndoable(person.name).handle(UndoHandleKind.Domain)
            ToastManager.show("brothers.delete_success", ToastStyle.Success, handle, handle.toastDurationMillis)
            fetchBrothers()
        } catch (e: Exception) {
            errorMessage.value = e.localizedMessage
            ToastManager.show(e.localizedMessage ?: "", ToastStyle.Error)
            isLoading.value = false
        }
    }
}
