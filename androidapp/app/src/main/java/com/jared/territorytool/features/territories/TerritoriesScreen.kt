package com.jared.territorytool.features.territories

import android.app.Activity
import android.content.ContextWrapper
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.SubcomposeAsyncImage
import com.jared.territorytool.R
import com.jared.territorytool.core.AppRouter
import com.jared.territorytool.core.AppTab
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.TerritoriesPresentation
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.appTopBarInset
import com.jared.territorytool.designsystem.ContentUnavailable
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.SwipeAction
import com.jared.territorytool.designsystem.SwipeActionsRow
import com.jared.territorytool.designsystem.TerritoryStatusIndicator
import com.jared.territorytool.designsystem.TerritoryStatusPresentation
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.designsystem.rememberStatusPresentation
import com.jared.territorytool.features.brothers.SearchCapsule
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.features.main.TerritoryDetailRoute
import com.jared.territorytool.features.quickaction.QuickActionResolution
import com.jared.territorytool.features.territories.map.TerritoriesExplorerMap
import com.jared.territorytool.shared.components.CongregationSwitcher
import com.jared.territorytool.shared.components.DetailWithVirtualMark
import com.jared.territorytool.shared.components.familyTint
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import com.jared.territorytool.shared.models.TerritoryOperationalStatus
import com.jared.territorytool.shared.models.daysBetween
import com.jared.territorytool.shared.utils.PermissionManager
import kotlinx.coroutines.launch

