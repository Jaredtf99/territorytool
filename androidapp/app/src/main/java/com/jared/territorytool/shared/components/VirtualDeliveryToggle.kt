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
import com.jared.territorytool.shared.models.DeliveryFormat

/**
 * Interruptor "Entregado en virtual". Apagado = físico (el formato por defecto). No pinta
 * fondo: cada pantalla lo envuelve en su propia tarjeta.
 */
@Composable
fun VirtualDeliveryToggle(format: DeliveryFormat, onFormatChange: (DeliveryFormat) -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val isVirtual = format == DeliveryFormat.Virtual
    val virtualTint = DeliveryFormat.familyTint
    fun set(virtual: Boolean) {
        if (virtual == isVirtual) return
        HapticManager.selection()
        onFormatChange(if (virtual) DeliveryFormat.Virtual else DeliveryFormat.Physical)
    }
    Row(
        modifier.fillMaxWidth().clickable(role = Role.Switch) { set(!isVirtual) },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Box(
            Modifier.size(40.dp).background((if (isVirtual) virtualTint else colors.textSecondary).copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(format.icon, null, Modifier.size(18.dp), tint = if (isVirtual) virtualTint else colors.textSecondary)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.delivery_format_toggle_title), style = AppType.appHeadline, color = colors.textPrimary)
            Text(
                stringResource(if (isVirtual) R.string.delivery_format_toggle_virtual_hint else R.string.delivery_format_toggle_physical_hint),
                style = AppType.appCaption,
                color = colors.textSecondary,
            )
        }
        Switch(
            checked = isVirtual,
            onCheckedChange = { set(it) },
            colors = SwitchDefaults.colors(checkedTrackColor = virtualTint, checkedThumbColor = Color.White),
        )
    }
}
