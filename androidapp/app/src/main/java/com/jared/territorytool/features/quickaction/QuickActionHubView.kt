package com.jared.territorytool.features.quickaction

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.FlashlightOff
import androidx.compose.material.icons.rounded.FlashlightOn
import androidx.compose.material.icons.rounded.NoPhotography
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material.icons.rounded.WrongLocation
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.currentStateAsState
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.core.navigation.NavStackHost
import com.jared.territorytool.core.navigation.Navigator
import com.jared.territorytool.core.navigation.Route
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoEmptyState
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.shared.components.CameraAuth
import com.jared.territorytool.shared.components.CameraScannerPreview
import com.jared.territorytool.shared.components.openAppSettings
import com.jared.territorytool.shared.components.rememberCameraAuthorization
import com.jared.territorytool.shared.models.Person
import kotlinx.coroutines.launch
import kotlin.random.Random

/** Destinos internos del flujo (pila propia del hub, sin hojas anidadas). */
private data class ResolutionRoute(val resolution: QuickActionResolution) : Route
data class ConfirmRoute(val action: QuickActionAction, val onDeliverAnother: ((String) -> Unit)? = null) : Route

/**
 * Centro rápido de escaneo: cámara embebida y buscador universal anclado abajo. El
 * usuario escanea o busca y la app infiere si toca entregar o devolver.
 */
@Composable
fun QuickActionHubView(initialResolution: QuickActionResolution?, onClose: () -> Unit, onComplete: () -> Unit) {
    val navigator = remember { Navigator() }
    val startsFromResolution = initialResolution != null
    var rootResolution by remember { mutableStateOf(initialResolution) }

    fun deliverAnother(name: String) {
        val person = Person(Random.nextInt(1_000_000, 9_999_999), name, true, emptyList())
        if (startsFromResolution) {
            navigator.popToRoot()
            rootResolution = QuickActionResolution.ForPerson(person)
        } else {
            navigator.popToRoot()
            navigator.push(ResolutionRoute(QuickActionResolution.ForPerson(person)))
        }
    }

    // En la raíz, "atrás" cierra todo el flujo.
    BackHandler(enabled = navigator.isAtRoot, onBack = onClose)

    Box(Modifier.fillMaxSize().background(AppTheme.colors.appBackground)) {
        NavStackHost(navigator, root = {
            val res = rootResolution
            if (res != null) ResolutionDestination(res, onComplete, ::deliverAnother, onClose)
            else HubRoot(onClose) { navigator.push(ResolutionRoute(it)) }
        }) { route ->
            when (route) {
                is ResolutionRoute -> ResolutionDestination(route.resolution, onComplete, ::deliverAnother, null)
                is ConfirmRoute -> QuickActionConfirmScreen(route.action, onComplete, route.onDeliverAnother, null)
                else -> Unit
            }
        }
    }
}

@Composable
private fun ResolutionDestination(
    resolution: QuickActionResolution,
    onDone: () -> Unit,
    onDeliverAnother: (String) -> Unit,
    onClose: (() -> Unit)?,
) {
    when (resolution) {
        is QuickActionResolution.ForTerritory ->
            if (resolution.territory.isAssigned) QuickActionConfirmScreen(QuickActionAction.Return(resolution.territory), onDone, onDeliverAnother, onClose)
            else QuickActionPickPersonScreen(resolution.territory, onDone, onClose)
        is QuickActionResolution.ForPerson -> QuickActionPersonScreen(resolution.person, onDone, onClose)
    }
}