@Composable
fun TerritoriesScreen(viewModel: TerritoriesViewModel = viewModel()) {
    val colors = AppTheme.colors
    val territories by viewModel.territories.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    val presentation by viewModel.presentation.collectAsStateWithLifecycle()
    val filter by viewModel.filterStatus.collectAsStateWithLifecycle()
    val formatFilter by viewModel.deliveryFormatFilter.collectAsStateWithLifecycle()
    val search by viewModel.searchText.collectAsStateWithLifecycle()
    val sort by viewModel.sortOption.collectAsStateWithLifecycle()
    val role by PermissionManager.currentUserRole.collectAsStateWithLifecycle()
    val canManage = remember(role) { PermissionManager.canManageTerritories }
    val location = rememberTerritoryLocationService()
    val currentLocation by location.location.collectAsStateWithLifecycle()
    val derived by viewModel.derived.collectAsStateWithLifecycle()
    val launchContext by AppRouter.territoriesLaunchContext.collectAsStateWithLifecycle()
    val selectedTab by AppRouter.selectedTab.collectAsStateWithLifecycle()

    var showAdd by remember { mutableStateOf(false) }
    var toEdit by remember { mutableStateOf<Territory?>(null) }
    var toDelete by remember { mutableStateOf<Territory?>(null) }
    var isMapFullscreen by rememberSaveable { mutableStateOf(false) }
    var controlsHeight by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current

    // El orden por cercanía se materializa aquí, no en el render del drawer.
    LaunchedEffect(currentLocation, sort, derived.geometryRevision) { viewModel.updateNearestOrder(currentLocation) }
    LaunchedEffect(Unit) {
        AppRouter.consumeTerritoriesLaunchContext()?.let(viewModel::applyLaunchContext)
        if (viewModel.territories.value.isEmpty()) viewModel.loadTerritories()
    }
    LaunchedEffect(launchContext, selectedTab) {
        if (selectedTab == AppTab.Territories && launchContext != null) {
            AppRouter.consumeTerritoriesLaunchContext()?.let {
                viewModel.applyLaunchContext(it)
                viewModel.reload()
            }
        }
    }
    LaunchedEffect(isMapFullscreen) { AppRouter.tabBarHidden.value = isMapFullscreen }

    fun openQuickAction(territory: Territory) {
        HapticManager.selection()
        AppRouter.openQuickAction(QuickActionResolution.ForTerritory(territory))
    }

    fun confirmDelete(territory: Territory) {
        HapticManager.selection()
        toDelete = territory
    }

    val showChrome = !(isMapFullscreen && presentation == TerritoriesPresentation.Map)

    // Como `.statusBarHidden` en iOS: el mapa a pantalla completa oculta la barra de estado.
    val view = LocalView.current
    DisposableEffect(showChrome) {
        val activity = generateSequence(view.context) { (it as? ContextWrapper)?.baseContext }.filterIsInstance<Activity>().firstOrNull()
        val controller = activity?.let { WindowCompat.getInsetsController(it.window, view) }
        if (!showChrome) controller?.hide(WindowInsetsCompat.Type.statusBars())
        onDispose { controller?.show(WindowInsetsCompat.Type.statusBars()) }
    }

    Box(Modifier.fillMaxSize()) {
        AppScreen(
            title = if (showChrome) stringResource(R.string.territories_title) else null,
            leading = if (showChrome) ({ CongregationSwitcher() }) else null,
            actions = if (showChrome && canManage) ({
                GlassIconButton(Icons.Rounded.Add, stringResource(R.string.territory_add_title), { HapticManager.selection(); showAdd = true }, tint = colors.accentDeep)
            }) else null,
            background = { com.jared.territorytool.designsystem.LiquidBackground() },
            // Mapa a pantalla completa: sin barra superior, el mapa ocupa también su hueco.
            showTopBar = showChrome,
            // Como en iOS: el mapa (y la lista) pasan por detrás de la barra superior.
            contentUnderTopBar = true,
        ) {
            Box(Modifier.fillMaxSize()) {
                val topInset = with(density) { controlsHeight.toDp() }
                when {
                    isLoading && territories.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = colors.accent)
                    }
                    error != null && territories.isEmpty() -> ContentUnavailable(
                        stringResource(R.string.common_error), Icons.Rounded.Warning, description = error,
                        modifier = Modifier.padding(top = topInset),
                        actions = { AppButton(stringResource(R.string.common_retry), { scope.launch { viewModel.loadTerritories() } }) },
                    )
                    territories.isEmpty() || (formatFilter != null && derived.sorted.isEmpty()) -> {
                        val filtered = filter != TerritoryFilter.All || formatFilter != null || search.isNotEmpty()
                        ContentUnavailable(
                            stringResource(R.string.territories_empty_list), Icons.Rounded.Map,
                            description = if (filtered) stringResource(R.string.territories_empty_filtered) else null,
                            modifier = Modifier.padding(top = topInset),
                            actions = if (filtered) ({
                                AppButton(stringResource(R.string.territories_clear_filters), {
                                    viewModel.searchText.value = ""
                                    viewModel.filterStatus.value = TerritoryFilter.All
                                    viewModel.deliveryFormatFilter.value = null
                                })
                            }) else null,
                        )
                    }
                    else -> AnimatedContent(presentation, transitionSpec = { fadeIn(tween(280)) + scaleIn(initialScale = 0.985f) togetherWith fadeOut(tween(200)) }, label = "presentation") { mode ->
                        when (mode) {
                            TerritoriesPresentation.Map -> TerritoriesExplorerMap(
                                viewModel = viewModel,
                                location = location,
                                topInset = if (isMapFullscreen) 0.dp else topInset,
                                isFullscreen = isMapFullscreen,
                                onToggleFullscreen = {
                                    HapticManager.impact(HapticManager.Impact.Light)
                                    isMapFullscreen = !isMapFullscreen
                                    viewModel.drawerDetent.value = if (isMapFullscreen) TerritoryDrawerDetent.Collapsed else TerritoryDrawerDetent.Medium
                                },
                                onAssign = ::openQuickAction,
                                onReturn = ::openQuickAction,
                            )
                            TerritoriesPresentation.List -> TerritoryExplorerList(
                                viewModel, topInset, ::openQuickAction, ::openQuickAction, canManage, { toEdit = it }, ::confirmDelete,
                            )
                        }
                    }
                }

                if (isLoading && territories.isNotEmpty()) {
                    Box(Modifier.align(Alignment.TopCenter).padding(top = topInset + AppSpacing.sm).glass(CircleShape).padding(AppSpacing.xs)) {
                        CircularProgressIndicator(Modifier.size(16.dp), color = colors.accent, strokeWidth = 2.dp)
                    }
                }

                androidx.compose.animation.AnimatedVisibility(showChrome, enter = slideInVertically { -it } + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
                    // La altura medida incluye el hueco de la barra superior, así `topInset` cubre ambos.
                    TerritoryExplorerControls(
                        viewModel,
                        onRequestLocation = location::requestLocation,
                        modifier = Modifier.onSizeChanged { controlsHeight = it.height }.padding(top = appTopBarInset()),
                    )
                }
            }
        }
    }

    if (showAdd) AddTerritorySheet(onDismiss = { showAdd = false; viewModel.reload() })
    toEdit?.let { EditTerritorySheet(it, onDismiss = { toEdit = null; viewModel.reload() }) }
    toDelete?.let { territory ->
        val successMsg = stringResource(R.string.territory_delete_success)
        val errorMsg = stringResource(R.string.territory_delete_error)
        AppAlert(
            stringResource(R.string.territory_detail_delete_confirmation_title),
            stringResource(R.string.territory_detail_delete_confirmation_message),
            stringResource(R.string.territory_detail_delete),
            onConfirm = {
                toDelete = null
                scope.launch {
                    if (viewModel.deleteTerritory(territory)) {
                        HapticManager.notification(HapticManager.Notification.Success)
                        val handle = viewModel.lastDeleteUndoHandle
                        ToastManager.show(successMsg, ToastStyle.Success, handle, handle?.toastDurationMillis ?: 3000)
                    } else {
                        HapticManager.notification(HapticManager.Notification.Error)
                        ToastManager.show(viewModel.errorMessage.value ?: errorMsg, ToastStyle.Error)
                    }
                }
            },
            onDismiss = { toDelete = null },
            destructive = true,
        )
    }
}

