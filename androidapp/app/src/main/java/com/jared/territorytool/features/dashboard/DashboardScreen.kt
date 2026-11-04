package com.jared.territorytool.features.dashboard

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.CardGiftcard
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.MonitorHeart
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.NorthEast
import androidx.compose.material.icons.rounded.SouthWest
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.AppRouter
import com.jared.territorytool.core.CongregationStore
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.TerritoriesLaunchContext
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppButtonStyle
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoEmptyState
import com.jared.territorytool.designsystem.ContentUnavailable
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.GradientIconCircle
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.Rounded
import com.jared.territorytool.designsystem.SwipeAction
import com.jared.territorytool.designsystem.SwipeActionsRow
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.blended
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.features.main.MovementHistoryRoute
import com.jared.territorytool.features.main.SettingsRoute
import com.jared.territorytool.features.main.TerritoryDetailRoute
import com.jared.territorytool.features.main.WeeklyActivityRoute
import com.jared.territorytool.features.quickaction.QuickActionResolution
import com.jared.territorytool.shared.components.CongregationSwitcher
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import kotlinx.coroutines.launch
import java.time.format.TextStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(viewModel: DashboardViewModel = viewModel()) {
    val navigator = LocalNavigator.current
    val snapshot by viewModel.snapshot.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var editingEvent by remember { mutableStateOf<TransactionEvent?>(null) }
    var eventToDelete by remember { mutableStateOf<TransactionEvent?>(null) }
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        if (viewModel.snapshot.value == null) viewModel.loadDashboard()
        CongregationStore.refresh()
    }

    AppScreen(
        title = null,
        leading = { CongregationSwitcher() },
        actions = {
            GlassIconButton(Icons.Outlined.Settings, stringResource(R.string.settings_title), { navigator.push(SettingsRoute) }, tint = AppTheme.colors.accentDeep)
        },
    ) {
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = {
                refreshing = true
                scope.launch { viewModel.loadDashboard().join(); refreshing = false }
            },
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = AppSpacing.md)
                    .padding(top = AppSpacing.xs, bottom = AppSpacing.xl + LocalTabBarPadding.current)
                    .navigationBarsPadding(),
                verticalArrangement = Arrangement.spacedBy(AppSpacing.lg),
            ) {
                DashboardHeader(viewModel.greetingKey, viewModel.userName, Modifier.appear(0))

                val current = snapshot
                when {
                    isLoading && current == null -> DashboardLoadingView()
                    error != null && current == null -> ContentUnavailable(
                        title = stringResource(R.string.common_error),
                        icon = Icons.Rounded.WifiOff,
                        description = error,
                        modifier = Modifier.heightIn(min = 380.dp),
                        actions = { AppButton(stringResource(R.string.common_retry), { viewModel.loadDashboard() }, style = AppButtonStyle.Bordered) },
                    )
                    current != null -> {
                        DailyPriorityCard(
                            current.priority,
                            viewModel.priorityDays,
                            onView = { p -> navigator.push(TerritoryDetailRoute(p.territoryId, p.name)) },
                            modifier = Modifier.appear(1),
                        )
                        TerritoryFlowView(
                            current.totals,
                            current.attentionTerritories.size,
                            onFree = { AppRouter.openTerritories(TerritoriesLaunchContext.Free) },
                            onGiven = { navigator.push(WeeklyActivityRoute(current.weeklyEvents, viewModel, WeeklyActivityFilter.Given)) },
                            onInUse = { AppRouter.openTerritories(TerritoriesLaunchContext.InUse) },
                            onAttention = { AppRouter.openTerritories(TerritoriesLaunchContext.Attention) },
                            modifier = Modifier.appear(2),
                        )
                        WeeklyActivityChart(
                            current.activity,
                            viewModel.totalGivenThisWeek,
                            viewModel.totalReturnedThisWeek,
                            Modifier.appear(3).bounceClick { navigator.push(WeeklyActivityRoute(current.weeklyEvents, viewModel)) },
                        )
                        RecentMovementsSection(
                            current.recentEvents,
                            showsSeeAll = current.hasMoreRecentEvents,
                            canEdit = viewModel.canEditTransactions,
                            onSeeAll = { navigator.push(MovementHistoryRoute(viewModel)) },
                            onEdit = { editingEvent = it.transactionEvent },
                            onDelete = { eventToDelete = it.transactionEvent },
                            modifier = Modifier.appear(4),
                        )
                    }
                }
            }
        }
    }

    editingEvent?.let { event ->
        EditTransactionSheet(event, onDismiss = { editingEvent = null }, onComplete = { viewModel.loadDashboard() })
    }
    eventToDelete?.let { event ->
        DeleteTransactionAlert(onConfirm = {
            eventToDelete = null
            scope.launch { viewModel.deleteTransaction(event) }
        }, onDismiss = { eventToDelete = null })
    }
}

