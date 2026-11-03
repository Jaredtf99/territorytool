package com.jared.territorytool.core

import android.content.Context
import androidx.annotation.StringRes
import com.jared.territorytool.R
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class AppTheme(val raw: String, @StringRes val title: Int) {
    System("system", R.string.settings_theme_system),
    Light("light", R.string.settings_theme_light),
    Dark("dark", R.string.settings_theme_dark),
}

object ThemeManager {
    private const val KEY = "appTheme"
    private val state = MutableStateFlow(AppTheme.System)
    val currentTheme: StateFlow<AppTheme> = state
    private lateinit var context: Context

    fun init(context: Context) {
        this.context = context.applicationContext
        val saved = prefs().getString(KEY, AppTheme.System.raw)
        state.value = AppTheme.entries.firstOrNull { it.raw == saved } ?: AppTheme.System
    }

    fun set(theme: AppTheme) {
        state.value = theme
        prefs().edit().putString(KEY, theme.raw).apply()
    }

    private fun prefs() = context.getSharedPreferences("settings", Context.MODE_PRIVATE)
}
