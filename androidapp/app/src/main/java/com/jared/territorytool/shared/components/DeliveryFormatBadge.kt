package com.jared.territorytool.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.shared.models.DeliveryFormat

/** Indicador compacto del formato de entrega (físico/virtual). */
@Composable
fun DeliveryFormatBadge(format: DeliveryFormat, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val title = stringResource(format.titleRes)
    Row(
        modifier
            .background(colors.textSecondary.copy(alpha = 0.12f), CircleShape)
            .padding(horizontal = 6.dp, vertical = 2.dp)
            .semantics(mergeDescendants = true) { contentDescription = title },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(format.icon, null, Modifier.size(12.dp), tint = colors.textSecondary)
        Text(title, style = AppType.appCaption.copy(fontWeight = FontWeight.Medium), color = colors.textSecondary, maxLines = 1)
    }
}
