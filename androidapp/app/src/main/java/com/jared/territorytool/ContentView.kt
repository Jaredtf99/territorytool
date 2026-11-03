package com.jared.territorytool

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.core.AppViewModel
import com.jared.territorytool.features.auth.LoginScreen
import com.jared.territorytool.features.auth.SessionExpiredAlert
import com.jared.territorytool.features.main.MainTabView

@Composable
fun ContentView(appViewModel: AppViewModel = viewModel()) {
    val isAuthenticated by appViewModel.isAuthenticated.collectAsStateWithLifecycle()
    val showSessionExpired by appViewModel.showSessionExpiredAlert.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize()) {
        if (isAuthenticated) MainTabView() else LoginScreen()

        AnimatedVisibility(showSessionExpired, enter = fadeIn(), exit = fadeOut()) {
            SessionExpiredAlert(onLogout = appViewModel::logout)
        }
    }
}
