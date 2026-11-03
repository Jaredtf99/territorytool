package com.jared.territorytool.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.Hairline
import com.jared.territorytool.designsystem.TerritoryCodeBadge
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.daysBetween

@Composable
fun TerritoryCard(territory: Territory, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val days = territory.givenDateUtc?.let { daysBetween(it) }
    fun ageColor(d: Int): Color = when {
        d > 120 -> colors.danger
        d > 90 -> colors.warning
        else -> colors.textSecondary
    }
    Column(modifier.paperCard().clip(RoundedCornerShape(AppRadius.lg))) {
        Box(Modifier.fillMaxWidth().height(140.dp)) {
            TerritoryMapImage(territory, Modifier.fillMaxSize(), centers = true, strokeWidth = 2.5f)
            TerritoryCodeBadge(territory.code, Modifier.padding(AppSpacing.sm))
        }
        Column(Modifier.padding(AppSpacing.sm), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(territory.name, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 2, modifier = Modifier.weight(1f))
                if (territory.personName != null) PersonBadge(territory.personName) else StatusBadge(isAssigned = false)
            }
            Hairline()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(AppSpacing.xxs)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Rounded.CalendarMonth, null, Modifier.size(12.dp), tint = colors.textSecondary)
                        Text(stringResource(R.string.dashboard_last_assigned), style = AppType.appCaption, color = colors.textSecondary)
                    }
                    Text(
                        territory.givenDateUtc?.let(DateFormats::abbreviated) ?: "-",
                        style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold),
                        color = colors.textPrimary,
                    )
                }
                if (days != null) {
                    val tint = ageColor(days)
                    Row(
                        Modifier.background(tint.copy(alpha = 0.12f), RoundedCornerShape(AppRadius.sm)).padding(horizontal = AppSpacing.xs, vertical = AppSpacing.xxs),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xxs),
                    ) {
                        Icon(Icons.Rounded.History, null, Modifier.size(12.dp), tint = tint)
                        Text(stringResource(R.string.dashboard_days_ago, days), style = AppType.appCaption.copy(fontWeight = FontWeight.Bold), color = tint)
                    }
                }
            }
        }
    }
}

/**
 * Imagen del territorio: snapshot del polígono si hay geometría, si no la imagen firmada
 * de Storage, y si no un marcador de posición.
 */
@Composable
fun TerritoryMapImage(
    territory: Territory,
    modifier: Modifier = Modifier,
    centers: Boolean = true,
    strokeWidth: Float = 2.5f,
    verticalBias: Double = 0.0,
    distanceMultiplier: Double? = null,
    horizontalShift: Double? = null,
) {
    val geometry = territory.mapGeometry
    when {
        geometry != null -> TerritorySnapshotBackdrop(
            geometry,
            modifier,
            centersTerritory = centers,
            strokeLineWidth = strokeWidth,
            verticalBias = verticalBias,
            distanceMultiplier = distanceMultiplier,
            horizontalShift = horizontalShift,
        )
        territory.imgUrl != null -> SubcomposeAsyncImage(
            model = territory.imgUrl,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = modifier,
            loading = { Box(Modifier.fillMaxSize().background(AppTheme.colors.textSecondary.copy(alpha = 0.1f))) },
            error = { MapPlaceholder(Modifier.fillMaxSize()) },
        )
        else -> MapPlaceholder(modifier)
    }
}

@Composable
fun MapPlaceholder(modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Box(modifier.background(colors.textSecondary.copy(alpha = 0.1f)), contentAlignment = Alignment.Center) {
        Icon(Icons.Rounded.Map, null, Modifier.size(34.dp), tint = colors.textSecondary.copy(alpha = 0.3f))
    }
}
