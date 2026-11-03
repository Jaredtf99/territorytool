package com.jared.territorytool.features.territories.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.PriorityHigh
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.AppRouter
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppTopBar
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CountUpText
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.GradientIconCircle
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.Rounded
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.designsystem.rememberStatusPresentation
import com.jared.territorytool.features.dashboard.DeleteTransactionAlert
import com.jared.territorytool.features.dashboard.EditTransactionSheet
import com.jared.territorytool.features.dashboard.TransactionEvent
import com.jared.territorytool.features.quickaction.QuickActionResolution
import com.jared.territorytool.features.territories.EditTerritorySheet
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.components.DeliveryFormatBadge
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.models.TerritoryDetail
import com.jared.territorytool.shared.models.Transaction
import com.jared.territorytool.shared.models.daysBetween
import com.jared.territorytool.shared.utils.PermissionManager
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
fun TerritoryDetailScreen(territoryId: Int, @Suppress("UNUSED_PARAMETER") territoryName: String) {
    val viewModel: TerritoryDetailViewModel = viewModel(factory = TerritoryDetailViewModel.Factory(territoryId))
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val territory by viewModel.territory.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val transactions by viewModel.transactions.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    val refreshingImage by viewModel.isRefreshingImage.collectAsStateWithLifecycle()
    val role by PermissionManager.currentUserRole.collectAsStateWithLifecycle()
    val canManage = remember(role) { PermissionManager.canManageTerritories }
    var showDelete by remember { mutableStateOf(false) }
    var showEdit by remember { mutableStateOf(false) }
    var editingTransaction by remember { mutableStateOf<Transaction?>(null) }
    var transactionToDelete by remember { mutableStateOf<Transaction?>(null) }
    var menu by remember { mutableStateOf(false) }
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val scroll = rememberScrollState()

    // La acción principal fija sustituye a la barra de pestañas.
    DisposableEffect(Unit) {
        AppRouter.tabBarHidden.value = true
        onDispose { AppRouter.tabBarHidden.value = false }
    }

    Box(Modifier.fillMaxSize()) {
        LiquidBackground()
        val current = territory
        when {
            isLoading && current == null -> DetailLoadingState()
            error != null && current == null -> Column(
                Modifier.fillMaxSize().padding(AppSpacing.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(AppSpacing.md, Alignment.CenterVertically),
            ) {
                Icon(Icons.Rounded.Warning, null, Modifier.size(50.dp), tint = colors.warning)
                Text(stringResource(R.string.territory_detail_error), style = AppType.appTitle, color = colors.textPrimary)
                Text(error!!, style = AppType.appSubheadline, color = colors.textSecondary, textAlign = TextAlign.Center)
                AppButton(stringResource(R.string.territory_detail_retry), { viewModel.reload() }, tint = colors.accentDeep, large = true)
            }
            current != null -> {
                PullToRefreshBox(refreshing, onRefresh = { refreshing = true; scope.launch { viewModel.loadData(); refreshing = false } }, Modifier.fillMaxSize()) {
                    Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(bottom = 110.dp)) {
                        HeroHeader(current, stats?.globalAverageHoldingTime, scroll.value, Modifier.appear(0))
                        Column(Modifier.padding(horizontal = AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.lg)) {
                            TrajectorySection(
                                transactions, stats, canManage,
                                onEdit = { editingTransaction = it },
                                onDelete = { transactionToDelete = it },
                                modifier = Modifier.appear(1),
                            )
                            stats?.let { TerritoryStatsSection(it, transactions, Modifier.appear(2)) }
                        }
                    }
                }
                BottomAction(current, Modifier.align(Alignment.BottomCenter))
            }
        }

        AppTopBar(
            title = null,
            onBack = navigator::pop,
            actions = if (canManage) ({
                Box {
                    if (refreshingImage) {
                        Box(Modifier.size(40.dp).glass(CircleShape), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(Modifier.size(18.dp), color = colors.accentDeep, strokeWidth = 2.dp)
                        }
                    } else {
                        GlassIconButton(Icons.Rounded.MoreHoriz, stringResource(R.string.territory_detail_menu_accessibility), { menu = true }, tint = colors.accentDeep)
                    }
                    DropdownMenu(menu, { menu = false }, Modifier.background(colors.surfaceRaised)) {
                        val successMsg = stringResource(R.string.territory_detail_refresh_image_success)
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.territory_detail_menu_refresh_map)) },
                            leadingIcon = { Icon(Icons.Rounded.Refresh, null) },
                            enabled = !refreshingImage,
                            onClick = {
                                menu = false
                                HapticManager.selection()
                                scope.launch {
                                    if (viewModel.refreshImage()) {
                                        HapticManager.notification(HapticManager.Notification.Success)
                                        ToastManager.show(successMsg, ToastStyle.Success)
                                    } else HapticManager.notification(HapticManager.Notification.Error)
                                }
                            },
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.territory_detail_edit)) },
                            leadingIcon = { Icon(Icons.Rounded.Edit, null) },
                            onClick = { menu = false; showEdit = true },
                        )
                        HorizontalDivider(color = colors.hairline)
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.territory_detail_delete), color = colors.danger) },
                            leadingIcon = { Icon(Icons.Rounded.Delete, null, tint = colors.danger) },
                            onClick = { menu = false; showDelete = true },
                        )
                    }
                }
            }) else null,
        )
    }

    if (showDelete) {
        val successMsg = stringResource(R.string.territory_delete_success)
        AppAlert(
            stringResource(R.string.territory_detail_delete_confirmation_title),
            stringResource(R.string.territory_detail_delete_confirmation_message),
            stringResource(R.string.territory_detail_delete),
            onConfirm = {
                showDelete = false
                scope.launch {
                    if (viewModel.deleteTerritory()) {
                        val handle = viewModel.lastUndoHandle
                        ToastManager.show(successMsg, ToastStyle.Success, handle, handle?.toastDurationMillis ?: 3000)
                        AppEvents.post(AppEvent.TerritoryDeleted)
                        navigator.pop()
                    } else HapticManager.notification(HapticManager.Notification.Error)
                }
            },
            onDismiss = { showDelete = false },
            dismissText = stringResource(R.string.cancel),
            destructive = true,
        )
    }
    transactionToDelete?.let { tx ->
        DeleteTransactionAlert(onConfirm = {
            transactionToDelete = null
            scope.launch {
                if (viewModel.deleteTransaction(tx.id)) {
                    val handle = viewModel.lastUndoHandle
                    ToastManager.show("dashboard.delete_transaction_success", ToastStyle.Success, handle, handle?.toastDurationMillis ?: 3000)
                }
            }
        }, onDismiss = { transactionToDelete = null })
    }
    if (showEdit) {
        territory?.let { t ->
            EditTerritorySheet(t.id, t.code, t.name, t.mapUrl, onDismiss = { showEdit = false }, onSuccess = { viewModel.reload() })
        }
    }
    editingTransaction?.let { tx ->
        EditTransactionSheet(
            TransactionEvent(tx.id, TransactionEvent.EventType.Given, tx.givenDateUtc, tx),
            onDismiss = { editingTransaction = null },
            onComplete = { viewModel.loadData() },
        )
    }
}

