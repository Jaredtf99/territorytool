package com.jared.territorytool.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.jared.territorytool.R
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.network.NetworkError
import com.jared.territorytool.core.network.SupabaseAuthService
import com.jared.territorytool.core.network.TokenManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class LoginViewModel : ViewModel() {
    val userName = MutableStateFlow("")
    val password = MutableStateFlow("")
    val isLoading = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)

    fun login(onFinished: (success: Boolean) -> Unit) {
        if (userName.value.isEmpty() || password.value.isEmpty()) {
            errorMessage.value = "Please enter username and password"
            onFinished(false)
            return
        }
        isLoading.value = true
        errorMessage.value = null
        viewModelScope.launch {
            try {
                val response = SupabaseAuthService.login(userName.value, password.value)
                TokenManager.saveSession(
                    token = response.token,
                    refreshToken = response.session.refreshToken,
                    userName = response.profile?.username,
                    role = response.profile?.role,
                    activeCongregationId = response.profile?.activeCongregationId,
                    congregationsJson = response.congregations?.let(SupabaseAuthService::encodeCongregations),
                )
                // Este ViewModel sobrevive al cierre de sesión: que el formulario vuelva vacío, como en iOS.
                userName.value = ""
                password.value = ""
                onFinished(true)
            } catch (e: Exception) {
                val raw = e.localizedMessage.orEmpty()
                errorMessage.value = when {
                    // El backend devuelve el JSON crudo ({"error":"WRONG_USERNAME_PASSWORD"}).
                    "WRONG_USERNAME_PASSWORD" in raw -> Strings.get(R.string.error_wrong_credentials)
                    e is NetworkError.Offline -> raw
                    else -> "Login failed: $raw"
                }
                onFinished(false)
            } finally {
                isLoading.value = false
            }
        }
    }
}
