package com.jared.territorytool.features.quickaction

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.features.territories.TerritorySortOption
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import java.time.Instant

/** Acción final del flujo: entregar un territorio libre o recoger uno asignado. */
sealed interface QuickActionAction {
    val territory: Territory

    data class Deliver(override val territory: Territory, val recipient: String) : QuickActionAction
    data class Return(override val territory: Territory) : QuickActionAction

    val isDeliver: Boolean get() = this is Deliver
    /** Persona destino (sólo en entrega). */
    val personName: String? get() = (this as? Deliver)?.recipient
}

/** Hub de Acción rápida: buscador universal, escaneos y sugerencias. */
@OptIn(FlowPreview::class)
class QuickActionViewModel(private val api: ApiService = DIContainer.apiService) : ViewModel() {
    val searchTerm = MutableStateFlow("")
    val searchHits = MutableStateFlow<List<QuickSearchHit>>(emptyList())
    val isSearching = MutableStateFlow(false)
    val attentionTerritories = MutableStateFlow<List<Territory>>(emptyList())
    val oldestFreeTerritories = MutableStateFlow<List<Territory>>(emptyList())
    val isLoadingSuggestions = MutableStateFlow(false)
    val isResolvingScan = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    private val attentionDays = 90
    private var isBrowsing = false
    private var searchJob: Job? = null

    init {
        viewModelScope.launch {
            searchTerm
                .map { it.trim() }
                .distinctUntilChanged()
                // Marca "buscando" de inmediato para no mostrar "sin resultados" mientras se teclea.
                .onEach { term ->
                    if (term.isEmpty()) {
                        if (isBrowsing) isSearching.value = true else { searchHits.value = emptyList(); isSearching.value = false }
                    } else {
                        isSearching.value = true
                    }
                }
                .debounce(300)
                .collect { term -> runSearch(term) }
        }
    }

    val hasSearch: Boolean get() = searchTerm.value.isNotBlank()

    /** Con el buscador enfocado y vacío se navegan todos los territorios. */
    fun setBrowsing(focused: Boolean) {
        isBrowsing = focused
        runSearch(searchTerm.value.trim())
    }

    private fun runSearch(term: String) {
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            if (term.isEmpty()) {
                if (isBrowsing) {
                    searchHits.value = fetchTerritories(null).sortedWith { a, b -> naturalCompare(a.code, b.code) }
                        .map { QuickSearchHit(QuickSearchHit.Kind.Territory, territory = it) }
                } else {
                    searchHits.value = emptyList()
                }
                isSearching.value = false
                return@launch
            }
            isSearching.value = true
            try {
                searchHits.value = api.searchQuickAction(term)
            } catch (e: Exception) {
                if (!e.isCancellation) { errorMessage.value = e.localizedMessage; searchHits.value = emptyList() }
            }
            isSearching.value = false
        }
    }

    fun loadSuggestions() {
        viewModelScope.launch {
            isLoadingSuggestions.value = true
            val (assigned, free) = coroutineScope {
                val a = async { fetchTerritories(true) }
                val f = async { fetchTerritories(false) }
                a.await() to f.await()
            }
            // Atención: sólo los que superan el umbral, el más antiguo primero.
            attentionTerritories.value = assigned
                .filter { (it.daysAssigned() ?: 0) >= attentionDays }
                .sortedBy { it.givenDateUtc ?: Instant.MAX }
                .take(3)
            // Libres desde hace tiempo: nunca recogidos primero, luego los más antiguos.
            oldestFreeTerritories.value = free.sortedWith(compareBy(nullsFirst()) { it.lastPickedDateUtc }).take(3)
            isLoadingSuggestions.value = false
        }
    }

    suspend fun resolve(scannedValue: String): Territory? {
        isResolvingScan.value = true
        return try {
            api.resolveTerritorySelector(scannedValue)
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = e.localizedMessage
            null
        } finally {
            isResolvingScan.value = false
        }
    }

    private suspend fun fetchTerritories(inUse: Boolean?): List<Territory> = try {
        api.getTerritories(null, inUse, TerritorySortOption.Name.code, true)
    } catch (e: Exception) {
        if (!e.isCancellation) errorMessage.value = e.localizedMessage
        emptyList()
    }
}

/** Selector de personas o de territorios libres con el buscador inteligente. */
@OptIn(FlowPreview::class)
class QuickActionPickerViewModel(val mode: Mode, private val api: ApiService = DIContainer.apiService) : ViewModel() {
    enum class Mode { Persons, FreeTerritories }

    val search = MutableStateFlow("")
    val persons = MutableStateFlow<List<Person>>(emptyList())
    val territories = MutableStateFlow<List<Territory>>(emptyList())
    val isLoading = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    private var job: Job? = null

    init {
        viewModelScope.launch {
            search.map { it.trim() }.distinctUntilChanged().drop(1).debounce(300).collect { run() }
        }
    }

    fun loadInitial() = run()

    private fun run() {
        job?.cancel()
        job = viewModelScope.launch {
            val term = search.value.trim()
            isLoading.value = true
            try {
                if (term.isEmpty()) {
                    when (mode) {
                        Mode.Persons -> persons.value = api.getPersons(null)
                        Mode.FreeTerritories -> territories.value = api.getTerritories(null, false, TerritorySortOption.Name.code, true)
                    }
                } else {
                    val hits = api.searchQuickAction(term)
                    when (mode) {
                        Mode.Persons -> persons.value = hits.mapNotNull { it.person }
                        Mode.FreeTerritories -> territories.value = hits.mapNotNull { it.territory }.filter { !it.isAssigned }
                    }
                }
            } catch (e: Exception) {
                if (!e.isCancellation) errorMessage.value = e.localizedMessage
            } finally {
                isLoading.value = false
            }
        }
    }

    class Factory(private val mode: Mode) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T = QuickActionPickerViewModel(mode) as T
    }
}

/** Orden "natural" de códigos (AV2 < AV10). */
fun naturalCompare(a: String, b: String): Int {
    val ra = Regex("\\d+|\\D+").findAll(a).map { it.value }.toList()
    val rb = Regex("\\d+|\\D+").findAll(b).map { it.value }.toList()
    for (i in 0 until minOf(ra.size, rb.size)) {
        val x = ra[i]; val y = rb[i]
        val c = if (x[0].isDigit() && y[0].isDigit()) x.toBigInteger().compareTo(y.toBigInteger()) else x.compareTo(y, ignoreCase = true)
        if (c != 0) return c
    }
    return ra.size - rb.size
}
