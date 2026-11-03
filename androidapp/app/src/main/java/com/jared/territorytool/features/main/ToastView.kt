package com.jared.territorytool.features.main

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.core.Strings
import com.jared.territorytool.designsystem.AppColors
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.ProgressRing
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.shared.components.ToastMessage
import com.jared.territorytool.shared.components.ToastStyle
import kotlinx.coroutines.delay

fun ToastStyle.icon(): ImageVector = when (this) {
    ToastStyle.Success -> Icons.Rounded.CheckCircle
    ToastStyle.Error -> Icons.Rounded.Cancel
    ToastStyle.Info -> Icons.Rounded.Info
    ToastStyle.Warning -> Icons.Rounded.Warning
}

fun ToastStyle.color(colors: AppColors): Color = when (this) {
    ToastStyle.Success -> colors.success
    ToastStyle.Error -> colors.danger
    ToastStyle.Info -> colors.info
    ToastStyle.Warning -> colors.warning
}

@Composable
fun ToastGlassMessageView(message: ToastMessage, isUndoing: Boolean, onUndo: (() -> Unit)?) {
    val colors = AppTheme.colors
    val shape = RoundedCornerShape(AppRadius.xl)
    val scale by animateFloatAsState(if (isUndoing) 0.985f else 1f, label = "toast")
    Row(
        Modifier
            .widthIn(max = 380.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .shadow(16.dp, shape, ambientColor = Color.Black.copy(alpha = 0.14f), spotColor = Color.Black.copy(alpha = 0.14f))
            .clip(shape)
            .background(colors.surfaceRaised.copy(alpha = 0.96f))
            .border(if (isUndoing) 1.5.dp else 1.dp, if (isUndoing) colors.danger.copy(alpha = 0.38f) else Color.White.copy(alpha = 0.24f), shape)
            .padding(horizontal = AppSpacing.md, vertical = AppSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Icon(message.style.icon(), null, Modifier.size(26.dp), tint = message.style.color(colors))
        Text(
            if (Strings.hasKey(message.message)) Strings.key(message.message) else message.message,
            style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold),
            color = colors.textPrimary,
            maxLines = 3,
            modifier = Modifier.weight(1f, fill = false),
        )
        val handle = message.undoHandle
        if (handle != null && onUndo != null) {
            Box(
                Modifier
                    .clip(CircleShape)
                    .background(colors.danger.copy(alpha = 0.14f))
                    .bounceClick(!isUndoing, onUndo)
                    .padding(horizontal = 14.dp, vertical = 8.dp)
                    .widthIn(min = 70.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (isUndoing) {
                    CircularProgressIndicator(Modifier.size(16.dp), color = colors.danger, strokeWidth = 2.dp)
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(stringResource(R.string.common_undo), style = AppType.appSubheadline.copy(fontWeight = FontWeight.Bold), color = colors.danger, maxLines = 1)
                        UndoCountdownRing(handle.expiresAt.toEpochMilli())
                    }
                }
            }
        }
    }
}

@Composable
private fun UndoCountdownRing(expiresAtMillis: Long) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(expiresAtMillis) {
        while (now < expiresAtMillis) {
            delay(32)
            now = System.currentTimeMillis()
        }
    }
    val remaining = (expiresAtMillis - now).coerceAtLeast(0) / 1000f
    ProgressRing((remaining / 5f).coerceIn(0f, 1f), AppTheme.colors.danger, Modifier.size(14.dp))
}