@Composable
private fun HubRoot(onClose: () -> Unit, onSelect: (QuickActionResolution) -> Unit) {
    val vm: QuickActionViewModel = viewModel()
    val colors = AppTheme.colors
    val term by vm.searchTerm.collectAsStateWithLifecycle()
    val hits by vm.searchHits.collectAsStateWithLifecycle()
    val isSearching by vm.isSearching.collectAsStateWithLifecycle()
    val attention by vm.attentionTerritories.collectAsStateWithLifecycle()
    val oldestFree by vm.oldestFreeTerritories.collectAsStateWithLifecycle()
    val loadingSuggestions by vm.isLoadingSuggestions.collectAsStateWithLifecycle()
    val error by vm.errorMessage.collectAsStateWithLifecycle()
    var searchFocused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val scope = rememberCoroutineScope()

    val searching = searchFocused || term.isNotBlank()
    val cameraActive = lifecycle.isAtLeast(Lifecycle.State.RESUMED) && !searching

    LaunchedEffect(Unit) { vm.loadSuggestions() }
    LaunchedEffect(searchFocused) { vm.setBrowsing(searchFocused) }
    LaunchedEffect(Unit) { AppEvents.of(AppEvent.TerritoryDataChanged).collect { vm.loadSuggestions() } }

    fun select(res: QuickActionResolution) {
        HapticManager.selection()
        focusManager.clearFocus()
        onSelect(res)
    }

    AppScreen(
        title = null,
        leading = { GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), onClose, tint = colors.textPrimary) },
    ) {
        Box(Modifier.fillMaxSize()) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = AppSpacing.md).padding(top = AppSpacing.sm, bottom = 96.dp),
                verticalArrangement = Arrangement.spacedBy(AppSpacing.lg),
            ) {
                // Mientras se busca, la cámara no aporta nada: se oculta.
                AnimatedVisibility(!searching, enter = slideInVertically { -it } + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                    ScannerCameraCard(
                        isActive = cameraActive,
                        onScan = { value ->
                            scope.launch {
                                val territory = vm.resolve(value)
                                if (territory != null) {
                                    HapticManager.notification(HapticManager.Notification.Success)
                                    onSelect(QuickActionResolution.ForTerritory(territory))
                                } else HapticManager.notification(HapticManager.Notification.Error)
                            }
                        },
                        onManualSearch = { focusRequester.requestFocus() },
                        modifier = Modifier.appear(0),
                    )
                }

                if (searching) {
                    when {
                        isSearching && hits.isEmpty() -> Box(Modifier.fillMaxWidth().padding(vertical = AppSpacing.lg), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = colors.accent)
                        }
                        hits.isEmpty() -> CartoEmptyState(Icons.Rounded.WrongLocation, stringResource(R.string.quick_action_no_results))
                        else -> Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                            hits.forEach { hit ->
                                val res = hit.resolution ?: return@forEach
                                when {
                                    hit.territory != null -> CompactTerritoryRow(hit.territory, Modifier.bounceClick { select(res) })
                                    hit.person != null -> PersonQuickRow(hit.person, Modifier.bounceClick { select(res) })
                                }
                            }
                        }
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.lg)) {
                        if (loadingSuggestions && attention.isEmpty() && oldestFree.isEmpty()) {
                            Box(Modifier.fillMaxWidth().padding(vertical = AppSpacing.lg), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(color = colors.accent)
                            }
                        }
                        if (attention.isNotEmpty()) {
                            Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                                QASectionHeader(stringResource(R.string.quick_action_suggestions_attention), Icons.Rounded.Warning, colors.accentTertiary)
                                Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                                    attention.forEach { t -> CompactTerritoryRow(t, Modifier.bounceClick { select(QuickActionResolution.ForTerritory(t)) }) }
                                }
                            }
                        }
                        if (oldestFree.isNotEmpty()) {
                            Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                                QASectionHeader(stringResource(R.string.quick_action_suggestions_free), Icons.Rounded.Eco)
                                Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                                    oldestFree.forEach { t -> CompactTerritoryRow(t, Modifier.bounceClick { select(QuickActionResolution.ForTerritory(t)) }) }
                                }
                            }
                        }
                    }
                }
            }
            QuickActionSearchBar(
                stringResource(R.string.quick_action_search_placeholder),
                term,
                { vm.searchTerm.value = it },
                Modifier.align(Alignment.BottomCenter),
                focusRequester,
                onFocusChange = { searchFocused = it },
            )
        }
    }

    error?.let {
        AppAlert(stringResource(R.string.common_error), it, stringResource(R.string.common_ok), { vm.errorMessage.value = null }, { vm.errorMessage.value = null }, dismissText = null)
    }
}

