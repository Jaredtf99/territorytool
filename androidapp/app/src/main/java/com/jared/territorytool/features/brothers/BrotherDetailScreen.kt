package com.jared.territorytool.features.brothers

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.HistoryToggleOff
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.LocalCafe
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.Smartphone
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.AppRouter
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppButtonStyle
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppTopBar
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoEmptyState
import com.jared.territorytool.designsystem.CartoSectionHeader
import com.jared.territorytool.designsystem.CountUpText
import com.jared.territorytool.designsystem.FormToggleRow
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.GlassTextField
import com.jared.territorytool.designsystem.GradientIconCircle
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.PrimaryButton
import com.jared.territorytool.designsystem.Rounded
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.features.main.TerritoryDetailRoute
import com.jared.territorytool.features.quickaction.QuickActionResolution
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.components.DeliveryFormatBadge
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.PersonAssignment
import com.jared.territorytool.shared.models.PersonCurrentAssignment
import com.jared.territorytool.shared.models.PersonDetail
import com.jared.territorytool.shared.models.PersonMonthlyActivity
import com.jared.territorytool.shared.utils.PermissionManager
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle as JavaTextStyle
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Ficha de hermano (tema "Cartográfico cálido"): cabecera con avatar y estado,
 * territorios en curso con su silueta, actividad de 12 meses e histórico filtrable.
 * La acción principal (Entregar) queda fija abajo, como en el detalle de territorio.
 */
@Composable
fun BrotherDetailScreen(personId: Int, personName: String) {
    val viewModel: BrotherDetailViewModel = viewModel(factory = BrotherDetailViewModel.Factory(personId))
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val detail by viewModel.detail.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    val filter by viewModel.historyFilter.collectAsStateWithLifecycle()
    val search by viewModel.historySearch.collectAsStateWithLifecycle()
    val limit by viewModel.historyLimit.collectAsStateWithLifecycle()
    val role by PermissionManager.currentUserRole.collectAsStateWithLifecycle()
    val canManage = remember(role) { PermissionManager.canManageBrothers }
    var refreshing by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val topInset = with(density) { WindowInsets.statusBars.getTop(this).toDp() } + 52.dp

    DisposableEffect(Unit) {
        AppRouter.tabBarHidden.value = true
        onDispose { AppRouter.tabBarHidden.value = false }
    }

    fun openTerritory(id: Int, name: String) {
        HapticManager.selection()
        navigator.push(TerritoryDetailRoute(id, name))
    }

    Box(Modifier.fillMaxSize()) {
        LiquidBackground()
        val current = detail
        when {
            current == null && error != null -> Column(
                Modifier.fillMaxSize().padding(AppSpacing.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(AppSpacing.md, Alignment.CenterVertically),
            ) {
                Icon(Icons.Rounded.Warning, null, Modifier.size(50.dp), tint = colors.warning)
                Text(stringResource(R.string.brother_detail_error), style = AppType.appTitle, color = colors.textPrimary)
                Text(error!!, style = AppType.appSubheadline, color = colors.textSecondary, textAlign = TextAlign.Center)
                AppButton(stringResource(R.string.common_retry), { viewModel.reload() }, tint = colors.accentDeep, large = true)
            }
            current == null -> DetailSkeleton(personName, topInset)
            else -> {
                val filtered = remember(current.history, filter, search) { viewModel.filteredHistory(current.history, filter, search) }
                val groups = remember(filtered, limit) { viewModel.groupByYear(filtered.take(limit)) }
                PullToRefreshBox(
                    refreshing,
                    onRefresh = {
                        refreshing = true
                        scope.launch {
                            viewModel.load()
                            HapticManager.notification(HapticManager.Notification.Success)
                            refreshing = false
                        }
                    },
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = AppSpacing.md, end = AppSpacing.md, top = topInset + AppSpacing.sm, bottom = 120.dp),
                        verticalArrangement = Arrangement.spacedBy(AppSpacing.lg),
                    ) {
                        item(key = "header") { DetailHeader(current, Modifier.appear(0)) }
                        item(key = "current") {
                            CurrentSection(current, Modifier.appear(1)) { openTerritory(it.territoryId, it.territoryCode) }
                        }
                        item(key = "activity") { ActivityChart(current.activity, Modifier.appear(2)) }
                        item(key = "history-header") {
                            HistoryControls(
                                total = current.history.size,
                                counts = BrotherHistoryFilter.entries.associateWith { f -> current.history.count(f::matches) },
                                filter = filter,
                                search = search,
                                onFilter = { HapticManager.selection(); viewModel.setFilter(it) },
                                onSearch = viewModel::setSearch,
                                modifier = Modifier.appear(3),
                            )
                        }
                        if (groups.isEmpty()) {
                            item(key = "history-empty") {
                                CartoEmptyState(
                                    Icons.Rounded.Map,
                                    stringResource(if (current.history.isEmpty()) R.string.brother_detail_history_empty else R.string.brother_detail_history_empty_filtered),
                                )
                            }
                        } else {
                            groups.forEach { group ->
                                item(key = "year-${group.year}-${filter.name}") {
                                    HistoryYearGroup(group, Modifier.animateItem()) { openTerritory(it.territoryId, it.territoryCode) }
                                }
                            }
                            val remaining = filtered.size - limit
                            if (remaining > 0) {
                                item(key = "history-more") {
                                    AppButton(
                                        stringResource(R.string.brother_detail_history_show_more, remaining),
                                        { HapticManager.selection(); viewModel.showMore() },
                                        icon = Icons.Rounded.KeyboardArrowDown,
                                        tint = colors.accentDeep,
                                        style = AppButtonStyle.Glass,
                                        fillWidth = true,
                                        large = true,
                                    )
                                }
                            }
                        }
                    }
                }
                if (current.person.enabled) {
                    Box(
                        Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding()
                            .padding(horizontal = AppSpacing.md).padding(top = AppSpacing.xs, bottom = AppSpacing.sm),
                    ) {
                        AppButton(
                            stringResource(R.string.brother_detail_give),
                            {
                                HapticManager.impact(HapticManager.Impact.Medium)
                                AppRouter.openQuickAction(QuickActionResolution.ForPerson(current.asPerson))
                            },
                            icon = Icons.AutoMirrored.Rounded.Send,
                            tint = colors.accent,
                            large = true,
                            fillWidth = true,
                            textStyle = AppType.appHeadline,
                        )
                    }
                }
            }
        }

        if (isLoading && detail == null && error == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.accent) }
        }

        AppTopBar(
            title = null,
            onBack = navigator::pop,
            actions = if (canManage && detail != null) ({
                GlassIconButton(Icons.Rounded.Edit, stringResource(R.string.brothers_edit_title), { HapticManager.selection(); editing = true }, tint = colors.accentDeep)
            }) else null,
        )
    }

    if (editing) {
        detail?.let { d -> EditSheet(viewModel, d, onDismiss = { editing = false }) }
    }
}