@Composable
fun DeleteTransactionAlert(onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AppAlert(
        title = stringResource(R.string.common_delete_confirmation),
        message = stringResource(R.string.dashboard_delete_transaction_message),
        confirmText = stringResource(R.string.common_delete),
        onConfirm = onConfirm,
        onDismiss = onDismiss,
        destructive = true,
    )
}

@Composable
private fun DashboardHeader(greetingKey: String, userName: String, modifier: Modifier = Modifier) {
    val greeting = Strings.key(greetingKey)
    val firstName = userName.split(" ").firstOrNull().orEmpty()
    Text(
        if (firstName.isEmpty()) greeting else "$greeting, $firstName",
        style = AppType.title.copy(fontWeight = FontWeight.Bold),
        color = AppTheme.colors.accentDeep,
        maxLines = 1,
        modifier = modifier.fillMaxWidth(),
    )
}

@Composable
private fun DailyPriorityCard(
    priority: DashboardPriority?,
    days: Int,
    onView: (DashboardPriority) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val highlight = colors.accentSecondary

    @Composable
    fun PriorityLabel() {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            GradientIconCircle(Icons.Rounded.Star, highlight, size = 28.dp, iconSize = 13.dp)
            Text(stringResource(R.string.dashboard_priority_title), style = AppType.appSubheadline.copy(fontWeight = FontWeight.Bold), color = highlight)
        }
    }

    if (priority == null) {
        Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            PriorityLabel()
            CartoEmptyState(Icons.Rounded.Verified, stringResource(R.string.dashboard_priority_none_overdue))
        }
        return
    }

    val shape = RoundedCornerShape(AppRadius.xl)
    // Titular "AVxxx lleva N días asignado" con el tramo "N días" resaltado.
    val full = stringResource(R.string.dashboard_priority_headline, priority.code, days)
    val headline = buildAnnotatedString {
        val number = days.toString()
        val start = full.indexOf(number)
        if (start < 0) {
            append(full)
        } else {
            var end = start + number.length
            while (end < full.length && full[end] == ' ') end++
            while (end < full.length && full[end] != ' ') end++
            append(full.substring(0, start))
            withStyle(SpanStyle(color = highlight, fontWeight = FontWeight.ExtraBold)) { append(full.substring(start, end)) }
            append(full.substring(end))
        }
    }

    Box(
        modifier
            .fillMaxWidth()
            .shadow(14.dp, shape, ambientColor = colors.glassShadow, spotColor = colors.glassShadow)
            .clip(shape)
            .background(colors.surface)
            .border(1.dp, Brush.linearGradient(listOf(highlight.copy(alpha = 0.9f), highlight.copy(alpha = 0.65f))), shape),
    ) {
        priority.mapGeometry?.let { geometry ->
            // Mapa como fondo: nítido a la derecha y desvanecido hacia la izquierda.
            TerritorySnapshotBackdrop(
                geometry,
                Modifier
                    .matchParentSize()
                    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                    .drawWithContent {
                        drawContent()
                        drawRect(
                            Brush.horizontalGradient(
                                0f to Color.Transparent,
                                0.30f to Color.Black.copy(alpha = 0.5f),
                                0.55f to Color.Black,
                                1f to Color.Black,
                            ),
                            blendMode = BlendMode.DstIn,
                        )
                    },
                verticalBias = 0.22,
            )
        }
        Column(Modifier.padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Column(Modifier.padding(end = 104.dp), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                PriorityLabel()
                Text(headline, style = AppType.title2.copy(fontWeight = FontWeight.Bold), color = colors.accentDeep)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                    InitialsAvatar(priority.personName, size = 36.dp)
                    Text(priority.personName, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                AppButton(
                    stringResource(R.string.dashboard_priority_view),
                    { onView(priority) },
                    icon = Icons.Rounded.Map,
                    tint = colors.accentDeep,
                    large = true,
                )
                AppButton(
                    stringResource(R.string.dashboard_priority_return),
                    {
                        HapticManager.selection()
                        AppRouter.openQuickAction(QuickActionResolution.ForTerritory(priority.territory))
                    },
                    icon = Icons.Rounded.MoveToInbox,
                    tint = colors.accentSecondary,
                    style = AppButtonStyle.Glass,
                    large = true,
                )
            }
        }
    }
}

