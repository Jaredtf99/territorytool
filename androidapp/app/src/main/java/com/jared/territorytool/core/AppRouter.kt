package com.jared.territorytool.core

import com.jared.territorytool.features.quickaction.QuickActionResolution
import com.jared.territorytool.features.territories.TerritoryFilter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class AppTab { Dashboard, Territories, Brothers, ActionLogs, Settings, QuickAction }

enum class TerritoriesPresentation { List, Map }

data class TerritoriesLaunchContext(
    val filter: TerritoryFilter,
    val presentation: TerritoriesPresentation,
    val attentionDays: Int,
) {
    companion object {
        val Free = TerritoriesLaunchContext(TerritoryFilter.Free, TerritoriesPresentation.List, 90)
        val InUse = TerritoriesLaunchContext(TerritoryFilter.InUse, TerritoriesPresentation.List, 90)
        val Attention = TerritoriesLaunchContext(TerritoryFilter.Attention, TerritoriesPresentation.List, 90)
    }
}

/** Navegación global (pestaña activa, lanzamientos contextuales y Acción rápida). */
object AppRouter {
    val selectedTab = MutableStateFlow(AppTab.Dashboard)
    private val _launchContext = MutableStateFlow<TerritoriesLaunchContext?>(null)
    val territoriesLaunchContext: StateFlow<TerritoriesLaunchContext?> = _launchContext
    private val _quickActionPresented = MutableStateFlow(false)
    val isQuickActionPresented: StateFlow<Boolean> = _quickActionPresented
    var quickActionInitialResolution: QuickActionResolution? = null
        private set

    /** Oculta la barra de pestañas (mapa a pantalla completa). */
    val tabBarHidden = MutableStateFlow(false)

    /** Peticiones para volver a la raíz de una pestaña (equivale a vaciar su `NavigationPath`). */
    val popToRootRequests = MutableStateFlow<Pair<AppTab, Long>?>(null)

    fun openTerritories(context: TerritoriesLaunchContext) {
        _launchContext.value = context
        popToRoot(AppTab.Territories)
        selectedTab.value = AppTab.Territories
    }

    fun popToRoot(tab: AppTab) {
        popToRootRequests.value = tab to System.nanoTime()
    }

    fun openQuickAction(resolution: QuickActionResolution? = null) {
        quickActionInitialResolution = resolution
        _quickActionPresented.value = true
    }

    fun closeQuickAction() {
        quickActionInitialResolution = null
        _quickActionPresented.value = false
    }

    fun consumeTerritoriesLaunchContext(): TerritoriesLaunchContext? =
        _launchContext.value.also { _launchContext.value = null }
}
