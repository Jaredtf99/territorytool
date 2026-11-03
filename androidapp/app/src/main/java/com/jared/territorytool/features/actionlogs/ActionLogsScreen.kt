package com.jared.territorytool.features.actionlogs

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Assignment
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.PersonRemove
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Send
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppColors
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.models.ActionLog
import com.jared.territorytool.shared.models.ActionType
import com.jared.territorytool.shared.utils.isCancellation
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class ActionLogsViewModel(private val api: ApiService = DIContainer.apiService) : ViewModel() {
    val logs = MutableStateFlow<List<ActionLog>>(emptyList())
    val isLoading = MutableStateFlow(false)
    val isLoadingMore = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    private var canLoadMore = true
    private var currentPage = 1
    private val pageSize = 20

    init {
        viewModelScope.launch { AppEvents.of(AppEvent.CongregationChanged).collect { loadLogs(reset = true) } }
        viewModelScope.launch { loadLogs(reset = true) }
    }

    suspend fun loadLogs(reset: Boolean = false) {
        if (reset) {
            currentPage = 1
            canLoadMore = true
            // Las filas actuales se mantienen hasta que llega la página nueva.
            isLoading.value = true
        } else {
            if (isLoadingMore.value || !canLoadMore) return
            isLoadingMore.value = true
        }
        errorMessage.value = null
        try {
            val response = api.getActionLogs(currentPage, pageSize, "DateUtc", "desc")
            logs.value = if (reset) response.data else logs.value + response.data
            val lastPage = response.lastPage
            if (lastPage != null) {
                if (currentPage >= lastPage) canLoadMore = false else currentPage += 1
            } else {
                if (response.data.size < pageSize) canLoadMore = false else currentPage += 1
            }
        } catch (e: Exception) {
            if (!e.isCancellation) errorMessage.value = e.localizedMessage
        }
        if (reset) isLoading.value = false else isLoadingMore.value = false
    }

    fun loadMoreIfNeeded(item: ActionLog) {
        if (item.id == logs.value.lastOrNull()?.id) viewModelScope.launch { loadLogs(reset = false) }
    }
}

@Composable
fun ActionLogsScreen(viewModel: ActionLogsViewModel = viewModel()) {
    val colors = AppTheme.colors
    val logs by viewModel.logs.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isLoadingMore by viewModel.isLoadingMore.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    AppScreen(stringResource(R.string.actionlogs_title)) {
        when {
            isLoading && logs.isEmpty() -> Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                CircularProgressIndicator(color = colors.accent)
                Text(stringResource(R.string.common_loading), style = AppType.body, color = colors.textSecondary, modifier = Modifier.padding(top = AppSpacing.sm))
            }
            logs.isEmpty() -> Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically)) {
                Icon(Icons.AutoMirrored.Rounded.Assignment, null, Modifier.size(60.dp), tint = colors.textSecondary.copy(alpha = 0.6f))
                Text(stringResource(R.string.actionlogs_empty), style = AppType.title3.copy(fontWeight = FontWeight.Medium), color = colors.textSecondary)
            }
            else -> PullToRefreshBox(
                refreshing,
                onRefresh = { refreshing = true; scope.launch { viewModel.loadLogs(reset = true); refreshing = false } },
                modifier = Modifier.fillMaxSize(),
            ) {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = AppSpacing.md, end = AppSpacing.md, top = 6.dp, bottom = AppSpacing.xl + LocalTabBarPadding.current),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(logs, key = { it.id }) { log ->
                        LaunchedEffect(log.id) { viewModel.loadMoreIfNeeded(log) }
                        ActionLogGlassRow(log)
                    }
                    if (isLoadingMore) item {
                        Box(Modifier.fillMaxWidth().padding(AppSpacing.md), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.accent) }
                    }
                }
            }
        }
    }

    error?.let {
        AppAlert(stringResource(R.string.common_error), it, stringResource(R.string.common_ok), { viewModel.errorMessage.value = null }, { viewModel.errorMessage.value = null }, dismissText = null)
    }
}

