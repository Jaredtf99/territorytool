package com.jared.territorytool.features.auth

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.TimerOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.LiquidBackground

@Composable
fun SessionExpiredAlert(onLogout: () -> Unit) {
    val colors = AppTheme.colors
    val scale = remember { Animatable(0.8f) }
    LaunchedEffect(Unit) { scale.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = 300f)) }

    Box(
        Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, indication = null) {},
        contentAlignment = Alignment.Center,
    ) {
        LiquidBackground()
        Column(
            Modifier
                .padding(40.dp)
                .graphicsLayer { scaleX = scale.value; scaleY = scale.value; alpha = ((scale.value - 0.8f) / 0.2f).coerceIn(0f, 1f) }
                .shadow(20.dp, RoundedCornerShape(20.dp))
                .background(colors.surfaceRaised, RoundedCornerShape(20.dp))
                .padding(30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Icon(Icons.Rounded.TimerOff, null, Modifier.size(50.dp), tint = colors.warning)
            Text(
                stringResource(R.string.session_expired_title),
                style = AppType.title2.copy(fontWeight = FontWeight.Bold),
                color = colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            Text(
                stringResource(R.string.session_expired_message),
                style = AppType.body,
                color = colors.textSecondary,
                textAlign = TextAlign.Center,
            )
            AppButton(
                stringResource(R.string.logout_title),
                onClick = onLogout,
                modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
                large = true,
                fillWidth = true,
            )
        }
    }
}