// MARK: - Cabecera

@Composable
private fun DetailHeader(detail: PersonDetail, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val person = detail.person
    val tint = Person(person.id, person.name, person.enabled, null).avatarTint(colors)
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Box(Modifier.size(96.dp), contentAlignment = Alignment.Center) {
                if (detail.summary.activeAssignments > 0 && person.enabled) BreathingHalo(tint)
                InitialsAvatar(person.name, size = 84.dp, tint = tint)
            }
            Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(
                    person.name,
                    style = TextStyle(fontFamily = Rounded, fontSize = 24.sp, fontWeight = FontWeight.Black),
                    color = colors.textPrimary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                StatusChip(detail)
            }
        }
    }
}

@Composable
private fun StatusChip(detail: PersonDetail) {
    val colors = AppTheme.colors
    val active = detail.summary.activeAssignments
    val (title, color) = when {
        !detail.person.enabled -> stringResource(R.string.brothers_status_inactive) to colors.textSecondary
        active == 0 -> stringResource(R.string.brother_detail_status_available) to colors.accent
        else -> stringResource(R.string.brother_detail_status_with_territories, active) to colors.accentSecondary
    }
    Row(
        Modifier
            .background(color.copy(alpha = 0.10f), CircleShape)
            .border(1.dp, color.copy(alpha = 0.35f), CircleShape)
            .padding(horizontal = AppSpacing.sm, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xxs),
    ) {
        Box(Modifier.size(7.dp).background(color, CircleShape))
        Text(title, style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = color)
    }
}