/** Tarjeta de cámara embebida: emite el código leído; gestiona permiso y linterna. */
@Composable
private fun ScannerCameraCard(isActive: Boolean, onScan: (String) -> Unit, onManualSearch: () -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val context = LocalContext.current
    val auth = rememberCameraAuthorization()
    var torch by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(AppRadius.xl)
    Box(
        modifier
            .fillMaxWidth()
            .height(230.dp)
            .shadow(14.dp, shape, ambientColor = colors.glassShadow, spotColor = colors.glassShadow)
            .clip(shape)
            .background(Color.Black.copy(alpha = 0.9f))
            .border(1.dp, colors.hairline.copy(alpha = 0.5f), shape),
        contentAlignment = Alignment.Center,
    ) {
        when (auth) {
            CameraAuth.Authorized -> {
                CameraScannerPreview(isActive, torch, onScan, Modifier.fillMaxSize())
                Icon(
                    if (torch) Icons.Rounded.FlashlightOn else Icons.Rounded.FlashlightOff,
                    stringResource(R.string.quick_action_torch),
                    Modifier
                        .align(Alignment.TopEnd)
                        .padding(AppSpacing.sm)
                        .size(40.dp)
                        .background(Color.White.copy(alpha = 0.2f), CircleShape)
                        .bounceClick { torch = !torch; HapticManager.impact(HapticManager.Impact.Light) }
                        .padding(10.dp),
                    tint = Color.White,
                )
                Text(
                    stringResource(R.string.quick_action_scan_overlay),
                    style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                    color = Color.White,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = AppSpacing.sm + AppSpacing.xs)
                        .background(Color.Black.copy(alpha = 0.35f), CircleShape)
                        .padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs),
                )
            }
            CameraAuth.NotDetermined -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                CircularProgressIndicator(color = Color.White)
                Text(stringResource(R.string.quick_action_camera_requesting), style = AppType.subheadline, color = Color.White.copy(alpha = 0.8f))
            }
            CameraAuth.Denied -> Column(
                Modifier.padding(AppSpacing.md),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            ) {
                Icon(Icons.Rounded.NoPhotography, null, Modifier.size(34.dp), tint = Color.White.copy(alpha = 0.85f))
                Text(stringResource(R.string.quick_action_camera_denied_title), style = AppType.headline, color = Color.White, textAlign = TextAlign.Center)
                Text(stringResource(R.string.quick_action_camera_denied_hint), style = AppType.caption, color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center)
                Row(Modifier.padding(top = AppSpacing.xs), horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                    Text(
                        stringResource(R.string.quick_action_open_settings),
                        style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = Color.White,
                        modifier = Modifier.background(Color.White.copy(alpha = 0.2f), CircleShape).bounceClick { context.openAppSettings() }
                            .padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs),
                    )
                    Text(
                        stringResource(R.string.quick_action_search_manually),
                        style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = Color.White,
                        modifier = Modifier.border(1.dp, Color.White.copy(alpha = 0.4f), CircleShape).bounceClick(onClick = onManualSearch)
                            .padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs),
                    )
                }
            }
        }
    }
}

/** Barra superior del flujo: X (entrada directa) o atrás (pila interna). */
@Composable
fun QuickActionScreen(title: String, onClose: (() -> Unit)?, bottomBar: (@Composable () -> Unit)? = null, content: @Composable () -> Unit) {
    val navigator = LocalNavigator.current
    AppScreen(
        title = title,
        onBack = if (onClose == null) navigator::pop else null,
        leading = onClose?.let { close -> { GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), close, tint = AppTheme.colors.textPrimary) } },
    ) {
        Box(Modifier.fillMaxSize()) {
            content()
            if (bottomBar != null) Box(Modifier.align(Alignment.BottomCenter)) { bottomBar() }
        }
    }
}
