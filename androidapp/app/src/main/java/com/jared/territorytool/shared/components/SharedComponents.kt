package com.jared.territorytool.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.ContentUnavailable
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.shared.models.Territory
import kotlinx.coroutines.launch

@Composable
fun StatusBadge(isAssigned: Boolean, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Text(
        stringResource(if (isAssigned) R.string.territory_status_assigned else R.string.territory_status_available),
        style = AppType.caption.copy(fontWeight = FontWeight.SemiBold),
        color = androidx.compose.ui.graphics.Color.White,
        modifier = modifier
            .background(if (isAssigned) colors.warning else colors.success, CircleShape)
            .padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
    )
}

@Composable
fun PersonBadge(personName: String, modifier: Modifier = Modifier) {
    Row(
        modifier
            .background(AppTheme.colors.accent, CircleShape)
            .padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xxs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Person, null, Modifier.size(12.dp), tint = androidx.compose.ui.graphics.Color.White)
        Text(personName, style = AppType.caption.copy(fontWeight = FontWeight.Medium), color = androidx.compose.ui.graphics.Color.White, maxLines = 1)
    }
}

@Composable
fun CompactTerritoryCard(territory: Territory, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Row(
        modifier
            .background(colors.surface, CircleShape)
            .border(1.dp, colors.hairline, CircleShape)
            .padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            territory.code,
            style = AppType.caption.copy(fontWeight = FontWeight.Bold),
            color = colors.accent,
            modifier = Modifier
                .background(colors.accent.copy(alpha = 0.12f), RoundedCornerShape(AppRadius.sm))
                .padding(horizontal = AppSpacing.xs, vertical = AppSpacing.xxs),
        )
        Text(territory.name, style = AppType.caption, color = colors.textPrimary, maxLines = 1)
    }
}

/** Estado unificado de carga / vacío / error con reintento. */
@Composable
fun LoadingErrorStateView(
    isLoading: Boolean,
    error: String?,
    isEmpty: Boolean,
    modifier: Modifier = Modifier,
    emptyText: String = stringResource(R.string.common_empty),
    emptyIcon: ImageVector = Icons.Rounded.Inbox,
    retry: (suspend () -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val scope = rememberCoroutineScope()
    when {
        isLoading -> Box(modifier.fillMaxWidth().heightIn(min = 220.dp), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = AppTheme.colors.accent)
        }
        error != null -> ContentUnavailable(
            title = stringResource(R.string.common_error),
            icon = Icons.Rounded.Warning,
            description = error,
            modifier = modifier,
            actions = retry?.let { r ->
                { AppButton(stringResource(R.string.common_retry), onClick = { scope.launch { r() } }) }
            },
        )
        isEmpty -> ContentUnavailable(title = emptyText, icon = emptyIcon, modifier = modifier)
        else -> content()
    }
}

/** Fila que abre un selector (persona, territorio…) con opción de limpiar. */
@Composable
fun SelectionRow(
    value: String?,
    placeholder: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onClear: (() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .glass(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(AppSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, Modifier.width(24.dp), tint = colors.textSecondary)
        Spacer(Modifier.width(AppSpacing.xs))
        if (value != null) {
            Text(value, style = AppType.body.copy(fontWeight = FontWeight.Medium), color = colors.textPrimary, modifier = Modifier.weight(1f))
        } else {
            Text(placeholder, style = AppType.body, color = colors.textSecondary, modifier = Modifier.weight(1f))
        }
        if (value != null && onClear != null) {
            Icon(Icons.Rounded.Cancel, null, Modifier.size(20.dp).clickable(onClick = onClear), tint = colors.textSecondary)
        } else {
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(18.dp), tint = colors.textSecondary)
        }
    }
}

@Composable
fun CenteredProgress(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = AppTheme.colors.accent)
    }
}

@Composable
fun SectionColumn(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) { content() }
}
