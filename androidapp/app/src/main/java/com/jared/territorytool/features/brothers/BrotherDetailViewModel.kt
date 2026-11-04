package com.jared.territorytool.features.brothers

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Smartphone
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.PersonAssignment
import com.jared.territorytool.shared.models.PersonDetail
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import java.text.Normalizer
import java.time.ZoneId

/** Filtro del histórico de la ficha de hermano. */
enum class BrotherHistoryFilter(@StringRes val title: Int, val icon: ImageVector) {
    All(R.string.brother_detail_history_filter_all, Icons.Rounded.Layers),
    Ongoing(R.string.brother_detail_history_filter_ongoing, Icons.AutoMirrored.Rounded.DirectionsWalk),
    Returned(R.string.brother_detail_history_filter_returned, Icons.Rounded.Check),
    Virtual(R.string.brother_detail_history_filter_virtual, Icons.Rounded.Smartphone);

    fun matches(item: PersonAssignment): Boolean = when (this) {
        All -> true
        Ongoing -> item.isOngoing
        Returned -> !item.isOngoing
        Virtual -> item.deliveryFormat == DeliveryFormat.Virtual
    }
}

data class BrotherHistoryYear(val year: Int, val items: List<PersonAssignment>)

class BrotherDetailViewModel(val personId: Int, private val api: ApiService = DIContainer.apiService) : ViewModel() {
    val detail = MutableStateFlow<PersonDetail?>(null)
    val isLoading = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    val historyFilter = MutableStateFlow(BrotherHistoryFilter.All)
    val historySearch = MutableStateFlow("")
    val historyLimit = MutableStateFlow(HISTORY_PAGE)
    val isSaving = MutableStateFlow(false)

    init {
        // Entregar/devolver desde la Acción rápida refresca la ficha.
        viewModelScope.launch {
            AppEvents.of(AppEvent.TerritoryDataChanged, AppEvent.CongregationChanged).collect { load() }
        }
        viewModelScope.launch { load() }
    }

    fun reload(): Job = viewModelScope.launch { load() }

    suspend fun load() {
        isLoading.value = true
        errorMessage.value = null
        try {
            detail.value = api.getPersonDetail(personId)
        } catch (e: Exception) {
            if (!e.isCancellation) {
                val message = e.localizedMessage ?: ""
                errorMessage.value = if (message.contains("PERSON_NOT_FOUND", true)) Strings.get(R.string.brothers_error_not_found) else message
            }
        }
        isLoading.value = false
    }

    // MARK: Histórico

    fun filteredHistory(history: List<PersonAssignment>, filter: BrotherHistoryFilter, search: String): List<PersonAssignment> {
        val term = normalize(search)
        return history.filter { item ->
            filter.matches(item) && (term.isEmpty() || normalize(item.territoryCode).contains(term) || normalize(item.territoryName).contains(term))
        }
    }

    fun groupByYear(items: List<PersonAssignment>): List<BrotherHistoryYear> {
        val zone = ZoneId.systemDefault()
        return items
            .groupBy { it.givenAt.atZone(zone).year }
            .map { (year, list) -> BrotherHistoryYear(year, list) }
            .sortedByDescending { it.year }
    }

    fun setFilter(filter: BrotherHistoryFilter) {
        historyFilter.value = filter
        historyLimit.value = HISTORY_PAGE
    }

    fun setSearch(value: String) {
        historySearch.value = value
        historyLimit.value = HISTORY_PAGE
    }

    fun showMore() {
        historyLimit.value += HISTORY_PAGE
    }

    // MARK: Edición

    suspend fun update(name: String, enabled: Boolean): Boolean {
        isSaving.value = true
        return try {
            val handle = api.updatePersonUndoable(personId, name, enabled).handle(UndoHandleKind.Domain)
            ToastManager.show("brothers.update_success", ToastStyle.Success, handle, handle.toastDurationMillis)
            // La lista de hermanos también escucha este evento.
            AppEvents.post(AppEvent.TerritoryDataChanged)
            true
        } catch (e: Exception) {
            var message = e.localizedMessage ?: ""
            if (message.contains("already exists", true) || message.contains("ya existe", true)) {
                message = Strings.get(R.string.brothers_error_exists)
            }
            ToastManager.show(message, ToastStyle.Error)
            false
        } finally {
            isSaving.value = false
        }
    }

    class Factory(private val id: Int) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T = BrotherDetailViewModel(id) as T
    }

    companion object {
        const val HISTORY_PAGE = 20

        private fun normalize(value: String): String =
            Normalizer.normalize(value, Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").lowercase().trim()
    }
}