/** Halo que se expande y desvanece en bucle (hermano con territorios en curso). */
@Composable
private fun BreathingHalo(tint: Color) {
    val transition = rememberInfiniteTransition(label = "halo")
    val progress by transition.animateFloat(0f, 1f, infiniteRepeatable(tween(2200, delayMillis = 600, easing = LinearEasing), RepeatMode.Restart), label = "haloProgress")
    Canvas(Modifier.size(84.dp)) {
        val radius = size.minDimension / 2 * (1f + 0.28f * progress)
        drawCircle(tint.copy(alpha = 0.7f * (1f - progress)), radius, style = Stroke(2.dp.toPx()))
    }
}

// MARK: - En curso

@Composable
private fun CurrentSection(detail: PersonDetail, modifier: Modifier = Modifier, onOpen: (PersonCurrentAssignment) -> Unit) {
    val colors = AppTheme.colors
    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        CartoSectionHeader(
            stringResource(R.string.brother_detail_current_title),
            Icons.AutoMirrored.Rounded.DirectionsWalk,
            count = detail.current.size.takeIf { it > 0 },
            tint = colors.accentSecondary,
        )
        if (detail.current.isEmpty()) {
            CartoEmptyState(Icons.Rounded.LocalCafe, stringResource(R.string.brother_detail_current_empty))
        } else {
            detail.current.forEachIndexed { index, assignment ->
                CurrentCard(assignment, detail.summary.congregationAverageHoldingDays, Modifier.appear(index, base = 60)) { onOpen(assignment) }
            }
        }
    }
}