@Composable
private fun TerritoryFlowView(
    totals: DashboardTotals,
    attentionCount: Int,
    onFree: () -> Unit,
    onGiven: () -> Unit,
    onInUse: () -> Unit,
    onAttention: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Column(modifier.fillMaxWidth().paperCard(AppRadius.xl).padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            FlowMetric(totals.free, stringResource(R.string.dashboard_flow_free), colors.accentDeep, onFree)
            FlowMetric(totals.givenThisWeek, stringResource(R.string.dashboard_flow_given), colors.accentSecondary, onGiven)
            FlowMetric(totals.inUse, stringResource(R.string.dashboard_flow_in_use), colors.accentTertiary, onInUse)
            FlowMetric(attentionCount, stringResource(R.string.dashboard_flow_attention), colors.danger, onAttention)
        }
        FlowTrack()
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.FlowMetric(value: Int, label: String, tint: Color, onClick: () -> Unit) {
    Column(
        Modifier.weight(1f).bounceClick(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(value.toString(), style = androidx.compose.ui.text.TextStyle(fontFamily = Rounded, fontSize = 30.sp, fontWeight = FontWeight.Bold), color = tint)
        Text(label, style = AppType.caption.copy(fontWeight = FontWeight.SemiBold), color = tint, textAlign = TextAlign.Center, maxLines = 2)
    }
}

/** Vía continua con cuatro iconos conectados, alineados con las métricas. */
@Composable
private fun FlowTrack() {
    val colors = AppTheme.colors
    val tints = listOf(colors.accentDeep, colors.accentSecondary, colors.accentTertiary, colors.danger)
    val icons = listOf(Icons.Rounded.Eco, Icons.Rounded.CardGiftcard, Icons.Rounded.Groups, Icons.Rounded.Warning)
    BoxWithConstraints(Modifier.fillMaxWidth().height(54.dp)) {
        val w = maxWidth
        val centers = tints.indices.map { w * ((it + 0.5f) / tints.size) }
        Canvas(Modifier.fillMaxSize()) {
            val y = size.height / 2
            val cx = centers.map { it.toPx() }
            fun segment(x0: Float, x1: Float, from: Color, to: Color, dots: Boolean) {
                drawLine(Brush.horizontalGradient(listOf(from, to), x0, x1), Offset(x0, y), Offset(x1, y), 3.dp.toPx(), StrokeCap.Round)
                if (dots) {
                    val mid = (x0 + x1) / 2
                    val gap = 13.dp.toPx()
                    listOf(-1, 0, 1).forEachIndexed { i, k ->
                        drawCircle(from.blended(to, 0.25f * (i + 1)), 3.dp.toPx(), Offset(mid + k * gap, y))
                    }
                }
            }
            segment(0f, cx[0], tints[0], tints[0], false)
            for (i in 0 until tints.size - 1) segment(cx[i], cx[i + 1], tints[i], tints[i + 1], true)
            segment(cx.last(), size.width, tints.last(), tints.last(), false)
        }
        tints.forEachIndexed { i, tint ->
            Box(
                Modifier
                    .offset(x = centers[i] - 25.dp, y = 2.dp)
                    .size(50.dp)
                    .shadow(4.dp, CircleShape, ambientColor = tint.copy(alpha = 0.28f), spotColor = tint.copy(alpha = 0.28f))
                    .background(Brush.linearGradient(listOf(tint, tint.blended(Color.Black, 0.14f))), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icons[i], null, Modifier.size(20.dp), tint = Color.White)
            }
        }
    }
}

@Composable
private fun WeeklyActivityChart(activity: List<DashboardDailyActivity>, givenTotal: Int, returnedTotal: Int, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val givenColor = colors.accent
    val returnedColor = colors.accentSecondary
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) { progress.animateTo(1f, tween(800)) }

    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            Icon(Icons.Rounded.MonitorHeart, null, Modifier.size(18.dp), tint = colors.accent)
            Text(stringResource(R.string.dashboard_week_title), style = AppType.headline.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary)
        }
        Column(Modifier.fillMaxWidth().paperCard(AppRadius.xl).padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
                ActivityLegend(givenTotal, stringResource(R.string.dashboard_week_given), givenColor)
                ActivityLegend(returnedTotal, stringResource(R.string.dashboard_week_returned), returnedColor)
            }
            val maxValue = (activity.maxOfOrNull { maxOf(it.givenCount, it.returnedCount) } ?: 0).coerceAtLeast(1)
            Canvas(Modifier.fillMaxWidth().height(80.dp)) {
                if (activity.isEmpty()) return@Canvas
                val stepX = if (activity.size > 1) size.width / (activity.size - 1) else 0f
                fun points(values: List<Int>) = values.mapIndexed { i, v ->
                    Offset(i * stepX, size.height - (v * progress.value / maxValue) * (size.height - 6.dp.toPx()) - 3.dp.toPx())
                }
                val given = points(activity.map { it.givenCount })
                val returned = points(activity.map { it.returnedCount })
                val givenPath = monotonePath(given)
                val area = Path().apply {
                    addPath(givenPath)
                    lineTo(given.last().x, size.height)
                    lineTo(given.first().x, size.height)
                    close()
                }
                drawPath(area, Brush.verticalGradient(listOf(givenColor.copy(alpha = 0.25f), givenColor.copy(alpha = 0.02f))))
                drawPath(monotonePath(returned), returnedColor, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
                drawPath(givenPath, givenColor, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                activity.forEach { day ->
                    Text(
                        day.date.dayOfWeek.getDisplayName(TextStyle.NARROW, Strings.currentLocale),
                        style = AppType.caption2,
                        color = colors.textSecondary,
                    )
                }
            }
        }
    }
}

