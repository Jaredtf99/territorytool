package com.jared.territorytool.core.network

import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.config.AppConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.net.ConnectException
import java.net.NoRouteToHostException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Transporte HTTP. Inyecta autenticación, gestiona el 401 con un único reintento tras
 * refrescar la sesión y parsea fuera del hilo principal.
 */
object NetworkTransport {
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val jsonMedia = "application/json".toMediaType()

    fun makeRequest(
        path: String,
        method: String,
        query: List<Pair<String, String>> = emptyList(),
        body: JsonElement? = null,
    ): Request {
        val url = (AppConfig.SUPABASE_URL + path).toHttpUrlOrNull()?.newBuilder()?.apply {
            query.forEach { (k, v) -> addQueryParameter(k, v) }
        }?.build() ?: throw NetworkError.InvalidUrl()

        val requestBody = when {
            body != null -> body.toString().toRequestBody(jsonMedia)
            method == "GET" -> null
            else -> "{}".toRequestBody(jsonMedia)
        }
        return Request.Builder()
            .url(url)
            .method(method, requestBody)
            .header("apikey", AppConfig.SUPABASE_PUBLISHABLE_KEY)
            .header("Content-Type", "application/json")
            .header("Accept", "application/json")
            .build()
    }

    /** Ejecuta la petición y devuelve el JSON (o `JsonObject` vacío si no hay cuerpo). */
    suspend fun json(request: Request): JsonElement = withContext(Dispatchers.IO) {
        val text = send(request, allowRefresh = true)
        if (text.isBlank()) JsonObject(emptyMap())
        else runCatching { SupabaseJson.parseToJsonElement(text) }.getOrElse {
            if (text.trim() == "null") JsonNull else throw NetworkError.Decoding()
        }
    }

    private suspend fun send(request: Request, allowRefresh: Boolean): String {
        val bearer = TokenManager.getToken() ?: AppConfig.SUPABASE_PUBLISHABLE_KEY
        val authorized = request.newBuilder().header("Authorization", "Bearer $bearer").build()

        val (code, text) = client.newCall(authorized).await().use { it.code to (it.body?.string() ?: "") }
        if (code in 200..299) return text

        if (code == 401) {
            // El access token probablemente ha caducado: canjeamos el refresh token y
            // repetimos una vez. Sólo si el propio refresco falla, la sesión expira.
            if (allowRefresh && TokenManager.getRefreshToken() != null) {
                val refreshed = runCatching { SessionRefresher.refresh() }.isSuccess
                if (refreshed) return send(request, allowRefresh = false)
            }
            AppEvents.post(AppEvent.SessionExpired)
            throw NetworkError.Unauthorized()
        }
        throw NetworkError.Server(errorMessage(text) ?: "Status code: $code")
    }

    fun errorMessage(text: String): String? {
        val obj = runCatching { SupabaseJson.parseToJsonElement(text) as? JsonObject }.getOrNull()
            ?: return text.ifBlank { null }
        return obj.str("message") ?: obj.str("error") ?: obj.str("msg") ?: obj.str("hint")
    }
}

suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) = cont.resume(response)
        override fun onFailure(call: Call, e: IOException) {
            if (cont.isCancelled) return
            // Mensaje legible en vez del técnico de OkHttp ("Unable to resolve host…").
            val offline = !call.isCanceled() &&
                (e is UnknownHostException || e is ConnectException || e is SocketTimeoutException || e is NoRouteToHostException)
            cont.resumeWithException(if (offline) NetworkError.Offline() else e)
        }
    })
    cont.invokeOnCancellation { runCatching { cancel() } }
}
