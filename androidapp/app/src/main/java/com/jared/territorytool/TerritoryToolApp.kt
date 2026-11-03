package com.jared.territorytool

import android.app.Application
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.jared.territorytool.core.CongregationStore
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.LanguageManager
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.ThemeManager
import com.jared.territorytool.core.TokenRefreshWorker
import com.jared.territorytool.core.network.TokenManager
import com.jared.territorytool.shared.utils.PermissionManager
import org.maplibre.android.MapLibre

class TerritoryToolApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Strings.init(this)
        TokenManager.init(this)
        LanguageManager.init(this)
        ThemeManager.init(this)
        HapticManager.init(this)
        PermissionManager.init()
        CongregationStore.init()
        MapLibre.getInstance(this)

        // Asegura que hay un refresco en segundo plano programado desde el arranque y al
        // pasar a segundo plano.
        TokenRefreshWorker.scheduleNext(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStop(owner: LifecycleOwner) = TokenRefreshWorker.scheduleNext(this@TerritoryToolApp)
        })
    }
}