@Composable
private fun CurrentCard(assignment: PersonCurrentAssignment, averageDays: Double?, modifier: Modifier = Modifier, onOpen: () -> Unit) {
    val colors = AppTheme.colors
    val tint = colors.urgency(assignment.days)
    val target = min(assignment.days / max(averageDays ?: 120.0, 1.0), 1.0).toFloat()
    val progress = remember { Animatable(0f) }
    LaunchedEffect(target) { progress.animateTo(target, tween(900, delayMillis = 250, easing = FastOutSlowInEasing)) }
    val shape = RoundedCornerShape(AppRadius.lg)
    Row(
        modifier
            .fillMaxWidth()
            .paperCard()
            .clip(shape)
            .bounceClick(onClick = onOpen)
            .height(IntrinsicSize.Min),
    ) {
        Box(Modifier.width(4.dp).fillMaxHeight().background(tint))
        Row(Modifier.padding(AppSpacing.sm), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            val thumb = RoundedCornerShape(AppRadius.md)
            Box(Modifier.size(84.dp, 72.dp).clip(thumb).border(1.dp, tint.copy(alpha = 0.28f), thumb)) {
                val geometry = assignment.mapGeometry
                if (geometry != null) TerritorySnapshotBackdrop(geometry, Modifier.fillMaxSize(), stroke = tint, fill = tint, centersTerritory = true)
                else Box(Modifier.fillMaxSize().background(colors.textSecondary.copy(alpha = 0.1f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Map, null, Modifier.size(22.dp), tint = colors.textSecondary.copy(alpha = 0.35f))
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                    Text(assignment.territoryCode, style = TextStyle(fontFamily = Rounded, fontSize = 17.sp, fontWeight = FontWeight.Black), color = colors.accentDeep)
                    if (assignment.deliveryFormat == DeliveryFormat.Virtual) DeliveryFormatBadge(DeliveryFormat.Virtual)
                    Spacer(Modifier.weight(1f))
                    DaysPill(assignment.days, tint)
                }
                if (assignment.territoryName != assignment.territoryCode) {
                    Text(assignment.territoryName, style = AppType.appSubheadline, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Box(Modifier.fillMaxWidth().height(6.dp).background(colors.hairline.copy(alpha = 0.6f), CircleShape)) {
                    Box(
                        Modifier.fillMaxWidth(progress.value).fillMaxHeight()
                            .background(Brush.horizontalGradient(listOf(tint.copy(alpha = 0.65f), tint)), CircleShape),
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.AutoMirrored.Rounded.Send, null, Modifier.size(9.dp), tint = colors.textSecondary)
                    Text(
                        listOfNotNull(DateFormats.abbreviated(assignment.givenAt), assignment.givenBy).joinToString(" · "),
                        style = AppType.caption2,
                        color = colors.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.size(14.dp), tint = colors.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun DaysPill(days: Int, tint: Color, emphasized: Boolean = true) {
    val colors = AppTheme.colors
    Text(
        stringResource(R.string.brothers_days_format, days),
        style = AppType.caption.copy(fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum"),
        color = if (emphasized) tint else colors.textPrimary,
        modifier = Modifier.background((if (emphasized) tint else colors.textSecondary).copy(alpha = 0.13f), CircleShape).padding(horizontal = AppSpacing.xs, vertical = 4.dp),
    )
}

// MARK: - Actividad

@Composable
private fun ActivityChart(activity: List<PersonMonthlyActivity>, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val total = activity.sumOf { it.givenCount }
    val maxValue = max(activity.maxOfOrNull { max(it.givenCount, it.returnedCount) } ?: 1, 1)
    // Eje Y con pasos "redondos" (como mucho ~4 divisiones, siempre enteras); las barras se escalan contra el tope.
    val axisStep = max(1, (maxValue + 3) / 4)
    val axisMax = axisStep * ((maxValue + axisStep - 1) / axisStep)
    val axisTicks = (0..axisMax step axisStep).toList()
    val plotHeight = 116.dp
    var selected by remember { mutableStateOf<String?>(null) }
    val locale = com.jared.territorytool.core.Strings.currentLocale
    val longFormatter = remember(locale) { DateTimeFormatter.ofPattern("LLLL yyyy", locale) }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        CartoSectionHeader(stringResource(R.string.brother_detail_activity_title), Icons.Rounded.BarChart, count = total.takeIf { it > 0 })
        Column(Modifier.fillMaxWidth().paperCard().padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            val month = activity.firstOrNull { it.month == selected }
            AnimatedContent(month, transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) }, label = "activitySummary") { m ->
                if (m != null) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(longFormatter.format(m.monthDate).replaceFirstChar { it.titlecase(locale) }, style = AppType.appSubheadline.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, modifier = Modifier.weight(1f))
                        Text(stringResource(R.string.brother_detail_activity_month_summary, m.givenCount, m.returnedCount), style = AppType.appCaption, color = colors.textSecondary)
                    }
                } else {
                    Text(stringResource(if (total == 0) R.string.brother_detail_activity_empty else R.string.brother_detail_activity_hint), style = AppType.appCaption, color = colors.textSecondary)
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
                YAxis(axisTicks, axisMax, plotHeight)
                Box(Modifier.weight(1f)) {
                ChartGrid(axisTicks, axisMax, Modifier.fillMaxWidth().height(plotHeight))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.Top) {
                activity.forEachIndexed { index, m ->
                    val isSelected = selected == m.month
                    val dimmed = selected != null && !isSelected
                    val alpha by animateFloatAsState(if (dimmed) 0.45f else 1f, label = "monthAlpha")
                    Column(
                        Modifier
                            .weight(1f)
                            .alpha(alpha)
                            .clip(RoundedCornerShape(6.dp))
                            .background(if (isSelected) colors.accent.copy(alpha = 0.10f) else Color.Transparent)
                            .bounceClick {
                                HapticManager.selection()
                                selected = if (isSelected) null else m.month
                            },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Row(Modifier.height(plotHeight), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                            GrowingBar(m.givenCount, axisMax, colors.accentSecondary, index * 30)
                            GrowingBar(m.returnedCount, axisMax, colors.accent, index * 30 + 15)
                        }
                        Text(
                            m.monthDate.month.getDisplayName(JavaTextStyle.SHORT, locale).take(3).replaceFirstChar { it.titlecase(locale) },
                            style = AppType.caption2.copy(fontSize = 10.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium),
                            color = if (isSelected) colors.textPrimary else colors.textSecondary,
                            maxLines = 1,
                        )
                    }
                }
                }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
                Legend(colors.accentSecondary, stringResource(R.string.brother_detail_activity_given))
                Legend(colors.accent, stringResource(R.string.brother_detail_activity_returned))
            }
        }
    }
}

@Composable
private fun GrowingBar(value: Int, maxValue: Int, color: Color, delay: Int) {
    val target = if (value == 0) 0f else max(value.toFloat() / maxValue, 0.04f)
    val fraction = remember { Animatable(0f) }
    LaunchedEffect(target) { fraction.animateTo(target, tween(700, delayMillis = 200 + delay, easing = FastOutSlowInEasing)) }
    Box(Modifier.width(9.dp).fillMaxHeight(), contentAlignment = Alignment.BottomCenter) {
        if (fraction.value > 0f) {
            Box(
                Modifier.fillMaxWidth().fillMaxHeight(fraction.value)
                    .background(Brush.verticalGradient(listOf(color.copy(alpha = 0.85f), color)), RoundedCornerShape(topStart = 3.dp, topEnd = 3.dp)),
            )
        }
    }
}

/** Etiquetas del eje Y, centradas sobre su línea guía. */
@Composable
private fun YAxis(ticks: List<Int>, axisMax: Int, plotHeight: Dp) {
    val colors = AppTheme.colors
    val labelHeight = 12.dp
    Box(Modifier.width(18.dp).height(plotHeight)) {
        ticks.forEach { tick ->
            Text(
                tick.toString(),
                style = TextStyle(fontFamily = Rounded, fontSize = 9.sp, fontWeight = FontWeight.Medium, fontFeatureSettings = "tnum", lineHeight = 12.sp),
                color = colors.textSecondary.copy(alpha = 0.8f),
                textAlign = TextAlign.End,
                maxLines = 1,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(labelHeight)
                    .offset(y = plotHeight * (1f - tick.toFloat() / axisMax) - labelHeight / 2),
            )
        }
    }
}

/** Líneas guía horizontales: la base continua, el resto punteadas. */
@Composable
private fun ChartGrid(ticks: List<Int>, axisMax: Int, modifier: Modifier = Modifier) {
    val hairline = AppTheme.colors.hairline
    Canvas(modifier) {
        val dash = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))
        ticks.forEach { tick ->
            val y = size.height * (1f - tick.toFloat() / axisMax)
            drawLine(
                if (tick == 0) hairline else hairline.copy(alpha = 0.7f),
                Offset(0f, y),
                Offset(size.width, y),
                strokeWidth = 1.dp.toPx(),
                pathEffect = if (tick == 0) null else dash,
            )
        }
    }
}

@Composable
private fun Legend(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(10.dp).background(color, RoundedCornerShape(2.dp)))
        Text(label, style = AppType.appCaption, color = AppTheme.colors.textSecondary)
    }
}

// MARK: - Histórico

@Composable
private fun HistoryControls(
    total: Int,
    counts: Map<BrotherHistoryFilter, Int>,
    filter: BrotherHistoryFilter,
    search: String,
    onFilter: (BrotherHistoryFilter) -> Unit,
    onSearch: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        CartoSectionHeader(stringResource(R.string.brother_detail_history_title), Icons.Rounded.HistoryToggleOff, count = total.takeIf { it > 0 })
        if (total > 0) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs), contentPadding = PaddingValues(horizontal = 2.dp)) {
                items(BrotherHistoryFilter.entries) { option ->
                    val count = counts[option] ?: 0
                    val enabled = option == BrotherHistoryFilter.All || count > 0
                    Box(Modifier.alpha(if (enabled) 1f else 0.45f)) {
                        CountChip(stringResource(option.title), count, selected = option == filter, onClick = { if (enabled) onFilter(option) })
                    }
                }
            }
            SearchCapsule(search, onSearch, stringResource(R.string.brother_detail_history_search))
        }
    }
}