/** Interpolación cúbica monótona (Fritsch–Carlson), como `.interpolationMethod(.monotone)`. */
private fun monotonePath(points: List<Offset>): Path {
    val path = Path()
    if (points.isEmpty()) return path
    path.moveTo(points[0].x, points[0].y)
    if (points.size < 2) return path
    val n = points.size
    val dx = FloatArray(n - 1) { points[it + 1].x - points[it].x }
    val slope = FloatArray(n - 1) { if (dx[it] == 0f) 0f else (points[it + 1].y - points[it].y) / dx[it] }
    val tangent = FloatArray(n)
    tangent[0] = slope[0]
    tangent[n - 1] = slope[n - 2]
    for (i in 1 until n - 1) {
        tangent[i] = if (slope[i - 1] * slope[i] <= 0) 0f else 3 * (dx[i - 1] + dx[i]) /
            ((2 * dx[i] + dx[i - 1]) / slope[i - 1] + (dx[i] + 2 * dx[i - 1]) / slope[i])
    }
    for (i in 0 until n - 1) {
        val p0 = points[i]; val p1 = points[i + 1]
        val h = dx[i] / 3
        path.cubicTo(p0.x + h, p0.y + tangent[i] * h, p1.x - h, p1.y - tangent[i + 1] * h, p1.x, p1.y)
    }
    return path
}

