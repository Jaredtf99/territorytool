package com.jared.territorytool.features.territories.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ShowChart
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.Hub
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.Strings
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoSectionHeader
import com.jared.territorytool.designsystem.GradientIconCircle
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.shared.models.TerritoryStatistics
import com.jared.territorytool.shared.models.Transaction
import kotlin.math.abs

/** Estadísticas inline: uso, actividad, ritmo de ciclo y alcance. */
@Composable
fun TerritoryStatsSection(stats: TerritoryStatistics, transactions: List<Transaction>, modifier: Modifier = Modifier) {
    val uniqueNames = transactions.sortedByDescending { it.givenDateUtc }.distinctBy { it.personId }
        .mapNotNull { it.personName.trim().ifEmpty { null } }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        CartoSectionHeader(stringResource(R.string.territory_detail_stats_title), Icons.Rounded.BarChart, tint = AppTheme.colors.accentSecondary)
        UsageRankCard(stats)
        ActiveTimeCard(stats)
        CycleRhythmCard(stats)
        ReachCard(stats, uniqueNames)
    }
}

/** Toca la tarjeta para ver qué significa la métrica. */
@Composable
private fun ExplainedCard(title: String, message: String, fill: Color? = null, content: @Composable () -> Unit) {
    var show by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxWidth().paperCard(AppRadius.lg, fill).bounceClick { HapticManager.selection(); show = true }.padding(AppSpacing.md)) {
        content()
    }
    if (show) AppAlert(title, message, "OK", { show = false }, { show = false }, dismissText = null)
}

@Composable
private fun UsageRankCard(stats: TerritoryStatistics) {
    val colors = AppTheme.colors
    val position = if (stats.totalTerritories > 1) ((stats.usageRank - 1).toFloat() / (stats.totalTerritories - 1)).coerceIn(0f, 1f) else 0f
    val (statusKey, marker) = when {
        stats.isHighUsage -> R.string.territory_detail_stats_rotation_high to colors.accentTertiary
        stats.isLowUsage -> R.string.territory_detail_stats_rotation_low to colors.info
        else -> R.string.territory_detail_stats_rotation_balanced to colors.accent
    }
    ExplainedCard(stringResource(R.string.territory_detail_stats_rotation), stringResource(R.string.territory_stats_rank_desc), colors.surfaceRaised) {
        Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(AppSpacing.xxs)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Rounded.Sync, null, Modifier.size(13.dp), tint = colors.textSecondary)
                        Text(stringResource(R.string.territory_detail_stats_rotation), style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = colors.textSecondary)
                    }
                    Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                        Text(stringResource(R.string.territory_detail_stats_rank_position, stats.usageRank), style = AppType.appLargeTitle.copy(fontWeight = FontWeight.Black), color = colors.textPrimary)
                        Text(
                            stringResource(R.string.territory_detail_stats_rank_of, stats.totalTerritories),
                            style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold),
                            color = colors.textSecondary,
                            modifier = Modifier.padding(bottom = 6.dp),
                        )
                    }
                }
                Text(
                    stringResource(statusKey),
                    style = AppType.appCaption.copy(fontWeight = FontWeight.Bold),
                    color = marker,
                    modifier = Modifier.background(marker.copy(alpha = 0.12f), CircleShape).padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
                )
            }
            RotationScale(position, marker)
            Row {
                Text(stringResource(R.string.territory_detail_stats_more_rotated), style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold), color = colors.textSecondary)
                Spacer(Modifier.weight(1f))
                Text(stringResource(R.string.territory_detail_stats_less_rotated), style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold), color = colors.textSecondary)
            }
        }
    }
}

@Composable
private fun RotationScale(position: Float, markerColor: Color) {
    val colors = AppTheme.colors
    BoxWithConstraints(Modifier.fillMaxWidth().height(28.dp)) {
        val width = maxWidth
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .fillMaxWidth()
                .height(14.dp)
                .background(Brush.horizontalGradient(listOf(colors.accentTertiary.copy(alpha = 0.78f), colors.accent.copy(alpha = 0.78f), colors.info.copy(alpha = 0.70f))), CircleShape),
        ) {
            Row(Modifier.fillMaxHeight().padding(horizontal = AppSpacing.sm)) {
                repeat(9) {
                    Box(Modifier.width(1.dp).fillMaxHeight().background(Color.White.copy(alpha = 0.34f)))
                    Spacer(Modifier.weight(1f))
                }
            }
        }
        val x = (width * position - 13.dp).coerceIn(0.dp, (width - 26.dp).coerceAtLeast(0.dp))
        Box(
            Modifier
                .offset(x = x, y = 1.dp)
                .size(26.dp)
                .shadow(6.dp, CircleShape, ambientColor = markerColor.copy(alpha = 0.35f), spotColor = markerColor.copy(alpha = 0.35f))
                .background(colors.surface, CircleShape)
                .padding(4.dp)
                .background(markerColor, CircleShape),
        )
    }
}

