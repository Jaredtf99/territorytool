package com.jared.territorytool.core

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.core.network.SignedImageUrlCache
import com.jared.territorytool.core.network.TokenManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class AppViewModel : ViewModel() {
    private val _isAuthenticated = MutableStateFlow(TokenManager.isAuthenticated)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated
    private val _showSessionExpired = MutableStateFlow(false)
    val showSessionExpiredAlert: StateFlow<Boolean> = _showSessionExpired

    init {
        viewModelScope.launch {
            AppEvents.flow.collect { event ->
                when (event) {
                    AppEvent.AuthChanged -> {
                        SignedImageUrlCache.removeAll()
                        checkAuth()
                    }
                    AppEvent.CongregationChanged -> SignedImageUrlCache.removeAll()
                    AppEvent.UserRequestedLogout -> logout()
                    AppEvent.SessionExpired -> _showSessionExpired.value = true
                    else -> Unit
                }
            }
        }
    }

    fun checkAuth() {
        _isAuthenticated.value = TokenManager.isAuthenticated
    }

    fun logout() {
        TokenManager.clearToken()
        _isAuthenticated.value = false
        _showSessionExpired.value = false
    }
}
