package com.jared.territorytool.features.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.core.network.TokenManager
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.models.UserRole
import com.jared.territorytool.shared.models.daysBetween
import com.jared.territorytool.shared.utils.JWTHelper
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.time.temporal.WeekFields
import java.util.Locale

class DashboardViewModel(private val api: ApiService = DIContainer.apiService) : ViewModel() {
    companion object {
        const val ATTENTION_DAYS = 90

        /** Inicio de la semana actual según el calendario del dispositivo. */
        fun startOfCurrentWeek(): Instant {
            val zone = ZoneId.systemDefault()
            val firstDay: DayOfWeek = WeekFields.of(Locale.getDefault()).firstDayOfWeek
            return LocalDate.now(zone).with(TemporalAdjusters.previousOrSame(firstDay)).atStartOfDay(zone).toInstant()
        }
    }

    private val _snapshot = MutableStateFlow<DashboardSnapshot?>(null)
    val snapshot: StateFlow<DashboardSnapshot?> = _snapshot
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading
    val errorMessage = MutableStateFlow<String?>(null)
    private var loadJob: Job? = null

    init {
        viewModelScope.launch {
            AppEvents.flow.collect { event ->
                when (event) {
                    AppEvent.CongregationChanged -> {
                        _snapshot.value = null
                        loadDashboard()
                    }
                    AppEvent.TerritoryDataChanged -> loadDashboard()
                    else -> Unit
                }
            }
        }
    }

    fun loadDashboard(): Job {
        loadJob?.cancel()
        return viewModelScope.launch {
            _isLoading.value = true
            errorMessage.value = null
            try {
                _snapshot.value = api.getDashboardSnapshot(startOfCurrentWeek(), ZoneId.systemDefault().id, ATTENTION_DAYS)
            } catch (e: Exception) {
                // Una cancelación no es un fallo: conservamos los datos actuales.
                if (!e.isCancellation) errorMessage.value = e.localizedMessage
            } finally {
                _isLoading.value = false
            }
        }.also { loadJob = it }
    }

    val userName: String get() = TokenManager.getToken()?.let { JWTHelper.getUserName(it) } ?: ""

    val greetingKey: String
        get() = when (LocalTime.now().hour) {
            in 5 until 13 -> "dashboard.greeting.morning"
            in 13 until 20 -> "dashboard.greeting.afternoon"
            else -> "dashboard.greeting.evening"
        }

    val priorityDays: Int get() = _snapshot.value?.priority?.givenAt?.let { daysBetween(it).coerceAtLeast(0) } ?: 0
    val totalGivenThisWeek: Int get() = _snapshot.value?.activity?.sumOf { it.givenCount } ?: 0
    val totalReturnedThisWeek: Int get() = _snapshot.value?.activity?.sumOf { it.returnedCount } ?: 0

    val canEditTransactions: Boolean
        get() {
            val role = TokenManager.getToken()?.let { JWTHelper.getUserRole(it) }
            return role == UserRole.SuperAdmin || role == UserRole.Admin
        }

    suspend fun deleteTransaction(event: TransactionEvent) {
        if (!canEditTransactions) return
        try {
            val handle = api.deleteTransactionUndoable(event.transaction.id).handle(UndoHandleKind.Domain)
            ToastManager.show("dashboard.delete_transaction_success", ToastStyle.Success, handle, handle.toastDurationMillis)
            AppEvents.post(AppEvent.TerritoryDataChanged)
        } catch (e: Exception) {
            errorMessage.value = "Error deleting transaction: ${e.localizedMessage}"
        }
    }

    suspend fun fetchDataForEdit(): Pair<List<Person>, List<Territory>> = coroutineScope {
        val persons = async { api.getPersons(null) }
        val territories = async { api.getTerritories(orderBy = 1, ascending = true) }
        persons.await() to territories.await()
    }
}
