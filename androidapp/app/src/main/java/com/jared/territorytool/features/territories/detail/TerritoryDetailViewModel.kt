package com.jared.territorytool.features.territories.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryDetail
import com.jared.territorytool.shared.models.TerritoryStatistics
import com.jared.territorytool.shared.models.Transaction
import com.jared.territorytool.shared.models.UndoHandle
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class TerritoryDetailViewModel(val territoryId: Int, private val api: ApiService = DIContainer.apiService) : ViewModel() {
    val territory = MutableStateFlow<TerritoryDetail?>(null)
    val stats = MutableStateFlow<TerritoryStatistics?>(null)
    val transactions = MutableStateFlow<List<Transaction>>(emptyList())
    val isLoading = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    val isRefreshingImage = MutableStateFlow(false)
    var lastUndoHandle: UndoHandle? = null
        private set

    init {
        viewModelScope.launch { loadData() }
    }

    fun reload(): Job = viewModelScope.launch { loadData() }

    suspend fun loadData() {
        isLoading.value = true
        errorMessage.value = null
        try {
            // Una sola petición: detalle, estadísticas e historial en paralelo.
            val bundle = api.getTerritoryDetailBundle(territoryId)
            territory.value = bundle.territory
            stats.value = bundle.stats
            transactions.value = bundle.transactions
            if (bundle.territory.mapGeometry == null) syncMapGeometry()
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = "Error loading data: ${e.localizedMessage}"
        }
        isLoading.value = false
    }

    private suspend fun syncMapGeometry() {
        try {
            api.syncTerritoryMap(territoryId)
            territory.value = api.getTerritoryDetail(territoryId)
        } catch (_: Exception) {
            // Se conserva la imagen heredada; la geometría se reintenta en la próxima carga.
        }
    }

    suspend fun refreshImage(): Boolean {
        isRefreshingImage.value = true
        return try {
            api.refreshTerritoryImage(territoryId)
            territory.value = api.getTerritoryDetail(territoryId)
            true
        } catch (e: Exception) {
            ToastManager.show("territory_detail.refresh_image_failed", ToastStyle.Error)
            false
        } finally {
            isRefreshingImage.value = false
        }
    }

    suspend fun deleteTerritory(): Boolean = try {
        lastUndoHandle = api.deleteTerritoryUndoable(territoryId).handle(UndoHandleKind.Domain)
        true
    } catch (e: Exception) {
        lastUndoHandle = null
        errorMessage.value = "Error deleting territory: ${e.localizedMessage}"
        false
    }

    suspend fun deleteTransaction(id: Int): Boolean = try {
        lastUndoHandle = api.deleteTransactionUndoable(id).handle(UndoHandleKind.Domain)
        transactions.value = transactions.value.filterNot { it.id == id }
        loadData()
        true
    } catch (e: Exception) {
        lastUndoHandle = null
        errorMessage.value = "Error deleting transaction: ${e.localizedMessage}"
        false
    }

    class Factory(private val id: Int) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T = TerritoryDetailViewModel(id) as T
    }
}

fun TerritoryDetail.toTerritory() = Territory(
    id = id, code = code, name = name, mapUrl = mapUrl, imgUrl = imgUrl, personName = personName,
    givenDateUtc = givenDateUtc, lastPickedDateUtc = lastPickedDateUtc, mapGeometry = mapGeometry,
)