fun TerritoryFilter.dotColor(colors: com.jared.territorytool.designsystem.AppColors): Color = when (this) {
    TerritoryFilter.All, TerritoryFilter.Free -> colors.accent
    TerritoryFilter.InUse -> colors.accentSecondary
    TerritoryFilter.Attention -> colors.accentTertiary
}

@Composable
private fun TerritoryExplorerControls(viewModel: TerritoriesViewModel, onRequestLocation: () -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val search by viewModel.searchText.collectAsStateWithLifecycle()
    val filter by viewModel.filterStatus.collectAsStateWithLifecycle()
    val formatFilter by viewModel.deliveryFormatFilter.collectAsStateWithLifecycle()
    val sort by viewModel.sortOption.collectAsStateWithLifecycle()
    val ascending by viewModel.sortAscending.collectAsStateWithLifecycle()
    val presentation by viewModel.presentation.collectAsStateWithLifecycle()
    var sortMenu by remember { mutableStateOf(false) }

    // Margen superior: sin él el buscador quedaba pegado a la barra superior.
    Column(modifier.padding(top = AppSpacing.xs, bottom = AppSpacing.xs), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        Row(Modifier.padding(horizontal = AppSpacing.md), horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
            SearchCapsule(search, { viewModel.searchText.value = it }, stringResource(R.string.territories_search_explorer), Modifier.weight(1f))
            PresentationToggle(presentation) {
                HapticManager.selection()
                viewModel.setPresentation(it)
            }
        }
        LazyRow(contentPadding = PaddingValues(horizontal = AppSpacing.md), horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
            item {
                Box {
                    Box(Modifier.size(34.dp).glass(CircleShape).bounceClick { sortMenu = true }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.SwapVert, stringResource(R.string.territories_sort_title), Modifier.size(16.dp), tint = colors.accentDeep)
                    }
                    DropdownMenu(sortMenu, { sortMenu = false }, Modifier.background(colors.surfaceRaised)) {
                        TerritorySortOption.entries.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(stringResource(option.title)) },
                                trailingIcon = { if (option == sort) Icon(Icons.Rounded.Check, null, tint = colors.accent) },
                                onClick = {
                                    viewModel.sortOption.value = option
                                    if (option == TerritorySortOption.Nearest) onRequestLocation()
                                    sortMenu = false
                                },
                            )
                        }
                        HorizontalDivider(color = colors.hairline)
                        DropdownMenuItem(
                            text = { Text(stringResource(if (ascending) R.string.territories_sort_ascending else R.string.territories_sort_descending)) },
                            leadingIcon = { Icon(if (ascending) Icons.Rounded.ArrowUpward else Icons.Rounded.ArrowDownward, null) },
                            onClick = { viewModel.sortAscending.value = !ascending; sortMenu = false },
                        )
                    }
                }
            }
            item {
                val active = filter != TerritoryFilter.All
                FilterMenuChip(
                    label = stringResource(if (active) filter.title else R.string.territories_filter_status),
                    contentDescription = stringResource(R.string.territories_filter_status),
                    active = active,
                    activeTint = colors.accent,
                    leading = if (active) ({ Box(Modifier.size(9.dp).background(Color.White, CircleShape)) }) else null,
                ) { close ->
                    TerritoryFilter.entries.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(stringResource(option.title)) },
                            leadingIcon = {
                                if (option == TerritoryFilter.All) Icon(Icons.Rounded.Layers, null, Modifier.size(16.dp), tint = colors.accent)
                                else Box(Modifier.size(10.dp).background(option.dotColor(colors), CircleShape))
                            },
                            trailingIcon = { if (option == filter) Icon(Icons.Rounded.Check, null, tint = colors.accent) },
                            onClick = {
                                HapticManager.selection()
                                viewModel.filterStatus.value = option
                                viewModel.select(null)
                                close()
                            },
                        )
                    }
                }
            }
            item {
                val active = formatFilter != null
                FilterMenuChip(
                    label = stringResource(formatFilter?.titleRes ?: R.string.delivery_format_title),
                    contentDescription = stringResource(R.string.delivery_format_title),
                    active = active,
                    // Color de la familia "formato", distinto de los colores de estado.
                    activeTint = DeliveryFormat.familyTint,
                    leading = formatFilter?.let { format -> { Icon(format.icon, null, Modifier.size(12.dp), tint = Color.White) } },
                ) { close ->
                    (listOf<DeliveryFormat?>(null) + DeliveryFormat.entries).forEach { option ->
                        DropdownMenuItem(
                            text = { Text(stringResource(option?.titleRes ?: R.string.delivery_format_all)) },
                            leadingIcon = {
                                if (option == null) Icon(Icons.Rounded.Layers, null, Modifier.size(16.dp), tint = DeliveryFormat.familyTint)
                                else Icon(option.icon, null, Modifier.size(16.dp), tint = DeliveryFormat.familyTint)
                            },
                            trailingIcon = { if (option == formatFilter) Icon(Icons.Rounded.Check, null, tint = colors.accent) },
                            onClick = {
                                HapticManager.selection()
                                viewModel.setDeliveryFormatFilter(option)
                                viewModel.select(null)
                                close()
                            },
                        )
                    }
                }
            }
        }
    }
}