@Composable
private fun HistoryYearGroup(group: BrotherHistoryYear, modifier: Modifier = Modifier, onOpen: (PersonAssignment) -> Unit) {
    val colors = AppTheme.colors
    Column(modifier.animateContentSize(), verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        Text(
            group.year.toString(),
            style = TextStyle(fontFamily = Rounded, fontSize = 12.sp, fontWeight = FontWeight.Black),
            color = colors.textSecondary,
            modifier = Modifier
                .background(colors.surface, CircleShape)
                .border(1.dp, colors.hairline, CircleShape)
                .padding(horizontal = AppSpacing.sm, vertical = 4.dp),
        )
        Column(Modifier.fillMaxWidth().paperCard().padding(vertical = AppSpacing.xxs)) {
            group.items.forEachIndexed { index, item ->
                HistoryRow(item, isFirst = index == 0, isLast = index == group.items.lastIndex, modifier = Modifier.appear(index, base = 25)) { onOpen(item) }
            }
        }
    }
}

@Composable
private fun HistoryRow(item: PersonAssignment, isFirst: Boolean, isLast: Boolean, modifier: Modifier = Modifier, onOpen: () -> Unit) {
    val colors = AppTheme.colors
    val tint = if (item.isOngoing) colors.urgency(item.days) else colors.accent
    val hairline = colors.hairline
    Row(
        modifier.fillMaxWidth().height(IntrinsicSize.Min).bounceClick(onClick = onOpen).padding(horizontal = AppSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        // Nodo de la ruta con tramos punteados que enlazan las paradas.
        Canvas(Modifier.width(14.dp).fillMaxHeight()) {
            val cx = size.width / 2
            val cy = size.height / 2
            val dash = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))
            if (!isFirst) drawLine(hairline, Offset(cx, 0f), Offset(cx, cy - 7.dp.toPx()), 1.5.dp.toPx(), pathEffect = dash)
            if (!isLast) drawLine(hairline, Offset(cx, cy + 7.dp.toPx()), Offset(cx, size.height), 1.5.dp.toPx(), pathEffect = dash)
            if (item.isOngoing) drawCircle(tint, 5.dp.toPx(), Offset(cx, cy), style = Stroke(2.5.dp.toPx()))
            else drawCircle(tint, 5.dp.toPx(), Offset(cx, cy))
        }
        Column(Modifier.weight(1f).padding(vertical = AppSpacing.xs + 2.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(item.territoryCode, style = AppType.subheadline.copy(fontWeight = FontWeight.Bold), color = colors.accentDeep)
                if (item.territoryName != item.territoryCode) {
                    Text(item.territoryName, style = AppType.appCaption, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                }
                if (item.deliveryFormat == DeliveryFormat.Virtual) Icon(Icons.Rounded.Smartphone, stringResource(R.string.delivery_format_virtual), Modifier.size(12.dp), tint = colors.info)
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(DateFormats.abbreviated(item.givenAt), style = AppType.caption2, color = colors.textSecondary)
                Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, Modifier.size(9.dp), tint = colors.textSecondary)
                val picked = item.pickedAt
                if (picked != null) Text(DateFormats.abbreviated(picked), style = AppType.caption2, color = colors.textSecondary)
                else Text(stringResource(R.string.territory_detail_trajectory_ongoing), style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold), color = tint)
            }
        }
        DaysPill(item.days, tint, emphasized = item.isOngoing)
    }
}