private fun percentText(v: Double) = Strings.get(R.string.territory_stats_percentage, v)
private fun daysText(v: Double) = Strings.get(R.string.territory_stats_days, v)

@Composable
private fun ActiveTimeCard(stats: TerritoryStatistics) {
    val colors = AppTheme.colors
    val subtitle = stringResource(R.string.territory_stats_active_time)
    ExplainedCard(subtitle, stringResource(R.string.territory_stats_active_time_desc)) {
        Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                StatIcon(Icons.AutoMirrored.Rounded.ShowChart, colors.accent)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(R.string.territory_detail_stats_activity), style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = colors.textSecondary)
                    Text(subtitle, style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary)
                }
                Text(percentText(stats.assignedTimePercentage), style = AppType.appTitle.copy(fontWeight = FontWeight.Black), color = colors.textPrimary)
            }
            ComparisonBar(
                stats.assignedTimePercentage, stats.globalAverageAssignedTimePercentage, 100.0, colors.accent,
                stringResource(R.string.territory_detail_stats_avg_value, percentText(stats.globalAverageAssignedTimePercentage)),
            )
            Row { Spacer(Modifier.weight(1f)); DeltaPill(stats.assignedTimePercentage, stats.globalAverageAssignedTimePercentage, lowerIsBetter = false) }
        }
    }
}

@Composable
private fun CycleRhythmCard(stats: TerritoryStatistics) {
    val colors = AppTheme.colors
    val max = maxOf(stats.averageHoldingTime, stats.globalAverageHoldingTime, stats.averageReassignmentTime, stats.globalAverageReassignmentTime, 1.0)
    ExplainedCard(stringResource(R.string.territory_detail_stats_cycle_rhythm), stringResource(R.string.territory_detail_stats_cycle_rhythm_desc)) {
        Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                StatIcon(Icons.Rounded.Hub, colors.accentSecondary)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(R.string.territory_detail_stats_cycle_rhythm), style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = colors.textSecondary)
                    Text(stringResource(R.string.territory_detail_stats_cycle_rhythm_subtitle), style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary)
                }
            }
            CycleMetricRow(
                stringResource(R.string.territory_detail_stats_assigned_segment), daysText(stats.averageHoldingTime),
                stringResource(R.string.territory_detail_stats_avg_value, daysText(stats.globalAverageHoldingTime)),
                stats.averageHoldingTime, stats.globalAverageHoldingTime, max, colors.accentSecondary,
            )
            CycleMetricRow(
                stringResource(R.string.territory_detail_stats_wait_segment), daysText(stats.averageReassignmentTime),
                stringResource(R.string.territory_detail_stats_avg_value, daysText(stats.globalAverageReassignmentTime)),
                stats.averageReassignmentTime, stats.globalAverageReassignmentTime, max, colors.info,
            )
        }
    }
}

@Composable
private fun CycleMetricRow(title: String, valueText: String, averageText: String, value: Double, average: Double, maxValue: Double, color: Color) {
    val colors = AppTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(title, style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, modifier = Modifier.weight(1f).padding(bottom = 6.dp))
            Text(valueText, style = AppType.appLargeTitle.copy(fontWeight = FontWeight.Black), color = colors.textPrimary, maxLines = 1)
        }
        ComparisonBar(value, average, maxValue, color, averageText)
        Row { Spacer(Modifier.weight(1f)); DeltaPill(value, average, lowerIsBetter = true) }
    }
}

@Composable
private fun ReachCard(stats: TerritoryStatistics, names: List<String>) {
    val colors = AppTheme.colors
    val title = stringResource(R.string.territory_stats_unique_users)
    ExplainedCard(title, stringResource(R.string.territory_stats_unique_users_desc)) {
        Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                StatIcon(Icons.Rounded.Group, colors.accentTertiary)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(R.string.territory_detail_stats_reach), style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = colors.textSecondary)
                    Text(title, style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary)
                }
                Text(
                    stringResource(R.string.territory_detail_stats_avg_value, stringResource(R.string.territory_detail_stats_users_average, stats.globalAverageUniqueUsersCount)),
                    style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold),
                    color = colors.textSecondary,
                    maxLines = 1,
                    modifier = Modifier.background(colors.surfaceRaised, CircleShape).border(1.dp, colors.hairline, CircleShape).padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                    Text(stats.uniqueUsersCount.toString(), style = AppType.appLargeTitle.copy(fontWeight = FontWeight.Black), color = colors.textPrimary)
                    Text(stringResource(R.string.territory_detail_stats_users_label), style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textSecondary, modifier = Modifier.padding(bottom = 6.dp))
                }
                UserDots(stats.uniqueUsersCount, names)
            }
        }
    }
}

