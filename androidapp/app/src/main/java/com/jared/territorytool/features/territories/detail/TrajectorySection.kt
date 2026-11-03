package com.jared.territorytool.features.territories.detail

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.TrendingDown
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.Route
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoEmptyState
import com.jared.territorytool.designsystem.CartoSectionHeader
import com.jared.territorytool.designsystem.GradientIconCircle
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.Rounded
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.components.DeliveryFormatBadge
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.TerritoryStatistics
import com.jared.territorytool.shared.models.Transaction
import com.jared.territorytool.shared.models.daysBetween
import java.time.Instant
import kotlin.math.roundToInt

/** Ciclo de asignación derivado de una transacción. */
private data class TrajectoryCycle(val transaction: Transaction) {
    val id get() = transaction.id
    val personName get() = transaction.personName
    val isCurrent get() = transaction.pickedDateUtc == null
    val deliveryFormat get() = transaction.deliveryFormat ?: DeliveryFormat.Physical
    val days get() = daysBetween(transaction.givenDateUtc, transaction.pickedDateUtc ?: Instant.now()).coerceAtLeast(0)
}

/** "Trayectoria": ciclos como anillos en un carrusel, detalle al tocar y comparativa. */
@Composable
fun TrajectorySection(
    transactions: List<Transaction>,
    stats: TerritoryStatistics?,
    canManage: Boolean,
    onEdit: (Transaction) -> Unit,
    onDelete: (Transaction) -> Unit,
    modifier: Modifier = Modifier,
) {
    var formatFilter by rememberSaveable { mutableStateOf<DeliveryFormat?>(null) }
    val cycles = transactions.map(::TrajectoryCycle)
        .filter { formatFilter == null || it.deliveryFormat == formatFilter }
        .sortedByDescending { it.transaction.givenDateUtc }
    val ringScale = (cycles.maxOfOrNull { it.days } ?: 1).coerceAtLeast(1).toFloat()
    var selectedId by rememberSaveable { mutableStateOf<Int?>(null) }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        CartoSectionHeader(stringResource(R.string.territory_detail_trajectory_title), Icons.Rounded.Route, count = cycles.size.takeIf { it > 0 })
        if (transactions.isNotEmpty()) {
            FormatFilterBar(formatFilter) {
                HapticManager.selection()
                formatFilter = it
                selectedId = null
            }
        }
        if (cycles.isEmpty()) {
            CartoEmptyState(
                formatFilter?.icon ?: Icons.Rounded.Map,
                stringResource(if (transactions.isEmpty()) R.string.territory_detail_trajectory_empty else R.string.territory_detail_trajectory_empty_format),
            )
            return@Column
        }
        LazyRow(
            contentPadding = PaddingValues(horizontal = 2.dp, vertical = AppSpacing.md),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            // Equivale al `.padding(.vertical, -8)` de iOS: recorta 8dp arriba y abajo.
            modifier = Modifier.layout { measurable, constraints ->
                val trim = 8.dp.roundToPx()
                val placeable = measurable.measure(constraints)
                layout(placeable.width, (placeable.height - 2 * trim).coerceAtLeast(0)) { placeable.place(0, -trim) }
            },
        ) {
            itemsIndexed(cycles, key = { _, c -> c.id }) { index, cycle ->
                CycleRing(
                    cycle, ringScale, selectedId == cycle.id, canManage,
                    onTap = {
                        HapticManager.selection()
                        selectedId = if (selectedId == cycle.id) null else cycle.id
                    },
                    onEdit = { onEdit(cycle.transaction) },
                    onDelete = { onDelete(cycle.transaction) },
                    modifier = Modifier.appear(index, 60),
                )
            }
        }
        val selected = cycles.firstOrNull { it.id == selectedId }
        AnimatedVisibility(selected != null, enter = fadeIn() + slideInVertically { -it / 6 }, exit = fadeOut()) {
            selected?.let { CycleDetail(it, canManage, onEdit, onDelete) }
        }
        if (stats != null && cycles.any { !it.isCurrent }) InsightBanner(stats)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CycleRing(
    cycle: TrajectoryCycle,
    ringScale: Float,
    isSelected: Boolean,
    canManage: Boolean,
    onTap: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val tint = if (cycle.isCurrent) colors.urgency(cycle.days) else colors.accent
    val progress = (cycle.days / ringScale).coerceAtMost(1f)
    val scale by animateFloatAsState(if (isSelected) 1.08f else 1f, spring(dampingRatio = 0.7f), label = "ring")
    var menu by remember { mutableStateOf(false) }

    Box(modifier) {
        Column(
            Modifier
                .padding(horizontal = AppSpacing.xxs)
                .combinedClickable(remember { MutableInteractionSource() }, null, onClick = onTap, onLongClick = { if (canManage) menu = true }),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        ) {
            Box(
                Modifier
                    .size(68.dp)
                    .graphicsLayer { scaleX = scale; scaleY = scale }
                    .then(if (isSelected) Modifier.shadow(8.dp, CircleShape, ambientColor = tint.copy(alpha = 0.35f), spotColor = tint.copy(alpha = 0.35f)) else Modifier),
                contentAlignment = Alignment.Center,
            ) {
                // El ciclo actual respira: halo pulsante en su color.
                if (cycle.isCurrent) PulseHalo(tint)
                val width = if (isSelected) 6.dp else 5.dp
                Canvas(Modifier.size(68.dp)) {
                    val stroke = width.toPx()
                    val inset = stroke / 2
                    val arcSize = size.copy(size.width - stroke, size.height - stroke)
                    drawArc(colors.hairline, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                    drawArc(tint, -90f, 360f * progress, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        cycle.days.toString(),
                        style = TextStyle(fontFamily = Rounded, fontSize = 20.sp, fontWeight = FontWeight.Black),
                        color = if (cycle.isCurrent) tint else colors.textPrimary,
                    )
                    Text(stringResource(R.string.common_days), style = AppType.caption2, color = colors.textSecondary)
                }
            }
            Row(Modifier.widthIn(max = 96.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                if (cycle.isCurrent) Box(Modifier.size(6.dp).background(tint, CircleShape))
                Text(
                    cycle.personName,
                    style = AppType.appCaption.copy(fontWeight = if (cycle.isCurrent || isSelected) FontWeight.Bold else FontWeight.Medium),
                    color = if (cycle.isCurrent || isSelected) tint else colors.textSecondary,
                    maxLines = 1,
                )
            }
            Icon(cycle.deliveryFormat.icon, stringResource(cycle.deliveryFormat.titleRes), Modifier.size(12.dp), tint = colors.textSecondary)
        }
        DropdownMenu(menu, { menu = false }, Modifier.background(colors.surfaceRaised)) {
            DropdownMenuItem(text = { Text(stringResource(R.string.common_edit)) }, leadingIcon = { Icon(Icons.Rounded.Edit, null) }, onClick = { menu = false; onEdit() })
            DropdownMenuItem(
                text = { Text(stringResource(R.string.common_delete), color = colors.danger) },
                leadingIcon = { Icon(Icons.Rounded.Delete, null, tint = colors.danger) },
                onClick = { menu = false; onDelete() },
            )
        }
    }
}

/** Filtro de la trayectoria por formato de entrega (Todos / Físico / Virtual). */
@Composable
private fun FormatFilterBar(selected: DeliveryFormat?, onSelect: (DeliveryFormat?) -> Unit) {
    val colors = AppTheme.colors
    Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
        (listOf<DeliveryFormat?>(null) + DeliveryFormat.entries).forEach { option ->
            val isSelected = option == selected
            Row(
                Modifier
                    .height(30.dp)
                    .clip(CircleShape)
                    .then(if (isSelected) Modifier.background(colors.accent) else Modifier.glass(CircleShape))
                    .bounceClick { onSelect(option) }
                    .padding(horizontal = AppSpacing.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                option?.let { Icon(it.icon, null, Modifier.size(12.dp), tint = if (isSelected) Color.White else colors.textPrimary) }
                Text(
                    stringResource(option?.titleRes ?: R.string.delivery_format_all),
                    style = AppType.appCaption.copy(fontWeight = FontWeight.Medium),
                    color = if (isSelected) Color.White else colors.textPrimary,
                )
            }
        }
    }
}

/** Halo que se expande y desvanece en bucle alrededor del anillo actual. */
@Composable
private fun PulseHalo(tint: Color) {
    val transition = rememberInfiniteTransition(label = "pulse")
    val t by transition.animateFloat(0f, 1f, infiniteRepeatable(tween(2000, delayMillis = 600), RepeatMode.Restart), label = "pulse-t")
    Canvas(Modifier.size(68.dp).graphicsLayer { scaleX = 1 + 0.32f * t; scaleY = 1 + 0.32f * t; alpha = 0.7f * (1 - t) }) {
        drawCircle(tint.copy(alpha = 0.55f), size.minDimension / 2 - 1.dp.toPx(), style = Stroke(2.dp.toPx()))
    }
}

/** Ficha del ciclo: nombre y ruta de fechas (entrega → devolución). */
@Composable
private fun CycleDetail(cycle: TrajectoryCycle, canManage: Boolean, onEdit: (Transaction) -> Unit, onDelete: (Transaction) -> Unit) {
    val colors = AppTheme.colors
    val tint = if (cycle.isCurrent) colors.urgency(cycle.days) else colors.accent
    Row(
        Modifier.fillMaxWidth().paperCard(AppRadius.lg, colors.surfaceRaised).padding(AppSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        InitialsAvatar(cycle.personName, size = 40.dp, tint = tint)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(AppSpacing.xxs)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(cycle.personName, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1, modifier = Modifier.weight(1f, fill = false))
                DeliveryFormatBadge(cycle.deliveryFormat)
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(Modifier.size(7.dp).background(colors.accentSecondary, CircleShape))
                    Text(DateFormats.abbreviated(cycle.transaction.givenDateUtc), style = AppType.appCaption, color = colors.textSecondary)
                }
                Canvas(Modifier.width(20.dp).size(20.dp, 2.dp)) {
                    drawLine(colors.hairline, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())))
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val picked = cycle.transaction.pickedDateUtc
                    if (picked != null) {
                        Box(Modifier.size(7.dp).background(colors.accent, CircleShape))
                        Text(DateFormats.abbreviated(picked), style = AppType.appCaption, color = colors.textSecondary)
                    } else {
                        Box(Modifier.size(8.dp).border(2.dp, tint, CircleShape))
                        Text(stringResource(R.string.territory_detail_trajectory_ongoing), style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold), color = tint)
                    }
                }
            }
        }
        if (canManage) {
            GlassIconButton(Icons.Rounded.Edit, stringResource(R.string.common_edit), { HapticManager.selection(); onEdit(cycle.transaction) }, tint = colors.accentDeep, size = 36.dp)
            GlassIconButton(Icons.Rounded.Delete, stringResource(R.string.common_delete), { onDelete(cycle.transaction) }, tint = colors.danger, size = 36.dp)
        }
    }
}

@Composable
private fun InsightBanner(stats: TerritoryStatistics) {
    val colors = AppTheme.colors
    val delta = (stats.averageHoldingTime - stats.globalAverageHoldingTime).roundToInt()
    val (icon, tint, message) = when {
        delta >= 3 -> Triple(Icons.AutoMirrored.Rounded.TrendingUp, colors.accentTertiary, stringResource(R.string.territory_detail_trajectory_slower, delta))
        delta <= -3 -> Triple(Icons.AutoMirrored.Rounded.TrendingDown, colors.accent, stringResource(R.string.territory_detail_trajectory_faster, -delta))
        else -> Triple(Icons.Rounded.Verified, colors.accent, stringResource(R.string.territory_detail_trajectory_on_track))
    }
    Row(
        Modifier.fillMaxWidth().paperCard(AppRadius.lg).padding(AppSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        GradientIconCircle(icon, tint, size = 34.dp, iconSize = 15.dp)
        Text(message, style = AppType.appSubheadline, color = colors.textPrimary, modifier = Modifier.weight(1f))
    }
}