// MARK: - Edición

@Composable
private fun EditSheet(viewModel: BrotherDetailViewModel, detail: PersonDetail, onDismiss: () -> Unit) {
    val saving by viewModel.isSaving.collectAsStateWithLifecycle()
    var name by remember { mutableStateOf(detail.person.name) }
    var enabled by remember { mutableStateOf(detail.person.enabled) }
    val scope = rememberCoroutineScope()
    fun save() {
        if (name.isBlank()) return
        HapticManager.selection()
        scope.launch {
            if (viewModel.update(name.trim(), enabled)) {
                HapticManager.notification(HapticManager.Notification.Success)
                onDismiss()
            }
        }
    }
    BrotherSheetScaffold(stringResource(R.string.brothers_edit_title), onDismiss) {
        Column(Modifier.padding(horizontal = AppSpacing.md), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            GlassTextField(name, { name = it }, stringResource(R.string.brothers_name), label = stringResource(R.string.brothers_name), onSubmit = ::save)
            Box(Modifier.glass(RoundedCornerShape(AppRadius.md))) {
                FormToggleRow(stringResource(R.string.brothers_enabled), enabled, { enabled = it })
            }
            PrimaryButton(stringResource(R.string.brothers_save), ::save, isLoading = saving, isDisabled = name.isBlank())
        }
    }
}

// MARK: - Esqueleto

@Composable
private fun DetailSkeleton(personName: String, topInset: Dp) {
    val colors = AppTheme.colors
    Column(Modifier.fillMaxSize().padding(top = topInset).padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.lg)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Box(Modifier.size(84.dp).background(colors.surface, CircleShape))
            Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(personName, style = TextStyle(fontFamily = Rounded, fontSize = 24.sp, fontWeight = FontWeight.Black), color = colors.textPrimary, maxLines = 1)
                Box(Modifier.size(110.dp, 26.dp).background(colors.surface, CircleShape))
            }
        }
        Box(Modifier.fillMaxWidth().height(96.dp).background(colors.surface, RoundedCornerShape(AppRadius.lg)))
        Box(Modifier.fillMaxWidth().height(150.dp).background(colors.surface, RoundedCornerShape(AppRadius.lg)))
    }
}