/**
 * Chip que abre un menú de opciones. Inactivo (valor por defecto) muestra el nombre del
 * filtro; activo se tiñe y muestra la opción elegida.
 */
@Composable
private fun FilterMenuChip(
    label: String,
    contentDescription: String,
    active: Boolean,
    activeTint: Color,
    leading: (@Composable () -> Unit)?,
    menu: @Composable ColumnScope.(close: () -> Unit) -> Unit,
) {
    val colors = AppTheme.colors
    var expanded by remember { mutableStateOf(false) }
    val content = if (active) Color.White else colors.textPrimary
    Box {
        Row(
            Modifier
                .height(34.dp)
                .clip(CircleShape)
                .then(if (active) Modifier.background(activeTint) else Modifier.glass(CircleShape))
                .bounceClick { expanded = true }
                .semantics { this.contentDescription = "$contentDescription: $label" }
                .padding(start = AppSpacing.sm, end = AppSpacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            leading?.invoke()
            Text(label, style = AppType.appCaption.copy(fontWeight = FontWeight.Medium), color = content)
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(16.dp), tint = if (active) Color.White else colors.textSecondary)
        }
        DropdownMenu(expanded, { expanded = false }, Modifier.background(colors.surfaceRaised)) {
            menu { expanded = false }
        }
    }
}