/** Cabecera: mapa real a sangre por detrás de la barra (con parallax), código, estado, días y responsable. */
@Composable
private fun HeroHeader(territory: TerritoryDetail, globalAverageHolding: Double?, scrollY: Int, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val density = LocalDensity.current
    val isAssigned = territory.personName != null
    val reference = if (isAssigned) territory.givenDateUtc else territory.lastPickedDateUtc
    val presentation = rememberStatusPresentation(territory.toTerritory().operationalStatus())
    val days = reference?.let { daysBetween(it).coerceAtLeast(0) }
    val topInset = with(density) { WindowInsets.statusBars.getTop(this).toDp() } + 52.dp

    Box(modifier.fillMaxWidth()) {
        territory.mapGeometry?.let { geometry ->
            TerritorySnapshotBackdrop(
                geometry,
                Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        // Parallax: el mapa acompaña al contenido a un 60 % de su velocidad.
                        translationY = scrollY * 0.4f
                        compositingStrategy = CompositingStrategy.Offscreen
                    }
                    .drawWithContent {
                        drawContent()
                        drawRect(
                            Brush.horizontalGradient(0f to Color.Transparent, 0.30f to Color.Black.copy(alpha = 0.45f), 0.55f to Color.Black, 1f to Color.Black),
                            blendMode = BlendMode.DstIn,
                        )
                        drawRect(
                            Brush.verticalGradient(0f to Color.Black, 0.75f to Color.Black, 1f to Color.Transparent),
                            blendMode = BlendMode.DstIn,
                        )
                    },
                stroke = presentation.color,
                fill = presentation.color,
                verticalBias = 0.16,
                distanceMultiplier = 4.2,
                horizontalShift = 0.28,
            )
        }
        Column(
            Modifier.padding(horizontal = AppSpacing.md).padding(top = topInset + AppSpacing.sm, bottom = AppSpacing.md),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        ) {
            Text(territory.code, style = TextStyle(fontFamily = Rounded, fontSize = 48.sp, fontWeight = FontWeight.Black), color = colors.accentDeep, maxLines = 1)
            Text(territory.name, style = AppType.title2.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary, maxLines = 2, modifier = Modifier.padding(end = 150.dp))

            // Chip de estado.
            Row(
                Modifier
                    .padding(top = AppSpacing.xxs)
                    .background(presentation.color.copy(alpha = 0.10f), CircleShape)
                    .border(1.dp, presentation.color.copy(alpha = 0.35f), CircleShape)
                    .padding(horizontal = AppSpacing.sm, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(AppSpacing.xxs),
            ) {
                Box(Modifier.size(7.dp).background(presentation.color, CircleShape))
                Text(presentation.title, style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = presentation.color)
            }

            // Días del ciclo (o de descanso si está libre).
            Column(Modifier.padding(top = AppSpacing.md), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    stringResource(if (isAssigned) R.string.territory_detail_cycle_started_label else R.string.territory_detail_available_label),
                    style = AppType.appSubheadline,
                    color = colors.textSecondary,
                )
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    CountUpText(days ?: 0, style = TextStyle(fontFamily = Rounded, fontSize = 44.sp, fontWeight = FontWeight.Black))
                    Text(stringResource(R.string.common_days), style = AppType.appHeadline, color = colors.textSecondary, modifier = Modifier.padding(bottom = 8.dp))
                }
                Text(
                    reference?.let { stringResource(R.string.territory_detail_cycle_since_date, DateFormats.abbreviated(it)) }
                        ?: stringResource(R.string.territory_detail_available_never),
                    style = AppType.appCaption,
                    color = colors.textSecondary,
                )
            }

            territory.personName?.let { person ->
                Row(
                    Modifier.padding(top = AppSpacing.xs).fillMaxWidth().glass(RoundedCornerShape(AppRadius.lg)).padding(AppSpacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
                ) {
                    InitialsAvatar(person, size = 40.dp, tint = colors.accentDeep)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(person, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1)
                        Text(stringResource(R.string.territory_detail_cycle_responsible), style = AppType.appCaption, color = colors.textSecondary)
                    }
                    territory.deliveryFormat?.let { DeliveryFormatBadge(it) }
                }
            }

            // Aviso cuando el ciclo supera la media de la congregación.
            val average = globalAverageHolding?.roundToInt() ?: 0
            if (isAssigned && days != null && average > 0 && days > average) {
                Row(
                    Modifier
                        .padding(top = AppSpacing.xs)
                        .fillMaxWidth()
                        .background(colors.accentTertiary.copy(alpha = 0.14f), RoundedCornerShape(AppRadius.lg))
                        .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(AppRadius.lg))
                        .bounceClick {
                            HapticManager.selection()
                            AppRouter.openQuickAction(QuickActionResolution.ForTerritory(territory.toTerritory()))
                        }
                        .padding(AppSpacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
                ) {
                    GradientIconCircle(Icons.Rounded.PriorityHigh, colors.accentTertiary, size = 30.dp, iconSize = 14.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(stringResource(R.string.territory_detail_cycle_review_title), style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.accentTertiary)
                        Text(stringResource(R.string.territory_detail_cycle_review_avg, average), style = AppType.appCaption, color = colors.textSecondary)
                    }
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.size(16.dp), tint = colors.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun BottomAction(territory: TerritoryDetail, modifier: Modifier) {
    val colors = AppTheme.colors
    val free = territory.personName == null
    Box(modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = AppSpacing.md).padding(top = AppSpacing.xs, bottom = AppSpacing.sm)) {
        AppButton(
            stringResource(if (free) R.string.territory_detail_assign else R.string.territory_detail_return),
            {
                HapticManager.selection()
                AppRouter.openQuickAction(QuickActionResolution.ForTerritory(territory.toTerritory()))
            },
            icon = if (free) Icons.AutoMirrored.Rounded.Send else Icons.Rounded.MoveToInbox,
            tint = if (free) colors.accent else colors.accentSecondary,
            large = true,
            fillWidth = true,
            textStyle = AppType.appHeadline,
        )
    }
}

/** Esqueleto con la silueta de la pantalla real. */
@Composable
private fun DetailLoadingState() {
    val colors = AppTheme.colors
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(top = 52.dp).padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.lg)) {
        Box {
            Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Box(Modifier.size(150.dp, 44.dp).background(colors.surface, RoundedCornerShape(AppRadius.sm)))
                Box(Modifier.size(190.dp, 24.dp).background(colors.surface, RoundedCornerShape(AppRadius.sm)))
                Box(Modifier.size(96.dp, 28.dp).background(colors.surface, CircleShape))
                Box(Modifier.padding(top = AppSpacing.md).size(130.dp, 58.dp).background(colors.surface, RoundedCornerShape(AppRadius.sm)))
                Box(Modifier.padding(top = AppSpacing.xs).fillMaxWidth().height(64.dp).background(colors.surface, RoundedCornerShape(AppRadius.lg)))
            }
            CircularProgressIndicator(Modifier.align(Alignment.Center), color = colors.accent)
        }
        Row(Modifier.padding(top = AppSpacing.md), horizontalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            repeat(4) { Box(Modifier.size(68.dp).background(colors.surface, CircleShape)) }
        }
        Box(Modifier.fillMaxWidth().height(72.dp).background(colors.surface, RoundedCornerShape(AppRadius.lg)))
        Box(Modifier.fillMaxWidth().height(96.dp).background(colors.surface, RoundedCornerShape(AppRadius.lg)))
    }
}
