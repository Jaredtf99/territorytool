package com.jared.territorytool.core

import com.jared.territorytool.core.network.CongregationSummary
import com.jared.territorytool.core.network.SupabaseAuthService
import com.jared.territorytool.core.network.TokenManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Congregaciones a las que puede operar el usuario y la activa. Cambiar refresca el
 * JWT para que RLS y los claims de rol se actualicen.
 */
object CongregationStore {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _congregations = MutableStateFlow<List<CongregationSummary>>(emptyList())
    val congregations: StateFlow<List<CongregationSummary>> = _congregations
    private val _isSwitching = MutableStateFlow(false)
    val isSwitching: StateFlow<Boolean> = _isSwitching

    fun init() {
        load()
        scope.launch { AppEvents.of(AppEvent.AuthChanged).collect { load() } }
    }

    val active: CongregationSummary? get() = _congregations.value.firstOrNull { it.isActive }
    val hasMultiple: Boolean get() = _congregations.value.size > 1

    fun load() {
        _congregations.value = TokenManager.getCongregationsJson()?.let(SupabaseAuthService::decodeCongregations) ?: emptyList()
    }

    suspend fun refresh() {
        runCatching { SupabaseAuthService.getMyCongregations() }.onSuccess(::persist)
    }

    suspend fun switchTo(congregationId: String): Boolean {
        if (active?.id == congregationId) return true
        _isSwitching.value = true
        return try {
            SupabaseAuthService.setActiveCongregation(congregationId)
            TokenManager.saveActiveCongregationId(congregationId)
            persist(_congregations.value.map { it.copy(isActive = it.id == congregationId) })
            AppEvents.post(AppEvent.CongregationChanged)
            true
        } catch (e: Exception) {
            false
        } finally {
            _isSwitching.value = false
        }
    }

    private fun persist(list: List<CongregationSummary>) {
        _congregations.value = list
        TokenManager.saveCongregations(SupabaseAuthService.encodeCongregations(list))
    }
}
