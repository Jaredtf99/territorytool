package com.jared.territorytool.core

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.Locale

enum class AppLanguage(val raw: String, val displayName: String) {
    System("system", "System"),
    English("en", "English"),
    Spanish("es", "Español");

    val locale: Locale? get() = if (this == System) null else Locale(raw)
}

object LanguageManager {
    private const val KEY = "appLanguage"
    private val state = MutableStateFlow(AppLanguage.System)
    val currentLanguage: StateFlow<AppLanguage> = state
    private lateinit var context: Context

    fun init(context: Context) {
        this.context = context.applicationContext
        val saved = prefs().getString(KEY, AppLanguage.System.raw)
        state.value = AppLanguage.entries.firstOrNull { it.raw == saved } ?: AppLanguage.System
    }

    fun set(language: AppLanguage) {
        state.value = language
        prefs().edit().putString(KEY, language.raw).apply()
        val locales = if (language == AppLanguage.System) LocaleListCompat.getEmptyLocaleList()
        else LocaleListCompat.forLanguageTags(language.raw)
        AppCompatDelegate.setApplicationLocales(locales)
    }

    private fun prefs() = context.getSharedPreferences("settings", Context.MODE_PRIVATE)
}
