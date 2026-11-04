package com.jared.territorytool.features.main

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material.icons.automirrored.rounded.Assignment
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.AppRouter
import com.jared.territorytool.core.AppTab
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.NavStackHost
import com.jared.territorytool.core.navigation.Navigator
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.features.actionlogs.ActionLogsScreen
import com.jared.territorytool.features.brothers.BrothersScreen
import com.jared.territorytool.features.dashboard.DashboardScreen
import com.jared.territorytool.features.quickaction.QuickActionHubView
import com.jared.territorytool.features.territories.TerritoriesScreen
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastMessage
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.utils.PermissionManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Alto reservado por la barra de pestañas flotante (para no tapar contenido). */
val LocalTabBarPadding = staticCompositionLocalOf { 0.dp }
val TabBarHeight: Dp = 64.dp

/**
 * Navegación raíz: pestañas con su propia pila, botón de Acción rápida separado a la
 * derecha (pestaña de rol `.search` en iOS 26) y toasts con deshacer.
 */
@Composable
fun MainTabView() {
    val colors = AppTheme.colors
    val selectedTab by AppRouter.selectedTab.collectAsStateWithLifecycle()
    val quickActionPresented by AppRouter.isQuickActionPresented.collectAsStateWithLifecycle()
    val role by PermissionManager.currentUserRole.collectAsStateWithLifecycle()
    val canViewLogs = remember(role) { PermissionManager.canViewActionLogs }

    val navigators = remember { AppTab.entries.associateWith { Navigator() } }
    val holder = rememberSaveableStateHolder()
    val popRequest by AppRouter.popToRootRequests.collectAsStateWithLifecycle()
    LaunchedEffect(popRequest) { popRequest?.first?.let { navigators[it]?.popToRoot() } }

    // Toasts
    val pending by ToastManager.pendingMessage.collectAsStateWithLifecycle()
    var visibleToast by remember { mutableStateOf<ToastMessage?>(null) }
    var isUndoing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    var dismissJob by remember { mutableStateOf<Job?>(null) }

    fun present(message: ToastMessage) {
        when (message.style) {
            ToastStyle.Success -> HapticManager.notification(HapticManager.Notification.Success)
            ToastStyle.Error -> HapticManager.notification(HapticManager.Notification.Error)
            ToastStyle.Warning -> HapticManager.notification(HapticManager.Notification.Warning)
            ToastStyle.Info -> HapticManager.impact(HapticManager.Impact.Light)
        }
        dismissJob?.cancel()
        isUndoing = false
        visibleToast = message
        ToastManager.clearPending()
        dismissJob = scope.launch {
            val millis = message.undoHandle?.let { it.expiresAt.toEpochMilli() - System.currentTimeMillis() } ?: message.durationMillis
            delay(millis.coerceAtLeast(100))
            if (visibleToast == message) visibleToast = null
        }
    }

    fun undoVisibleToast() {
        val handle = visibleToast?.undoHandle ?: return
        if (isUndoing) return
        isUndoing = true
        dismissJob?.cancel()
        scope.launch {
            val result = runCatching {
                when (handle.kind) {
                    UndoHandleKind.Domain -> DIContainer.apiService.undoAction(handle.id)
                    UndoHandleKind.User -> DIContainer.apiService.undoUserAction(handle.id)
                }
            }
            AppEvents.post(AppEvent.TerritoryDataChanged)
            if (handle.kind == UndoHandleKind.User) AppEvents.post(AppEvent.UserDataChanged)
            visibleToast = null
            isUndoing = false
            delay(120)
            result.onSuccess { ToastManager.show("undo.success", ToastStyle.Success) }
                .onFailure { e ->
                    val expired = e.localizedMessage?.contains("UNDO_EXPIRED", ignoreCase = true) == true
                    ToastManager.show(if (expired) "undo.expired" else "undo.failed", ToastStyle.Error)
                }
        }
    }

    LaunchedEffect(pending) { pending?.let(::present) }

    val tabs = buildList {
        add(TabItem(AppTab.Dashboard, R.string.dashboard_title, Icons.Outlined.Home, Icons.Rounded.Home))
        add(TabItem(AppTab.Territories, R.string.territories_title, Icons.Outlined.Map, Icons.Rounded.Map))
        add(TabItem(AppTab.Brothers, R.string.brothers_title, Icons.Outlined.Groups, Icons.Rounded.Groups))
        if (canViewLogs) add(TabItem(AppTab.ActionLogs, R.string.tab_logs, Icons.AutoMirrored.Outlined.Assignment, Icons.AutoMirrored.Rounded.Assignment))
    }

    val currentNavigator = navigators.getValue(selectedTab)
    // Atrás en la raíz de una pestaña distinta del tablero vuelve al tablero.
    BackHandler(enabled = !quickActionPresented && currentNavigator.isAtRoot && selectedTab != AppTab.Dashboard) {
        AppRouter.selectedTab.value = AppTab.Dashboard
    }

    Box(Modifier.fillMaxSize().background(colors.appBackground)) {
        CompositionLocalProvider(LocalTabBarPadding provides TabBarHeight + AppSpacing.md) {
            holder.SaveableStateProvider(selectedTab.name) {
                val navigator = navigators.getValue(selectedTab)
                NavStackHost(navigator, enableBack = !quickActionPresented, root = {
                    when (selectedTab) {
                        AppTab.Dashboard -> DashboardScreen()
                        AppTab.Territories -> TerritoriesScreen()
                        AppTab.Brothers -> BrothersScreen()
                        AppTab.ActionLogs -> ActionLogsScreen()
                        else -> DashboardScreen()
                    }
                }) { route -> Destination(route) }
            }
        }

        val tabBarHidden by AppRouter.tabBarHidden.collectAsStateWithLifecycle()
        AnimatedVisibility(
            !tabBarHidden,
            enter = slideInVertically { it } + fadeIn(),
            exit = androidx.compose.animation.slideOutVertically { it } + fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
        FloatingTabBar(
            tabs = tabs,
            selected = selectedTab,
            onSelect = { tab ->
                if (tab == selectedTab) navigators.getValue(tab).popToRoot()
                else AppRouter.selectedTab.value = tab
                HapticManager.selection()
            },
            onQuickAction = {
                HapticManager.selection()
                AppRouter.openQuickAction()
            },
        )
        }

        AnimatedVisibility(
            visible = quickActionPresented,
            enter = scaleIn(spring(dampingRatio = 0.86f, stiffness = 300f), initialScale = 0.92f) + fadeIn(),
            exit = scaleOut(tween(220), targetScale = 0.94f) + fadeOut(tween(200)),
        ) {
            QuickActionHubView(
                initialResolution = AppRouter.quickActionInitialResolution,
                onClose = { AppRouter.closeQuickAction() },
                onComplete = {
                    // Tras entregar/recoger: cerrar y volver al tablero (raíz).
                    navigators.getValue(AppTab.Dashboard).popToRoot()
                    AppRouter.selectedTab.value = AppTab.Dashboard
                    AppRouter.closeQuickAction()
                },
            )
        }

        AnimatedVisibility(
            visible = visibleToast != null,
            enter = slideInVertically(spring(dampingRatio = 0.6f)) { it } + fadeIn() + scaleIn(initialScale = 0.96f),
            exit = fadeOut(tween(180)) + scaleOut(targetScale = 0.97f),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = TabBarHeight + AppSpacing.lg),
        ) {
            val toast = visibleToast
            if (toast != null) {
                ToastGlassMessageView(toast, isUndoing, onUndo = toast.undoHandle?.let { { undoVisibleToast() } })
            }
        }
    }
}

