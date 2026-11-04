package com.jared.territorytool.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.LightbulbCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType

/**
 * Interruptor "No sugerir para entregar": el territorio deja de aparecer en las sugerencias
 * de territorios libres. No pinta fondo: cada pantalla lo envuelve en su propia tarjeta.
 */
@Composable
fun ExcludeFromSuggestionsToggle(isExcluded: Boolean, onChange: (Boolean) -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    fun set(value: Boolean) {
        if (value == isExcluded) return
        HapticManager.selection()
        onChange(value)
    }
    Row(
        modifier.fillMaxWidth().clickable(role = Role.Switch) { set(!isExcluded) },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Box(
            Modifier.size(40.dp).background(colors.accent.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (isExcluded) Icons.Rounded.LightbulbCircle else Icons.Rounded.Lightbulb,
                null,
                Modifier.size(18.dp),
                tint = colors.accentDeep,
            )
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.territory_exclude_from_suggestions_title), style = AppType.appHeadline, color = colors.textPrimary)
            Text(stringResource(R.string.territory_exclude_from_suggestions_hint), style = AppType.appCaption, color = colors.textSecondary)
        }
        Switch(
            checked = isExcluded,
            onCheckedChange = { set(it) },
            colors = SwitchDefaults.colors(checkedTrackColor = colors.accent, checkedThumbColor = Color.White),
        )
    }
}
