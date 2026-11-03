package com.jared.territorytool.core.network

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents

/**
 * Sesión persistida. A diferencia de iOS (UserDefaults), aquí va cifrada con
 * EncryptedSharedPreferences respaldado por el Android Keystore.
 */
object TokenManager {
    private const val KEY = "authToken"
    private const val REFRESH_KEY = "authRefreshToken"
    private const val USER_NAME_KEY = "authUserName"
    private const val ROLE_KEY = "authUserRole"
    private const val ACTIVE_CONGREGATION_KEY = "activeCongregationId"
    private const val CONGREGATIONS_KEY = "congregationsJSON"

    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        prefs = try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                context,
                "session",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            // Keystore corrupto (p. ej. tras restaurar copia): se empieza sin sesión.
            context.deleteSharedPreferences("session")
            context.getSharedPreferences("session_fallback", Context.MODE_PRIVATE)
        }
    }

    /** Persiste la sesión completa y **después** publica un único `AuthChanged`. */
    fun saveSession(
        token: String,
        refreshToken: String?,
        userName: String?,
        role: String?,
        activeCongregationId: String?,
        congregationsJson: String?,
    ) {
        prefs.edit().apply {
            putString(KEY, token)
            refreshToken?.let { putString(REFRESH_KEY, it) }
            userName?.let { putString(USER_NAME_KEY, it) }
            role?.let { putString(ROLE_KEY, it) }
            if (activeCongregationId != null) putString(ACTIVE_CONGREGATION_KEY, activeCongregationId)
            else remove(ACTIVE_CONGREGATION_KEY)
            congregationsJson?.let { putString(CONGREGATIONS_KEY, it) }
        }.commit()
        AppEvents.post(AppEvent.AuthChanged)
    }

    fun saveToken(token: String) {
        prefs.edit().putString(KEY, token).commit()
        AppEvents.post(AppEvent.AuthChanged)
    }

    fun saveRefreshToken(token: String?) {
        token?.let { prefs.edit().putString(REFRESH_KEY, it).commit() }
    }

    fun getRefreshToken(): String? = prefs.getString(REFRESH_KEY, null)

    fun saveActiveCongregationId(id: String?) {
        prefs.edit().apply {
            if (id != null) putString(ACTIVE_CONGREGATION_KEY, id) else remove(ACTIVE_CONGREGATION_KEY)
        }.apply()
    }

    fun getActiveCongregationId(): String? = prefs.getString(ACTIVE_CONGREGATION_KEY, null)

    fun saveCongregations(json: String?) {
        json?.let { prefs.edit().putString(CONGREGATIONS_KEY, it).apply() }
    }

    fun getCongregationsJson(): String? = prefs.getString(CONGREGATIONS_KEY, null)

    fun getToken(): String? = prefs.getString(KEY, null)

    fun clearToken() {
        prefs.edit().clear().commit()
        AppEvents.post(AppEvent.AuthChanged)
    }

    fun getUserName(): String? = prefs.getString(USER_NAME_KEY, null)

    fun getUserRole(): String? = prefs.getString(ROLE_KEY, null)

    val isAuthenticated: Boolean get() = getToken() != null
}
