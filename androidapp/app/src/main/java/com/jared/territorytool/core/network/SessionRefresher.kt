package com.jared.territorytool.core.network

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Coordina los refrescos de token: varios 401 concurrentes (o el refresco en segundo
 * plano a la vez que una petición) comparten una única llamada a GoTrue.
 */
object SessionRefresher {
    private val mutex = Mutex()
    private var inFlight: CompletableDeferred<String>? = null

    suspend fun refresh(): String {
        val (deferred, owner) = mutex.withLock {
            inFlight?.let { it to false } ?: CompletableDeferred<String>().also { inFlight = it }.let { it to true }
        }
        if (owner) {
            try {
                deferred.complete(SupabaseAuthService.refreshSession())
            } catch (e: Throwable) {
                deferred.completeExceptionally(e)
            } finally {
                mutex.withLock { inFlight = null }
            }
        }
        return deferred.await()
    }
}
