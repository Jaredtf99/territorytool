package com.jared.territorytool.core

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.jared.territorytool.core.network.SessionRefresher
import com.jared.territorytool.core.network.TokenManager
import java.util.concurrent.TimeUnit

/**
 * Mantiene viva la sesión de Supabase refrescando el token cada ~5 días en segundo
 * plano (equivalente a `TokenRefreshScheduler` con BGTaskScheduler en iOS). Es un
 * respaldo: el 401 → refresh del transporte arregla la sesión igualmente.
 */
class TokenRefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (TokenManager.getRefreshToken() == null) return Result.success()
        return if (runCatching { SessionRefresher.refresh() }.isSuccess) Result.success() else Result.retry()
    }

    companion object {
        private const val NAME = "com.jared.TerritoryTool.tokenrefresh"

        fun scheduleNext(context: Context) {
            if (TokenManager.getRefreshToken() == null) return
            val request = PeriodicWorkRequestBuilder<TokenRefreshWorker>(5, TimeUnit.DAYS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }
    }
}
