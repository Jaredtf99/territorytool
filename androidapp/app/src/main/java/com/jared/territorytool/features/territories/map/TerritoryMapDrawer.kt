package com.jared.territorytool.features.territories.map

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.WrongLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppButtonStyle
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoSectionHeader
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.TerritoryStatusIndicator
import com.jared.territorytool.designsystem.TerritoryStatusIndicatorSize
import com.jared.territorytool.designsystem.TerritoryStatusPresentation
import com.jared.territorytool.designsystem.rememberStatusPresentation
import com.jared.territorytool.features.main.TerritoryDetailRoute
import com.jared.territorytool.features.territories.TerritoriesViewModel
import com.jared.territorytool.features.territories.TerritoryDrawerDetent
import com.jared.territorytool.features.territories.TerritoryPolygonThumbnail
import com.jared.territorytool.features.territories.availableDetail
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryOperationalStatus
import kotlinx.coroutines.delay
import kotlin.math.abs

/**
 * Panel inferior del explorador: dos posiciones (compacto / medio), arrastre con
 * resistencia elástica en los límites y tarjetas que se expanden al seleccionarse.
 */
@Composable
fun TerritoryMapDrawer(
    viewModel: TerritoriesViewModel,
    collapsedHeight: Dp,
    mediumHeight: Dp,
    bottomInset: Dp,
    onSelect: (Territory) -> Unit,
    onAssign: (Territory) -> Unit,
    onReturn: (Territory) -> Unit,
) {
    val colors = AppTheme.colors
    val density = LocalDensity.current
    val detent by viewModel.drawerDetent.collectAsStateWithLifecycle()
    val selectedId by viewModel.selectedTerritoryId.collectAsStateWithLifecycle()
    val derived by viewModel.derived.collectAsStateWithLifecycle()
    val nearest by viewModel.nearestFirst.collectAsStateWithLifecycle()
    val sort by viewModel.sortOption.collectAsStateWithLifecycle()
    val rows = viewModel.drawerTerritories(derived, nearest, sort)
    val listState = rememberLazyListState()

    var dragDp by remember { mutableFloatStateOf(0f) }
    var dragging by remember { mutableStateOf(false) }
    var boundaryPulse by remember { mutableStateOf(false) }
    var reachedBoundary by remember { mutableStateOf(0) }

    val base = if (detent == TerritoryDrawerDetent.Collapsed) collapsedHeight else mediumHeight

    // Resistencia elástica estilo iOS más allá de los límites.
    fun rubberBand(distance: Float): Float {
        val dimension = 110f
        return (1 - 1 / (distance * 0.55f / dimension + 1)) * dimension
    }

    val proposed = base.value - dragDp
    val visible = when {
        proposed > mediumHeight.value -> mediumHeight.value + rubberBand(proposed - mediumHeight.value)
        proposed < collapsedHeight.value -> collapsedHeight.value - rubberBand(collapsedHeight.value - proposed)
        else -> proposed
    }
    val animatedHeight by animateDpAsState(
        visible.dp,
        if (dragging) spring(stiffness = 100000f) else spring(dampingRatio = 0.82f, stiffness = 300f),
        label = "drawer",
    )

    // Al seleccionar, la tarjeta seleccionada queda arriba del todo.
    LaunchedEffect(selectedId) {
        val id = selectedId ?: return@LaunchedEffect
        delay(120)
        val index = rows.indexOfFirst { it.id == id }.takeIf { it >= 0 }
            ?: derived.withoutGeometry.indexOfFirst { it.id == id }.takeIf { it >= 0 }?.let { rows.size + 1 + it }
        index?.let { listState.animateScrollToItem(it) }
    }

    LaunchedEffect(boundaryPulse) {
        if (boundaryPulse) { delay(200); boundaryPulse = false }
    }

    val shape = RoundedCornerShape(topStart = AppRadius.xl, topEnd = AppRadius.xl)
    Column(
        Modifier
            .fillMaxWidth()
            .height(animatedHeight)
            .shadow(18.dp, shape, ambientColor = Color.Black.copy(alpha = 0.12f), spotColor = Color.Black.copy(alpha = 0.12f))
            .clip(shape)
            .background(colors.surface)
            .border(1.dp, colors.hairline.copy(alpha = 0.6f), shape),
    ) {
        // Asa de arrastre.
        Box(
            Modifier
                .fillMaxWidth()
                .pointerInput(collapsedHeight, mediumHeight, detent) {
                    var velocityTracker = 0f
                    detectVerticalDragGestures(
                        onDragStart = { dragging = true },
                        onDragEnd = {
                            val projected = base.value - dragDp - velocityTracker * 0.15f
                            val target = if (abs(projected - collapsedHeight.value) < abs(projected - mediumHeight.value))
                                TerritoryDrawerDetent.Collapsed else TerritoryDrawerDetent.Medium
                            dragging = false
                            dragDp = 0f
                            reachedBoundary = 0
                            viewModel.drawerDetent.value = target
                        },
                        onDragCancel = { dragging = false; dragDp = 0f },
                        onVerticalDrag = { change, amount ->
                            change.consume()
                            val deltaDp = with(density) { amount.toDp().value }
                            velocityTracker = deltaDp * 16f
                            dragDp += deltaDp
                            val prop = base.value - dragDp
                            val boundary = when {
                                prop > mediumHeight.value + 6 -> 1
                                prop < collapsedHeight.value - 6 -> -1
                                else -> 0
                            }
                            if (boundary != 0 && boundary != reachedBoundary) {
                                reachedBoundary = boundary
                                boundaryPulse = true
                                HapticManager.impact(HapticManager.Impact.Light)
                            } else if (boundary == 0) reachedBoundary = 0
                        },
                    )
                }
                .padding(vertical = AppSpacing.sm),
            contentAlignment = Alignment.Center,
        ) {
            val handleWidth by animateDpAsState(if (boundaryPulse) 48.dp else 40.dp, spring(dampingRatio = 0.55f), label = "handle")
            Box(Modifier.width(handleWidth).height(5.dp).background(colors.textSecondary.copy(alpha = 0.4f), CircleShape))
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = AppSpacing.md, end = AppSpacing.md, bottom = bottomInset + 72.dp),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            items(rows, key = { it.id }) { territory ->
                DrawerRow(territory, viewModel.status(territory), selectedId == territory.id, onSelect, onAssign, onReturn)
            }
            if (derived.withoutGeometry.isNotEmpty()) {
                item(key = "no-geometry") {
                    CartoSectionHeader(
                        stringResource(R.string.territories_section_no_geometry),
                        Icons.Rounded.WrongLocation,
                        count = derived.withoutGeometry.size,
                        tint = colors.textSecondary,
                    )
                }
                items(derived.withoutGeometry, key = { "ng-${it.id}" }) { territory ->
                    DrawerRow(territory, viewModel.status(territory), selectedId == territory.id, onSelect, onAssign, onReturn)
                }
            }
        }
    }
}

