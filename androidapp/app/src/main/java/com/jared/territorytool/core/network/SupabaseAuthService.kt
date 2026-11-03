package com.jared.territorytool.core.network

import com.jared.territorytool.core.config.AppConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.JsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

@Serializable
data class SupabaseLoginResponse(
    val token: String,
    val session: SupabaseSession,
    val profile: SupabaseProfile? = null,
    val congregations: List<CongregationSummary>? = null,
)

@Serializable
data class SupabaseSession(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
)

@Serializable
data class SupabaseProfile(
    val id: String,
    val username: String,
    val role: String,
    @SerialName("must_change_password") val mustChangePassword: Boolean = false,
    @SerialName("is_superadmin") val isSuperadmin: Boolean? = null,
    @SerialName("active_congregation_id") val activeCongregationId: String? = null,
)

@Serializable
data class CongregationSummary(
    val id: String,
    val name: String,
    val role: String,
    @SerialName("is_active") val isActive: Boolean = false,
)

@Serializable
private data class RefreshResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
)

object SupabaseAuthService {
    private val jsonMedia = "application/json".toMediaType()

    fun encodeCongregations(list: List<CongregationSummary>): String =
        SupabaseJson.encodeToString(ListSerializer(CongregationSummary.serializer()), list)

    fun decodeCongregations(json: String): List<CongregationSummary> =
        runCatching { SupabaseJson.decodeFromString(ListSerializer(CongregationSummary.serializer()), json) }
            .getOrDefault(emptyList())

    suspend fun login(username: String, password: String): SupabaseLoginResponse {
        val request = Request.Builder()
            .url("${AppConfig.SUPABASE_URL}/functions/v1/login-with-username")
            .post(jsonBody("username" to username, "password" to password).toString().toRequestBody(jsonMedia))
            .header("apikey", AppConfig.SUPABASE_PUBLISHABLE_KEY)
            .header("Authorization", "Bearer ${AppConfig.SUPABASE_PUBLISHABLE_KEY}")
            .build()
        val text = execute(request, authorized = false)
        return runCatching { SupabaseJson.decodeFromString(SupabaseLoginResponse.serializer(), text) }
            .getOrElse { throw NetworkError.Decoding() }
    }

    /** Cambia la congregación activa y refresca el JWT para que los claims se actualicen. */
    suspend fun setActiveCongregation(congregationId: String): String {
        callRpc("set_active_congregation", jsonBody("p_congregation_id" to congregationId))
        return refreshSession()
    }

    suspend fun getMyCongregations(): List<CongregationSummary> {
        val text = execute(authorizedRequest("/rest/v1/rpc/get_my_congregations", "POST", JsonObject(emptyMap())), true)
        return decodeCongregations(text)
    }

    suspend fun changeOwnPassword(newPassword: String) {
        execute(authorizedRequest("/auth/v1/user", "PUT", jsonBody("password" to newPassword)), true)
    }

    suspend fun createCongregation(name: String) = callRpc("create_congregation", jsonBody("p_name" to name))

    suspend fun renameCongregation(id: String, name: String) =
        callRpc("rename_congregation", jsonBody("p_congregation_id" to id, "p_name" to name))

    suspend fun deleteCongregation(id: String) = callRpc("delete_congregation", jsonBody("p_congregation_id" to id))

    /** Canjea el refresh token guardado por un access token nuevo. */
    suspend fun refreshSession(): String {
        val refreshToken = TokenManager.getRefreshToken() ?: throw NetworkError.Unauthorized()
        val request = Request.Builder()
            .url("${AppConfig.SUPABASE_URL}/auth/v1/token?grant_type=refresh_token")
            .post(jsonBody("refresh_token" to refreshToken).toString().toRequestBody(jsonMedia))
            .header("apikey", AppConfig.SUPABASE_PUBLISHABLE_KEY)
            .build()
        val text = execute(request, authorized = false)
        val refreshed = SupabaseJson.decodeFromString(RefreshResponse.serializer(), text)
        TokenManager.saveRefreshToken(refreshed.refreshToken)
        TokenManager.saveToken(refreshed.accessToken)
        return refreshed.accessToken
    }

    private suspend fun callRpc(name: String, body: JsonObject) {
        execute(authorizedRequest("/rest/v1/rpc/$name", "POST", body), true)
    }

    private fun authorizedRequest(path: String, method: String, body: JsonObject): Request {
        val bearer = TokenManager.getToken() ?: AppConfig.SUPABASE_PUBLISHABLE_KEY
        return Request.Builder()
            .url(AppConfig.SUPABASE_URL + path)
            .method(method, body.toString().toRequestBody(jsonMedia))
            .header("apikey", AppConfig.SUPABASE_PUBLISHABLE_KEY)
            .header("Authorization", "Bearer $bearer")
            .build()
    }

    private suspend fun execute(request: Request, authorized: Boolean): String = withContext(Dispatchers.IO) {
        NetworkTransport.client.newCall(request).await().use { response ->
            val text = response.body?.string() ?: ""
            if (response.code !in 200..299) {
                if (authorized && response.code == 401) throw NetworkError.Unauthorized()
                throw NetworkError.Server(text.ifBlank { "Status code: ${response.code}" })
            }
            text
        }
    }
}
