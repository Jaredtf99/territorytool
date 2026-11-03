package com.jared.territorytool.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.shared.models.TerritoryOperationalStatus
import androidx.compose.material3.Text

enum class TerritoryStatusIndicatorSize { Compact, Regular }

data class TerritoryStatusPresentation(val title: String, val detail: String, val icon: ImageVector, val color: Color)

@Composable
fun rememberStatusPresentation(status: TerritoryOperationalStatus): TerritoryStatusPresentation {
    val colors = AppTheme.colors
    return when (status) {
        TerritoryOperationalStatus.Available -> TerritoryStatusPresentation(
            stringResource(R.string.territory_status_available),
            stringResource(R.string.territories_status_available_now),
            Icons.Rounded.Check,
            colors.accent,
        )
        is TerritoryOperationalStatus.Assigned -> TerritoryStatusPresentation(
            stringResource(R.string.territory_status_assigned),
            stringResource(R.string.territories_status_days_assigned, status.days),
            Icons.Rounded.AccountCircle,
            colors.accentSecondary,
        )
        is TerritoryOperationalStatus.Attention -> TerritoryStatusPresentation(
            stringResource(R.string.territories_filter_attention),
            stringResource(R.string.territories_status_days_assigned, status.days),
            Icons.Rounded.Warning,
            colors.accentTertiary,
        )
    }
}

@Composable
fun TerritoryStatusIcon(presentation: TerritoryStatusPresentation, size: TerritoryStatusIndicatorSize = TerritoryStatusIndicatorSize.Regular) {
    val d = if (size == TerritoryStatusIndicatorSize.Compact) 24.dp else 28.dp
    GradientIconCircle(presentation.icon, presentation.color, size = d, iconSize = 13.dp)
}

@Composable
fun TerritoryStatusIndicator(
    presentation: TerritoryStatusPresentation,
    modifier: Modifier = Modifier,
    detail: String? = null,
    size: TerritoryStatusIndicatorSize = TerritoryStatusIndicatorSize.Regular,
) {
    val compact = size == TerritoryStatusIndicatorSize.Compact
    Row(
        modifier.semantics(mergeDescendants = true) { contentDescription = presentation.title },
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TerritoryStatusIcon(presentation, size)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                presentation.title,
                style = (if (compact) AppType.appCaption else AppType.appSubheadline).copy(fontWeight = FontWeight.Bold),
                color = presentation.color,
                maxLines = 1,
            )
            if (detail != null) {
                Text(
                    detail,
                    style = (if (compact) AppType.caption2 else AppType.appCaption).copy(fontWeight = FontWeight.Medium),
                    color = presentation.color,
                    maxLines = 1,
                )
            }
        }
    }
}
