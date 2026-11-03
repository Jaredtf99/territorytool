package com.jared.territorytool.features.main

import androidx.compose.runtime.Composable
import com.jared.territorytool.core.navigation.Route
import com.jared.territorytool.features.dashboard.MovementHistoryScreen
import com.jared.territorytool.features.dashboard.WeeklyActivityScreen
import com.jared.territorytool.features.reports.TerritoryReportScreen
import com.jared.territorytool.features.settings.ChangePasswordScreen
import com.jared.territorytool.features.settings.CongregationsManagementScreen
import com.jared.territorytool.features.settings.SettingsScreen
import com.jared.territorytool.features.territories.detail.TerritoryDetailScreen
import com.jared.territorytool.features.users.UsersScreen

/** Resuelve cada `Route` a su pantalla (equivale a los `NavigationLink` de iOS). */
@Composable
fun Destination(route: Route) {
    when (route) {
        is WeeklyActivityRoute -> WeeklyActivityScreen(route.events, route.viewModel, route.initialFilter)
        is MovementHistoryRoute -> MovementHistoryScreen(route.actionViewModel)
        is TerritoryDetailRoute -> TerritoryDetailScreen(route.territoryId, route.territoryName)
        SettingsRoute -> SettingsScreen()
        ChangePasswordRoute -> ChangePasswordScreen()
        CongregationsRoute -> CongregationsManagementScreen()
        UsersRoute -> UsersScreen()
        TerritoryReportRoute -> TerritoryReportScreen()
        else -> Unit
    }
}
