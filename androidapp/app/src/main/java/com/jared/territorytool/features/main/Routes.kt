package com.jared.territorytool.features.main

import com.jared.territorytool.core.navigation.Route
import com.jared.territorytool.features.dashboard.DashboardMovement
import com.jared.territorytool.features.dashboard.DashboardViewModel
import com.jared.territorytool.features.dashboard.WeeklyActivityFilter

data object SettingsRoute : Route
data object ChangePasswordRoute : Route
data object CongregationsRoute : Route
data object UsersRoute : Route
data object DeactivatedUsersRoute : Route
data object TerritoryReportRoute : Route
data class TerritoryDetailRoute(val territoryId: Int, val territoryName: String) : Route
data class BrotherDetailRoute(val personId: Int, val personName: String) : Route
data class WeeklyActivityRoute(
    val events: List<DashboardMovement>,
    val viewModel: DashboardViewModel,
    val initialFilter: WeeklyActivityFilter = WeeklyActivityFilter.All,
) : Route
data class MovementHistoryRoute(val actionViewModel: DashboardViewModel) : Route