/** Conmutador flotante Mapa / Lista. */
@Composable
private fun PresentationToggle(presentation: TerritoriesPresentation, onSelect: (TerritoriesPresentation) -> Unit) {
    val colors = AppTheme.colors
    Row(Modifier.glass(CircleShape).padding(4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        listOf(TerritoriesPresentation.Map to R.string.territories_presentation_map, TerritoriesPresentation.List to R.string.territories_presentation_list).forEach { (value, title) ->
            val selected = value == presentation
            Box(
                Modifier
                    .heightIn(min = 36.dp)
                    .widthIn(min = 44.dp)
                    .clip(CircleShape)
                    .background(if (selected) colors.accent else Color.Transparent)
                    .bounceClick { if (!selected) onSelect(value) }
                    .padding(horizontal = AppSpacing.xs),
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(title), style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = if (selected) Color.White else colors.textPrimary)
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TerritoryExplorerList(
    viewModel: TerritoriesViewModel,
    topInset: androidx.compose.ui.unit.Dp,
    onAssign: (Territory) -> Unit,
    onReturn: (Territory) -> Unit,
    canManage: Boolean,
    onEdit: (Territory) -> Unit,
    onDelete: (Territory) -> Unit,
) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val derived by viewModel.derived.collectAsStateWithLifecycle()
    val filter by viewModel.filterStatus.collectAsStateWithLifecycle()
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    val total = derived.sorted.size
    // Con el filtro de Libres se omite "requieren atención" (un libre nunca la requiere).
    val summary = if (filter == TerritoryFilter.Free) stringResource(R.string.territories_summary_short, total)
    else stringResource(R.string.territories_summary, total, derived.attention.size)

    PullToRefreshBox(
        refreshing,
        onRefresh = {
            refreshing = true
            scope.launch {
                viewModel.loadTerritories()
                HapticManager.notification(HapticManager.Notification.Success)
                refreshing = false
            }
        },
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = AppSpacing.md, end = AppSpacing.md, top = topInset, bottom = AppSpacing.xl + LocalTabBarPadding.current),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.xs),
        ) {
            item(key = "header") {
                Text(summary, style = AppType.appSubheadline, color = colors.textSecondary, modifier = Modifier.padding(horizontal = AppSpacing.xs, vertical = AppSpacing.xxs))
            }
            items(derived.sorted, key = { it.id }) { territory ->
                var menu by remember { mutableStateOf(false) }
                val free = territory.personName == null
                val leading = listOf(
                    if (free) SwipeAction(stringResource(R.string.assignment_title), Icons.AutoMirrored.Rounded.Send, colors.accent) { onAssign(territory) }
                    else SwipeAction(stringResource(R.string.return_title), Icons.Rounded.MoveToInbox, colors.accentSecondary) { onReturn(territory) },
                )
                val trailing = if (canManage) listOf(
                    SwipeAction(stringResource(R.string.territory_detail_delete), Icons.Rounded.Delete, Color(0xFFE53935)) { onDelete(territory) },
                    SwipeAction(stringResource(R.string.territory_detail_edit), Icons.Rounded.Edit, colors.accent) { onEdit(territory) },
                ) else emptyList()
                Box(Modifier.animateItem()) {
                    SwipeActionsRow(trailing, leadingActions = leading, shape = RoundedCornerShape(AppRadius.xl)) {
                        TerritoryExplorerRow(
                            territory,
                            viewModel.status(territory),
                            Modifier.combinedClickable(
                                remember { MutableInteractionSource() },
                                null,
                                onClick = { navigator.push(TerritoryDetailRoute(territory.id, territory.name)) },
                                onLongClick = { HapticManager.impact(HapticManager.Impact.Medium); menu = true },
                            ),
                        )
                    }
                    DropdownMenu(menu, { menu = false }, Modifier.background(colors.surfaceRaised)) {
                        DropdownMenuItem(
                            text = { Text(stringResource(if (free) R.string.assignment_title else R.string.return_title)) },
                            leadingIcon = { Icon(if (free) Icons.AutoMirrored.Rounded.Send else Icons.Rounded.MoveToInbox, null) },
                            onClick = { menu = false; if (free) onAssign(territory) else onReturn(territory) },
                        )
                        if (canManage) DropdownMenuItem(
                            text = { Text(stringResource(R.string.territory_detail_edit)) },
                            leadingIcon = { Icon(Icons.Rounded.Edit, null) },
                            onClick = { menu = false; onEdit(territory) },
                        )
                    }
                }
            }
        }
    }
}

/** Texto del estado libre: días desde la última recogida, o "nunca recogido". */
@Composable
fun availableDetail(territory: Territory): String {
    val picked = territory.lastPickedDateUtc ?: return stringResource(R.string.territories_drawer_never_picked)
    return stringResource(R.string.territories_status_days_available, daysBetween(picked).coerceAtLeast(0))
}

