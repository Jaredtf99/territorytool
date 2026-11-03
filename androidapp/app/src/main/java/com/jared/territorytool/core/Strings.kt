package com.jared.territorytool.core

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import androidx.annotation.StringRes
import java.util.Locale

/**
 * Acceso a textos fuera de Compose (errores, toasts). Respeta el idioma elegido en
 * Ajustes, igual que `String.localized` en iOS.
 */
@SuppressLint("StaticFieldLeak")
object Strings {
    private lateinit var appContext: Context

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    private val context: Context
        get() {
            val locale = LanguageManager.currentLanguage.value.locale ?: return appContext
            val config = Configuration(appContext.resources.configuration).apply { setLocale(locale) }
            return appContext.createConfigurationContext(config)
        }

    fun get(@StringRes id: Int, vararg args: Any): String =
        if (args.isEmpty()) context.getString(id) else context.getString(id, *args)

    /** Convierte una clave de iOS (`dashboard.title`) en el recurso Android equivalente. */
    @SuppressLint("DiscouragedApi")
    fun resId(key: String): Int =
        appContext.resources.getIdentifier(key.replace(Regex("[^A-Za-z0-9_]"), "_"), "string", appContext.packageName)

    /** Texto para una clave dinámica; si no existe, devuelve la clave tal cual (como iOS). */
    fun key(key: String, vararg args: Any): String {
        val id = resId(key)
        return if (id == 0) key else get(id, *args)
    }

    fun hasKey(key: String): Boolean = resId(key) != 0

    val currentLocale: Locale
        get() = LanguageManager.currentLanguage.value.locale ?: appContext.resources.configuration.locales[0]
}