@Composable
private fun ActivityLegend(value: Int, label: String, color: Color) {
    val colors = AppTheme.colors
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        Box(Modifier.size(8.dp).background(color, CircleShape))
        Text(value.toString(), style = AppType.subheadline.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary)
        Text(label, style = AppType.caption, color = colors.textSecondary, maxLines = 1)
    }
}

@Composable
private fun RecentMovementsSection(
    movements: List<DashboardMovement>,
    showsSeeAll: Boolean,
    canEdit: Boolean,
    onSeeAll: () -> Unit,
    onEdit: (DashboardMovement) -> Unit,
    onDelete: (DashboardMovement) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.History, null, Modifier.size(18.dp), tint = colors.accent)
            Spacer(Modifier.width(AppSpacing.xs))
            Text(stringResource(R.string.dashboard_recent_movements), style = AppType.headline.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, modifier = Modifier.weight(1f))
            if (showsSeeAll) {
                Text(
                    stringResource(R.string.dashboard_see_all),
                    style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                    color = colors.accent,
                    modifier = Modifier.bounceClick(onClick = onSeeAll),
                )
            }
        }
        if (movements.isEmpty()) {
            CartoEmptyState(Icons.Rounded.Verified, stringResource(R.string.dashboard_no_movements))
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                movements.forEach { movement ->
                    MovementSwipeRow(movement, canEdit, { onEdit(movement) }, { onDelete(movement) })
                }
            }
        }
    }
}

@Composable
fun MovementSwipeRow(movement: DashboardMovement, canEdit: Boolean, onEdit: () -> Unit, onDelete: () -> Unit) {
    val colors = AppTheme.colors
    val actions = if (canEdit) listOf(
        SwipeAction(stringResource(R.string.common_delete), Icons.Rounded.Delete, colors.danger, onDelete),
        SwipeAction(stringResource(R.string.common_edit), Icons.Rounded.Edit, colors.accent, onEdit),
    ) else emptyList()
    SwipeActionsRow(actions) { MovementRow(movement) }
}

@Composable
fun MovementRow(movement: DashboardMovement, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val isReturn = movement.eventType == DashboardMovementType.Returned
    val tint = if (isReturn) colors.accent else colors.accentSecondary
    val shape = RoundedCornerShape(AppRadius.lg)
    Row(
        modifier
            .fillMaxWidth()
            .background(colors.surface, shape)
            .border(1.dp, colors.hairline, shape)
            .padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        GradientIconCircle(if (isReturn) Icons.Rounded.SouthWest else Icons.Rounded.NorthEast, tint, size = 42.dp, iconSize = 17.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(movement.territoryCode, style = AppType.subheadline.copy(fontWeight = FontWeight.Bold), color = tint)
                Text(movement.territoryName, style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary, maxLines = 1)
            }
            Text(
                stringResource(if (isReturn) R.string.movements_returned_by else R.string.movements_given_to, movement.personName),
                style = AppType.appCaption,
                color = colors.textSecondary,
                maxLines = 1,
            )
            Text(stringResource(R.string.movements_recorded_by, movement.actorName), style = AppType.caption2, color = colors.textSecondary, maxLines = 1)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                stringResource(if (isReturn) R.string.movements_returned else R.string.movements_given).uppercase(Strings.currentLocale),
                style = AppType.caption2.copy(fontWeight = FontWeight.Bold),
                color = tint,
            )
            Text(DateFormats.relative(movement.eventDate), style = AppType.appCaption, color = colors.textSecondary, maxLines = 1)
        }
    }
}

@Composable
private fun DashboardLoadingView() {
    val colors = AppTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.lg)) {
        repeat(4) { index ->
            Box(
                Modifier.fillMaxWidth().height(if (index == 0) 280.dp else 180.dp).background(colors.surface, RoundedCornerShape(AppRadius.xl)),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = colors.accent) }
        }
    }
}