@Composable
fun TerritoryExplorerRow(territory: Territory, status: TerritoryOperationalStatus, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val presentation = rememberStatusPresentation(status)
    val shape = RoundedCornerShape(AppRadius.xl)
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 128.dp)
            .shadow(14.dp, shape, ambientColor = colors.glassShadow, spotColor = colors.glassShadow)
            .clip(shape)
            .background(colors.surface)
            .border(1.dp, Brush.linearGradient(listOf(presentation.color.copy(alpha = 0.72f), presentation.color.copy(alpha = 0.22f))), shape),
    ) {
        MapBackdrop(territory, presentation, Modifier.matchParentSize())
        Column(Modifier.padding(AppSpacing.md).padding(end = 104.dp), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(territory.code, style = AppType.appTitle.copy(fontWeight = FontWeight.Bold), color = colors.accentDeep)
                Text(territory.name, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1)
            }
            val person = territory.personName
            if (person != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                    InitialsAvatar(person, size = 32.dp, tint = presentation.color)
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(person, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1)
                        DetailWithVirtualMark(territory.deliveryFormat) {
                            Text(presentation.detail, style = AppType.appCaption.copy(fontWeight = FontWeight.Medium), color = presentation.color, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            } else {
                TerritoryStatusIndicator(presentation, detail = availableDetail(territory))
            }
        }
    }
}

/** Mapa a la derecha que se desvanece hacia la izquierda. */
private fun Modifier.fadeFromLeft(): Modifier = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        drawRect(
            Brush.horizontalGradient(
                0f to Color.Transparent,
                0.18f to Color.Black.copy(alpha = 0.08f),
                0.34f to Color.Black.copy(alpha = 0.38f),
                0.52f to Color.Black.copy(alpha = 0.76f),
                0.68f to Color.Black,
                1f to Color.Black,
            ),
            blendMode = BlendMode.DstIn,
        )
    }

@Composable
private fun MapBackdrop(territory: Territory, presentation: TerritoryStatusPresentation, modifier: Modifier) {
    val geometry = territory.mapGeometry
    val placeholder = @Composable {
        Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(presentation.color.copy(alpha = 0.03f), presentation.color.copy(alpha = 0.18f))))) {
            TerritoryPolygonThumbnail(null, presentation.color, Modifier.align(Alignment.CenterEnd).padding(end = AppSpacing.md).size(112.dp))
        }
    }
    Box(modifier.fadeFromLeft()) {
        when {
            geometry != null -> TerritorySnapshotBackdrop(geometry, Modifier.fillMaxSize(), stroke = presentation.color, fill = presentation.color, verticalBias = 0.12)
            territory.imgUrl != null -> SubcomposeAsyncImage(
                territory.imgUrl, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop,
                loading = { placeholder() }, error = { placeholder() },
            )
            else -> placeholder()
        }
    }
}

/** Silueta simple del polígono más grande (o icono de mapa si no hay geometría). */
@Composable
fun TerritoryPolygonThumbnail(geometry: TerritoryMapGeometry?, tint: Color, modifier: Modifier = Modifier) {
    val polygon = geometry?.polygons?.maxByOrNull { it.coordinates.size }?.coordinates
    Box(modifier.background(tint.copy(alpha = 0.06f), RoundedCornerShape(AppRadius.md)), contentAlignment = Alignment.Center) {
        if (polygon.isNullOrEmpty()) {
            Icon(Icons.Rounded.Map, null, Modifier.size(26.dp), tint = tint)
        } else {
            Canvas(Modifier.fillMaxSize()) {
                val minLat = polygon.minOf { it.latitude }; val maxLat = polygon.maxOf { it.latitude }
                val minLon = polygon.minOf { it.longitude }; val maxLon = polygon.maxOf { it.longitude }
                val latSpan = maxOf(maxLat - minLat, 1e-6); val lonSpan = maxOf(maxLon - minLon, 1e-6)
                val pad = 7.dp.toPx()
                val path = Path()
                polygon.forEachIndexed { i, p ->
                    val x = pad + ((p.longitude - minLon) / lonSpan).toFloat() * (size.width - 2 * pad)
                    val y = pad + (1 - ((p.latitude - minLat) / latSpan).toFloat()) * (size.height - 2 * pad)
                    if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                path.close()
                drawPath(path, tint.copy(alpha = 0.16f))
                drawPath(path, tint, style = Stroke(2.dp.toPx()))
            }
        }
    }
}