/** Tarjeta compacta que se expande en su misma posición al seleccionarse. */
@Composable
private fun DrawerRow(
    territory: Territory,
    status: TerritoryOperationalStatus,
    selected: Boolean,
    onSelect: (Territory) -> Unit,
    onAssign: (Territory) -> Unit,
    onReturn: (Territory) -> Unit,
) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val presentation = rememberStatusPresentation(status)
    val shape = RoundedCornerShape(AppRadius.lg)
    val rowHeight by animateDpAsState(if (selected) 132.dp else 84.dp, spring(dampingRatio = 0.86f, stiffness = 500f), label = "row")
    val thumbWidth by animateDpAsState(if (selected) 116.dp else 96.dp, spring(dampingRatio = 0.86f, stiffness = 500f), label = "thumb")

    Row(
        Modifier
            .fillMaxWidth()
            .height(rowHeight)
            .then(if (selected) Modifier.shadow(10.dp, shape, ambientColor = presentation.color.copy(alpha = 0.12f), spotColor = presentation.color.copy(alpha = 0.12f)) else Modifier)
            .clip(shape)
            .background(if (selected) presentation.color.copy(alpha = 0.10f) else colors.surfaceRaised.copy(alpha = 0.82f))
            .border(1.dp, if (selected) presentation.color.copy(alpha = 0.30f) else Color.Transparent, shape)
            .clickable(remember { MutableInteractionSource() }, null, enabled = !selected) {
                HapticManager.selection()
                onSelect(territory)
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val mapShape = RoundedCornerShape(topEnd = AppRadius.md, bottomEnd = AppRadius.md)
        Box(Modifier.width(thumbWidth).fillMaxHeight().clip(mapShape).border(1.dp, presentation.color.copy(alpha = 0.32f), mapShape)) {
            val geometry = territory.mapGeometry
            if (geometry != null) {
                TerritorySnapshotBackdrop(geometry, Modifier.fillMaxSize(), stroke = presentation.color, fill = presentation.color, centersTerritory = true)
                Box(Modifier.align(Alignment.CenterEnd).width(18.dp).fillMaxHeight().background(Brush.horizontalGradient(listOf(Color.Transparent, colors.surface.copy(alpha = 0.16f)))))
            } else {
                TerritoryPolygonThumbnail(null, presentation.color, Modifier.fillMaxSize().background(presentation.color.copy(alpha = 0.08f)))
            }
        }

        Column(
            Modifier.weight(1f).padding(horizontal = AppSpacing.sm, vertical = AppSpacing.xs).animateContentSize(),
            verticalArrangement = Arrangement.spacedBy(if (selected) 5.dp else 3.dp),
        ) {
            Text(territory.code, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1)
            DrawerAssignmentDetail(territory, status, presentation, selected)
            AnimatedVisibility(selected, enter = slideInVertically { it / 2 } + fadeIn() + scaleIn(initialScale = 0.96f), exit = fadeOut()) {
                Row(Modifier.padding(top = 3.dp), horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                    AppButton(
                        stringResource(R.string.territories_action_view_short),
                        { navigator.push(TerritoryDetailRoute(territory.id, territory.name)) },
                        Modifier.weight(1f).heightIn(min = 34.dp),
                        icon = Icons.Rounded.Visibility,
                        style = AppButtonStyle.Glass,
                        tint = colors.accentDeep,
                        fillWidth = true,
                        textStyle = AppType.caption.copy(fontWeight = FontWeight.SemiBold),
                    )
                    val free = territory.personName == null
                    AppButton(
                        stringResource(if (free) R.string.assignment_title else R.string.return_title),
                        { if (free) onAssign(territory) else onReturn(territory) },
                        Modifier.weight(1f).heightIn(min = 34.dp),
                        icon = if (free) Icons.AutoMirrored.Rounded.Send else Icons.Rounded.MoveToInbox,
                        tint = if (free) colors.accent else colors.accentSecondary,
                        fillWidth = true,
                        textStyle = AppType.caption.copy(fontWeight = FontWeight.SemiBold),
                    )
                }
            }
        }
        if (!selected) {
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.padding(end = AppSpacing.sm).size(18.dp), tint = colors.textSecondary.copy(alpha = 0.6f))
        }
    }
}

