package com.jared.territorytool.features.users

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.core.network.TokenManager
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.models.User
import com.jared.territorytool.shared.models.UserRole
import com.jared.territorytool.shared.utils.JWTHelper
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class UsersViewModel(private val api: ApiService = DIContainer.apiService) : ViewModel() {
    private val _users = MutableStateFlow<List<User>>(emptyList())
    val users: StateFlow<List<User>> = _users
    val searchText = MutableStateFlow("")
    val isLoading = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    val deactivatedUsers = MutableStateFlow<List<User>>(emptyList())
    val isLoadingDeactivated = MutableStateFlow(false)
    val deactivatedErrorMessage = MutableStateFlow<String?>(null)

    /** Lista filtrada derivada de `users` + `searchText`. */
    val filteredUsers: StateFlow<List<User>> = combine(_users, searchText) { list, query ->
        if (query.isEmpty()) list else list.filter { it.userName.contains(query, ignoreCase = true) }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val currentUserRole: UserRole? get() = TokenManager.getToken()?.let { JWTHelper.getUserRole(it) }

    init {
        viewModelScope.launch {
            AppEvents.flow.collect { event ->
                when (event) {
                    AppEvent.CongregationChanged -> { _users.value = emptyList(); fetchUsers() }
                    AppEvent.UserDataChanged -> fetchUsers()
                    else -> Unit
                }
            }
        }
        viewModelScope.launch { fetchUsers() }
    }

    suspend fun fetchUsers() {
        isLoading.value = true
        errorMessage.value = null
        try {
            _users.value = api.getUsers().sortedBy { it.userName }
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = e.localizedMessage
        }
        isLoading.value = false
    }

    suspend fun addUser(name: String, role: UserRole, password: String): Boolean = mutate {
        val handle = api.addUserUndoable(name, role.raw, password).handle(UndoHandleKind.User)
        ToastManager.show("users.add_success", ToastStyle.Success, handle, handle.toastDurationMillis)
        fetchUsers()
    }

    suspend fun updateUser(user: User, newName: String, newRole: UserRole): Boolean = mutate {
        val handle = api.updateUserUndoable(user.id, newName, newRole.raw).handle(UndoHandleKind.User)
        ToastManager.show("users.update_success", ToastStyle.Success, handle, handle.toastDurationMillis)
        fetchUsers()
    }

    suspend fun changePassword(user: User, newPassword: String): Boolean = mutate {
        api.changeUserPassword(user.id, newPassword)
        ToastManager.show("users.change_password_success", ToastStyle.Success)
        isLoading.value = false
    }

    suspend fun deleteUser(user: User) {
        mutate {
            val handle = api.deleteUserUndoable(user.id).handle(UndoHandleKind.User)
            ToastManager.show("users.delete_success", ToastStyle.Success, handle, handle.toastDurationMillis)
            fetchUsers()
        }
    }

    private suspend fun mutate(block: suspend () -> Unit): Boolean {
        isLoading.value = true
        errorMessage.value = null
        return try {
            block()
            true
        } catch (e: Exception) {
            errorMessage.value = e.localizedMessage
            ToastManager.show(e.localizedMessage ?: "", ToastStyle.Error)
            isLoading.value = false
            false
        }
    }

    /** Cuentas desactivadas que el usuario actual puede reactivar (el backend ya filtra). */
    suspend fun fetchDeactivatedUsers() {
        isLoadingDeactivated.value = true
        deactivatedErrorMessage.value = null
        try {
            deactivatedUsers.value = api.getDeactivatedUsers().sortedBy { it.userName }
        } catch (e: Exception) {
            if (!e.isCancellation) deactivatedErrorMessage.value = e.localizedMessage
        }
        isLoadingDeactivated.value = false
    }

    suspend fun reactivateUser(user: User) {
        try {
            api.reactivateUser(user.id)
            deactivatedUsers.value = deactivatedUsers.value.filterNot { it.id == user.id }
            ToastManager.show("users.reactivate_success", ToastStyle.Success)
            fetchUsers()
        } catch (e: Exception) {
            ToastManager.show(e.localizedMessage ?: "", ToastStyle.Error)
        }
    }

    // MARK: - Permisos

    /** Nadie gestiona a un SUPERADMIN; un ADMIN sólo gestiona USER. */
    fun canEdit(user: User): Boolean {
        val role = currentUserRole ?: return false
        if (user.role == UserRole.SuperAdmin) return false
        return when (role) {
            UserRole.SuperAdmin -> true
            UserRole.Admin -> user.role == UserRole.User
            UserRole.User -> false
        }
    }

    fun canDelete(user: User) = canEdit(user)
    fun canChangePassword(user: User) = canEdit(user)

    fun availableRolesForAssignment(): List<UserRole> = when (currentUserRole) {
        UserRole.SuperAdmin -> listOf(UserRole.Admin, UserRole.User)
        UserRole.Admin -> listOf(UserRole.User)
        else -> emptyList()
    }
}
