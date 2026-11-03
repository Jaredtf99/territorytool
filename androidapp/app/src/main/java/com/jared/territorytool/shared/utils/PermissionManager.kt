package com.jared.territorytool.shared.utils

import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.network.TokenManager
import com.jared.territorytool.shared.models.UserRole
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Única fuente de verdad de roles/capacidades, a partir del JWT. */
object PermissionManager {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val role = MutableStateFlow<UserRole?>(null)
    val currentUserRole: StateFlow<UserRole?> = role

    fun init() {
        reload()
        scope.launch { AppEvents.of(AppEvent.AuthChanged).collect { reload() } }
    }

    private fun reload() {
        role.value = TokenManager.getToken()?.let { JWTHelper.getUserRole(it) }
    }

    val isAuthenticated get() = role.value != null
    val isAdminOrHigher get() = role.value == UserRole.SuperAdmin || role.value == UserRole.Admin
    val canManageTerritories get() = isAdminOrHigher
    val canRefreshTerritoryImage get() = isAdminOrHigher
    val canManageBrothers get() = isAdminOrHigher
    val canManageUsers get() = isAdminOrHigher
    val canViewActionLogs get() = role.value == UserRole.SuperAdmin
    val canManageCongregations get() = role.value == UserRole.SuperAdmin
}
