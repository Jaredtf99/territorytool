package com.jared.territorytool.shared.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Navigation
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.background
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.jared.territorytool.core.CongregationStore
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import kotlinx.coroutines.launch

/** Control para ver/cambiar la congregación activa (menú si hay varias). */
@Composable
fun CongregationSwitcher() {
    val colors = AppTheme.colors
    val congregations by CongregationStore.congregations.collectAsStateWithLifecycle()
    val isSwitching by CongregationStore.isSwitching.collectAsStateWithLifecycle()
    val active = congregations.firstOrNull { it.isActive } ?: return
    val multiple = congregations.size > 1
    var expanded by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Box {
        Row(
            Modifier
                .glass(CircleShape)
                .then(if (multiple) Modifier.bounceClick(!isSwitching) { expanded = true } else Modifier)
                .padding(horizontal = 12.dp, vertical = 9.dp)
                .widthIn(max = 220.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(Icons.Rounded.Navigation, null, Modifier.size(14.dp), tint = colors.accentDeep)
            Text(
                active.name,
                style = AppType.subheadline.copy(fontWeight = FontWeight.Medium),
                color = colors.accentDeep,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (multiple) Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(14.dp), tint = colors.accentDeep)
        }
        DropdownMenu(expanded, { expanded = false }, Modifier.background(colors.surfaceRaised)) {
            congregations.forEach { congregation ->
                DropdownMenuItem(
                    text = { Text(congregation.name, style = AppType.body, color = colors.textPrimary) },
                    leadingIcon = if (congregation.isActive) ({ Icon(Icons.Rounded.Check, null, tint = colors.accent) }) else null,
                    onClick = {
                        expanded = false
                        scope.launch {
                            val ok = CongregationStore.switchTo(congregation.id)
                            ToastManager.show(if (ok) "congregation.switched" else "congregation.switch_failed", if (ok) ToastStyle.Success else ToastStyle.Error)
                        }
                    },
                )
            }
        }
    }
}