@Composable
private fun UserDots(count: Int, names: List<String>) {
    val colors = AppTheme.colors
    val palette = listOf(colors.accent, colors.accentSecondary, colors.accentTertiary, colors.info)
    Row(
        Modifier.background(colors.surfaceRaised, CircleShape).border(1.dp, colors.hairline, CircleShape).padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
        horizontalArrangement = Arrangement.spacedBy((-8).dp),
    ) {
        if (count == 0) {
            Text("—", style = AppType.appSubheadline.copy(fontWeight = FontWeight.Black), color = colors.textSecondary, modifier = Modifier.size(30.dp), textAlign = TextAlign.Center)
        } else {
            val visible = minOf(count, 4)
            repeat(visible) { index ->
                val z = (visible - index).toFloat()
                if (count > 4 && index == 3) {
                    Box(Modifier.zIndex(z).size(30.dp).background(colors.surfaceRaised, CircleShape).border(2.dp, colors.surface, CircleShape), contentAlignment = Alignment.Center) {
                        Text("+${count - 3}", style = AppType.appCaption.copy(fontWeight = FontWeight.Black), color = colors.textSecondary)
                    }
                } else {
                    InitialsAvatar(names.getOrElse(index) { "?" }, Modifier.zIndex(z).border(2.dp, colors.surface, CircleShape), size = 30.dp, tint = palette[index % palette.size])
                }
            }
        }
    }
}

@Composable
private fun ComparisonBar(value: Double, average: Double, maxValue: Double, color: Color, averageText: String) {
    val colors = AppTheme.colors
    fun norm(v: Double) = if (maxValue > 0) (v / maxValue).coerceIn(0.0, 1.0).toFloat() else 0f
    BoxWithConstraints(Modifier.fillMaxWidth().height(46.dp)) {
        val width = maxWidth
        val markerWidth = (width * 0.34f).coerceIn(78.dp, 116.dp)
        val markerX = width * norm(average)
        Box(Modifier.offset(y = 8.dp).fillMaxWidth().height(16.dp).background(colors.hairline.copy(alpha = 0.65f), CircleShape))
        Box(
            Modifier.offset(y = 8.dp).width((width * norm(value)).coerceAtLeast(8.dp)).height(16.dp)
                .background(Brush.horizontalGradient(listOf(color.copy(alpha = 0.72f), color)), CircleShape),
        )
        Box(Modifier.offset(x = (markerX - 1.dp).coerceIn(0.dp, (width - 2.dp).coerceAtLeast(0.dp)), y = 3.dp).size(2.dp, 26.dp).background(colors.textPrimary.copy(alpha = 0.72f), CircleShape))
        Text(
            averageText,
            style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold),
            color = colors.textSecondary,
            maxLines = 1,
            textAlign = TextAlign.Center,
            modifier = Modifier.offset(x = (markerX - markerWidth / 2).coerceIn(0.dp, (width - markerWidth).coerceAtLeast(0.dp)), y = 30.dp).width(markerWidth),
        )
    }
}

@Composable
private fun DeltaPill(value: Double, average: Double, lowerIsBetter: Boolean) {
    val colors = AppTheme.colors
    val delta = value - average
    val neutral = abs(delta) <= maxOf(average * 0.05, 0.5)
    val good = neutral || (if (lowerIsBetter) delta < 0 else delta > 0)
    val color = if (neutral) colors.textSecondary else if (good) colors.success else colors.warning
    val icon = if (neutral) Icons.Rounded.Remove else if (delta > 0) Icons.Rounded.ArrowUpward else Icons.Rounded.ArrowDownward
    val text = when {
        neutral -> stringResource(R.string.territory_detail_stats_on_average)
        abs(delta) >= 10 -> "%+.0f".format(delta)
        else -> "%+.1f".format(delta)
    }
    Row(
        Modifier.background(color.copy(alpha = 0.10f), CircleShape).padding(horizontal = AppSpacing.xs, vertical = AppSpacing.xxs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(icon, null, Modifier.size(12.dp), tint = color)
        Text(text, style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = color)
    }
}

@Composable
private fun StatIcon(icon: ImageVector, color: Color) = GradientIconCircle(icon, color, size = 36.dp, iconSize = 16.dp)
