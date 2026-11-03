package com.jared.territorytool.features.dashboard

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Sort
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.EventBusy
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.SearchOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.ContentUnavailable
import com.jared.territorytool.designsystem.FilterChip
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.SegmentedControl
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.shared.components.SearchField
import kotlinx.coroutines.launch

enum class WeeklyActivityFilter(@StringRes val title: Int) {
    All(R.string.dashboard_week_filter_all),
    Given(R.string.dashboard_week_filter_given),
    Returned(R.string.dashboard_week_filter_returned),
}

@Composable
fun WeeklyActivityScreen(events: List<DashboardMovement>, viewModel: DashboardViewModel, initialFilter: WeeklyActivityFilter) {
    val navigator = LocalNavigator.current
    val snapshot by viewModel.snapshot.collectAsStateWithLifecycle()
    var filter by rememberSaveable { mutableStateOf(initialFilter) }
    var editingEvent by remember { mutableStateOf<TransactionEvent?>(null) }
    var eventToDelete by remember { mutableStateOf<TransactionEvent?>(null) }
    val scope = rememberCoroutineScope()

    val source = snapshot?.weeklyEvents ?: events
    val filtered = when (filter) {
        WeeklyActivityFilter.All -> source
        WeeklyActivityFilter.Given -> source.filter { it.eventType == DashboardMovementType.Given }
        WeeklyActivityFilter.Returned -> source.filter { it.eventType == DashboardMovementType.Returned }
    }

    AppScreen(stringResource(R.string.dashboard_week_activity), onBack = navigator::pop) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                start = AppSpacing.md, end = AppSpacing.md, top = AppSpacing.xs, bottom = AppSpacing.xl + LocalTabBarPadding.current,
            ),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        ) {
            item {
                SegmentedControl(WeeklyActivityFilter.entries, filter, { stringResource(it.title) }, { filter = it }, Modifier.padding(bottom = AppSpacing.xs))
            }
            if (filtered.isEmpty()) {
                item { ContentUnavailable(stringResource(R.string.dashboard_no_weekly_activity), Icons.Rounded.EventBusy) }
            } else {
                items(filtered, key = { it.id }) { movement ->
                    MovementSwipeRow(movement, viewModel.canEditTransactions, { editingEvent = movement.transactionEvent }, { eventToDelete = movement.transactionEvent })
                }
            }
        }
    }

    editingEvent?.let { EditTransactionSheet(it, onDismiss = { editingEvent = null }, onComplete = { viewModel.loadDashboard() }) }
    eventToDelete?.let { event ->
        DeleteTransactionAlert(onConfirm = {
            eventToDelete = null
            scope.launch { viewModel.deleteTransaction(event) }
        }, onDismiss = { eventToDelete = null })
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MovementHistoryScreen(actionViewModel: DashboardViewModel, viewModel: MovementHistoryViewModel = viewModel()) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val movements by viewModel.movements.collectAsStateWithLifecycle()
    val search by viewModel.searchText.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val sort by viewModel.sort.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isLoadingMore by viewModel.isLoadingMore.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var editingEvent by remember { mutableStateOf<TransactionEvent?>(null) }
    var eventToDelete by remember { mutableStateOf<TransactionEvent?>(null) }
    var sortMenu by remember { mutableStateOf(false) }
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    AppScreen(
        stringResource(R.string.movements_title),
        onBack = navigator::pop,
        actions = {
            Box {
                GlassIconButton(Icons.AutoMirrored.Rounded.Sort, stringResource(R.string.movements_sort_title), { sortMenu = true }, tint = colors.accentDeep)
                DropdownMenu(sortMenu, { sortMenu = false }, Modifier.background(colors.surfaceRaised)) {
                    MovementHistorySort.entries.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(stringResource(option.title)) },
                            trailingIcon = { if (option == sort) Icon(Icons.Rounded.Check, null, tint = colors.accent) },
                            onClick = { sortMenu = false; viewModel.sort.value = option },
                        )
                    }
                }
            }
        },
    ) {
        SearchField(search, { viewModel.searchText.value = it }, stringResource(R.string.movements_search), Modifier.padding(horizontal = AppSpacing.md))
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = { refreshing = true; scope.launch { viewModel.load(reset = true); refreshing = false } },
            modifier = Modifier.fillMaxSize(),
        ) {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = AppSpacing.md, end = AppSpacing.md, top = AppSpacing.xs, bottom = AppSpacing.xl + LocalTabBarPadding.current,
                ),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs), modifier = Modifier.padding(vertical = AppSpacing.xs)) {
                        items(MovementHistoryFilter.entries) { option ->
                            val selected = option == filter
                            FilterChip(
                                stringResource(option.title),
                                selected,
                                onClick = { HapticManager.selection(); viewModel.filter.value = option },
                                icon = if (option == MovementHistoryFilter.All) Icons.Rounded.Layers else null,
                                tint = colors.accent,
                            )
                        }
                    }
                }
                when {
                    isLoading && movements.isEmpty() -> item {
                        Box(Modifier.fillMaxWidth().padding(AppSpacing.lg), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.accent) }
                    }
                    movements.isEmpty() -> item {
                        ContentUnavailable(stringResource(R.string.common_no_results), Icons.Rounded.SearchOff, description = search.ifBlank { null })
                    }
                    else -> {
                        items(movements, key = { it.id }) { movement ->
                            androidx.compose.runtime.LaunchedEffect(movement.id) { viewModel.loadMoreIfNeeded(movement) }
                            MovementSwipeRow(
                                movement,
                                actionViewModel.canEditTransactions,
                                { editingEvent = movement.transactionEvent },
                                { eventToDelete = movement.transactionEvent },
                            )
                        }
                        if (isLoadingMore) item {
                            Box(Modifier.fillMaxWidth().padding(AppSpacing.md), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.accent) }
                        }
                    }
                }
            }
        }
    }

    editingEvent?.let {
        EditTransactionSheet(it, onDismiss = { editingEvent = null }, onComplete = {
            actionViewModel.loadDashboard()
            viewModel.reload()
        })
    }
    eventToDelete?.let { event ->
        DeleteTransactionAlert(onConfirm = {
            eventToDelete = null
            scope.launch {
                actionViewModel.deleteTransaction(event)
                viewModel.load(reset = true)
            }
        }, onDismiss = { eventToDelete = null })
    }
    error?.let {
        AppAlert(stringResource(R.string.common_error), it, stringResource(R.string.common_ok), { viewModel.errorMessage.value = null }, { viewModel.errorMessage.value = null }, dismissText = null)
    }
}

