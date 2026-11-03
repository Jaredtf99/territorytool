package com.jared.territorytool.features.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

@OptIn(FlowPreview::class)
class MovementHistoryViewModel(private val api: ApiService = DIContainer.apiService) : ViewModel() {
    private val _movements = MutableStateFlow<List<DashboardMovement>>(emptyList())
    val movements: StateFlow<List<DashboardMovement>> = _movements
    val searchText = MutableStateFlow("")
    val filter = MutableStateFlow(MovementHistoryFilter.All)
    val sort = MutableStateFlow(MovementHistorySort.Newest)
    val isLoading = MutableStateFlow(false)
    val isLoadingMore = MutableStateFlow(false)
    private var canLoadMore = true
    val errorMessage = MutableStateFlow<String?>(null)

    private val pageSize = 25
    private var currentPage = 1
    private var loadJob: Job? = null

    init {
        viewModelScope.launch {
            combine(searchText, filter, sort) { a, b, c -> Triple(a, b, c) }
                .debounce(350)
                .distinctUntilChanged()
                .drop(1)
                .collect { reload() }
        }
        viewModelScope.launch {
            AppEvents.of(AppEvent.CongregationChanged, AppEvent.TerritoryDataChanged).collect { reload() }
        }
        reload()
    }

    fun reload() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch { load(reset = true) }
    }

    suspend fun load(reset: Boolean) {
        if (reset) {
            currentPage = 1
            canLoadMore = true
            isLoading.value = true
        } else {
            if (!canLoadMore || isLoadingMore.value) return
            isLoadingMore.value = true
        }
        errorMessage.value = null
        try {
            val query = searchText.value.trim()
            val response = api.getMovementHistory(currentPage, pageSize, query.ifEmpty { null }, filter.value, sort.value)
            _movements.value = if (reset) response.data else _movements.value + response.data
            val lastPage = response.lastPage ?: currentPage
            canLoadMore = currentPage < lastPage
            if (canLoadMore) currentPage += 1
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = e.localizedMessage
        } finally {
            isLoading.value = false
            isLoadingMore.value = false
        }
    }

    fun loadMoreIfNeeded(current: DashboardMovement) {
        if (current.id != _movements.value.lastOrNull()?.id) return
        viewModelScope.launch { load(reset = false) }
    }
}