@Composable
private fun DrawerAssignmentDetail(territory: Territory, status: TerritoryOperationalStatus, presentation: TerritoryStatusPresentation, selected: Boolean) {
    val colors = AppTheme.colors
    val person = territory.personName
    if (person != null) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            InitialsAvatar(person, size = if (selected) 30.dp else 26.dp, tint = presentation.color)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    person,
                    style = if (selected) AppType.appSubheadline else AppType.appCaption.copy(fontWeight = FontWeight.SemiBold),
                    color = colors.textPrimary,
                    maxLines = 1,
                )
                val detail = when (status) {
                    is TerritoryOperationalStatus.Assigned -> stringResource(R.string.territories_status_days_assigned, status.days)
                    is TerritoryOperationalStatus.Attention -> stringResource(R.string.territories_status_days_assigned, status.days)
                    TerritoryOperationalStatus.Available -> availableDetail(territory)
                }
                Text(detail, style = AppType.appCaption.copy(fontWeight = FontWeight.Medium), color = presentation.color, maxLines = 1)
            }
        }
    } else {
        TerritoryStatusIndicator(
            presentation,
            detail = availableDetail(territory),
            size = if (selected) TerritoryStatusIndicatorSize.Regular else TerritoryStatusIndicatorSize.Compact,
        )
    }
}
