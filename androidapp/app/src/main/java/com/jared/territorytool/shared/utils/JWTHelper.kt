package com.jared.territorytool.shared.utils

import android.util.Base64
import com.jared.territorytool.core.network.SupabaseJson
import com.jared.territorytool.core.network.TokenManager
import com.jared.territorytool.core.network.bool
import com.jared.territorytool.core.network.str
import com.jared.territorytool.shared.models.UserRole
import kotlinx.serialization.json.JsonObject

object JWTHelper {
    private const val ROLE_CLAIM = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"

    fun getUserRole(token: String): UserRole? {
        val claims = decode(token) ?: return null
        val role = claims.str("app_role") ?: claims.str("role") ?: claims.str(ROLE_CLAIM)
        UserRole.from(role)?.let { return it }
        return UserRole.from(TokenManager.getUserRole())
    }

    fun getUserName(token: String): String? {
        val claims = decode(token) ?: return null
        return claims.str("UserName") ?: claims.str("unique_name") ?: claims.str("name")
            ?: claims.str("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name")
            ?: TokenManager.getUserName()
    }

    fun getCongregationId(token: String): String? =
        decode(token)?.str("congregation_id") ?: TokenManager.getActiveCongregationId()

    fun isSuperadmin(token: String): Boolean = decode(token)?.bool("is_superadmin") ?: false

    private fun decode(jwt: String): JsonObject? {
        val segments = jwt.split(".")
        if (segments.size < 2) return null
        return runCatching {
            val bytes = Base64.decode(segments[1], Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
            SupabaseJson.parseToJsonElement(String(bytes)) as? JsonObject
        }.getOrNull()
    }
}