@Composable
private fun ActionLogGlassRow(log: ActionLog) {
    val colors = AppTheme.colors
    var expanded by rememberSaveable(log.id) { mutableStateOf(false) }
    val tint = log.type.color(colors)
    val shape = RoundedCornerShape(20.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(8.dp, shape, ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.05f))
            .background(colors.surface.copy(alpha = 0.92f), shape)
            .border(1.dp, Color.White.copy(alpha = if (colors.isDark) 0.06f else 0.3f), shape)
            .padding(16.dp)
            .animateContentSize(spring(dampingRatio = 0.7f, stiffness = 500f)),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(44.dp).background(tint.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(log.type.icon(), null, Modifier.size(22.dp), tint = tint)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(log.type.title()), style = AppType.body.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Rounded.Person, null, Modifier.size(11.dp), tint = colors.textSecondary)
                    Text(log.userName ?: stringResource(R.string.common_unknown), style = AppType.caption.copy(fontWeight = FontWeight.Medium), color = colors.textSecondary)
                    Text("•", style = AppType.caption2, color = colors.textSecondary.copy(alpha = 0.5f))
                    Text(DateFormats.relative(log.dateUtc), style = AppType.caption, color = colors.textSecondary)
                }
            }
            if (!log.successful) Icon(Icons.Rounded.Warning, null, Modifier.size(14.dp), tint = colors.warning)
        }
        val message = log.message
        if (!message.isNullOrEmpty()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(colors.textPrimary.copy(alpha = 0.03f), RoundedCornerShape(12.dp))
                    .clickable { expanded = !expanded }
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(message, style = AppType.subheadline, color = colors.textPrimary.copy(alpha = 0.8f), maxLines = if (expanded) Int.MAX_VALUE else 1)
                if (!expanded && message.length > 50) {
                    Text(stringResource(R.string.common_see_more), style = AppType.caption2.copy(fontWeight = FontWeight.Bold), color = colors.accent, modifier = Modifier.padding(top = 2.dp))
                }
            }
        }
    }
}

private fun ActionType.title(): Int = when (this) {
    ActionType.AddTerritory -> R.string.actionlogs_type_add_territory
    ActionType.EditTerritory -> R.string.actionlogs_type_edit_territory
    ActionType.DeleteTerritory -> R.string.actionlogs_type_delete_territory
    ActionType.AddUser -> R.string.actionlogs_type_add_user
    ActionType.DeleteUser -> R.string.actionlogs_type_delete_user
    ActionType.ChangeUserPassword -> R.string.actionlogs_type_change_password
    ActionType.EditUser -> R.string.actionlogs_type_edit_user
    ActionType.AddPerson -> R.string.actionlogs_type_add_person
    ActionType.EditPerson -> R.string.actionlogs_type_edit_person
    ActionType.DeletePerson -> R.string.actionlogs_type_delete_person
    ActionType.GiveTerritory -> R.string.actionlogs_type_give_territory
    ActionType.PickTerritory -> R.string.actionlogs_type_pick_territory
    ActionType.RefreshTerritoryImage -> R.string.actionlogs_type_refresh_image
    ActionType.EditTransaction -> R.string.actionlogs_type_edit_transaction
    ActionType.DeleteTransaction -> R.string.actionlogs_type_delete_transaction
    ActionType.Unknown -> R.string.actionlogs_type_unknown
}

private fun ActionType.icon(): ImageVector = when (this) {
    ActionType.AddTerritory, ActionType.EditTerritory, ActionType.DeleteTerritory -> Icons.Rounded.Map
    ActionType.GiveTerritory -> Icons.Rounded.Send
    ActionType.PickTerritory -> Icons.Rounded.MoveToInbox
    ActionType.RefreshTerritoryImage -> Icons.Rounded.Refresh
    ActionType.AddUser -> Icons.Rounded.PersonAdd
    ActionType.EditUser -> Icons.Rounded.AccountCircle
    ActionType.DeleteUser -> Icons.Rounded.PersonRemove
    ActionType.ChangeUserPassword -> Icons.Rounded.Key
    ActionType.AddPerson, ActionType.EditPerson, ActionType.DeletePerson -> Icons.Rounded.Groups
    ActionType.EditTransaction, ActionType.DeleteTransaction -> Icons.Rounded.SwapHoriz
    ActionType.Unknown -> Icons.Rounded.Settings
}

private fun ActionType.color(colors: AppColors): Color = when (this) {
    ActionType.AddTerritory, ActionType.AddPerson, ActionType.AddUser -> colors.success
    ActionType.EditTerritory, ActionType.EditPerson, ActionType.EditUser, ActionType.ChangeUserPassword,
    ActionType.RefreshTerritoryImage, ActionType.EditTransaction -> colors.warning
    ActionType.DeleteTerritory, ActionType.DeletePerson, ActionType.DeleteUser, ActionType.DeleteTransaction -> colors.danger
    ActionType.GiveTerritory -> colors.accent
    ActionType.PickTerritory -> colors.accentSecondary
    ActionType.Unknown -> colors.textSecondary
}
