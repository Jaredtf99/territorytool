package com.jared.territorytool.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.GlassTextField
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.PrimaryButton
import com.jared.territorytool.designsystem.glass

@Composable
fun LoginScreen(viewModel: LoginViewModel = viewModel()) {
    val colors = AppTheme.colors
    val userName by viewModel.userName.collectAsStateWithLifecycle()
    val password by viewModel.password.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    val focus = LocalFocusManager.current

    fun submit() {
        focus.clearFocus()
        viewModel.login { success ->
            HapticManager.notification(if (success) HapticManager.Notification.Success else HapticManager.Notification.Error)
        }
    }

    Box(Modifier.fillMaxSize()) {
        LiquidBackground()
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(AppSpacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(AppSpacing.xl),
        ) {
            Column(
                Modifier.padding(top = 50.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            ) {
                Icon(Icons.Rounded.Public, null, Modifier.size(80.dp), tint = colors.accent)
                Text("Territory Tool", style = AppType.appLargeTitle, color = colors.textPrimary)
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = AppSpacing.md)
                    .glass(RoundedCornerShape(AppRadius.xl))
                    .padding(AppSpacing.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
            ) {
                Text(stringResource(R.string.login_welcome), style = AppType.appHeadline, color = colors.textSecondary)

                GlassTextField(
                    value = userName,
                    onValueChange = { viewModel.userName.value = it },
                    placeholder = stringResource(R.string.login_username),
                    leadingIcon = Icons.Rounded.Person,
                    imeAction = ImeAction.Next,
                    autoCapitalize = false,
                    onSubmit = { focus.moveFocus(androidx.compose.ui.focus.FocusDirection.Down) },
                )
                GlassTextField(
                    value = password,
                    onValueChange = { viewModel.password.value = it },
                    placeholder = stringResource(R.string.login_password),
                    leadingIcon = Icons.Rounded.Lock,
                    isPassword = true,
                    imeAction = ImeAction.Go,
                    onSubmit = ::submit,
                )

                if (error != null) {
                    Text(error!!, style = AppType.appCaption, color = colors.danger, textAlign = TextAlign.Center)
                }

                PrimaryButton(
                    title = stringResource(R.string.login_button),
                    onClick = ::submit,
                    isLoading = isLoading,
                    modifier = Modifier.padding(top = AppSpacing.xs),
                )
            }
        }
    }
}