private data class TabItem(val tab: AppTab, val title: Int, val icon: ImageVector, val selectedIcon: ImageVector)

@Composable
private fun FloatingTabBar(
    tabs: List<TabItem>,
    selected: AppTab,
    onSelect: (AppTab) -> Unit,
    onQuickAction: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    // Opaca: con la sombra debajo, cualquier transparencia deja ver la lista que pasa por detrás.
    val barColor = colors.surfaceRaised
    val border = Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.7f)
    Row(
        modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = AppSpacing.md)
            .padding(bottom = AppSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Row(
            Modifier
                .weight(1f)
                .height(TabBarHeight)
                .shadow(14.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.18f), spotColor = Color.Black.copy(alpha = 0.18f))
                .clip(CircleShape)
                .background(barColor)
                .border(1.dp, border, CircleShape)
                .padding(4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEach { item ->
                val isSelected = item.tab == selected
                Column(
                    Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .clip(CircleShape)
                        .background(if (isSelected) colors.accentDeep.copy(alpha = 0.12f) else Color.Transparent)
                        .bounceClick { onSelect(item.tab) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    val tint = if (isSelected) colors.accentDeep else colors.textPrimary
                    Icon(if (isSelected) item.selectedIcon else item.icon, null, Modifier.size(24.dp), tint = tint)
                    Text(
                        stringResource(item.title),
                        style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold),
                        color = tint,
                        maxLines = 1,
                    )
                }
            }
        }

        val label = stringResource(R.string.quick_action_title)
        Box(
            Modifier
                .size(TabBarHeight)
                .shadow(14.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.18f), spotColor = Color.Black.copy(alpha = 0.18f))
                .clip(CircleShape)
                .background(barColor)
                .border(1.dp, border, CircleShape)
                .bounceClick(onClick = onQuickAction)
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.QrCodeScanner, null, Modifier.size(28.dp), tint = colors.accentDeep)
        }
    }
}
