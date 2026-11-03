package com.jared.territorytool.features.brothers

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PersonOff
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.SubcomposeAsyncImage
import com.jared.territorytool.R
import com.jared.territorytool.core.AppRouter
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppColors
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.CartoEmptyState
import com.jared.territorytool.designsystem.ContentUnavailable
import com.jared.territorytool.designsystem.FormToggleRow
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.GlassTextField
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.PrimaryButton
import com.jared.territorytool.designsystem.SwipeAction
import com.jared.territorytool.designsystem.SwipeActionsRow
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.features.main.TerritoryDetailRoute
import com.jared.territorytool.features.quickaction.QuickActionResolution
import com.jared.territorytool.features.quickaction.daysHeld
import com.jared.territorytool.features.quickaction.maxDaysHeld
import com.jared.territorytool.shared.components.AppSheet
import com.jared.territorytool.shared.components.CongregationSwitcher
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.components.SearchField
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.TerritoryInUse
import com.jared.territorytool.shared.models.TerritoryMapGeometry
import com.jared.territorytool.shared.utils.PermissionManager
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt

/** Tinte estable por persona (rota por id sobre la paleta cálida). */
fun Person.avatarTint(colors: AppColors): Color {
    if (!enabled) return colors.textSecondary
    val palette = listOf(colors.accent, colors.accentSecondary, colors.accentTertiary, colors.info)
    return palette[abs(id) % palette.size]
}

@Composable
fun BrothersScreen(viewModel: BrothersViewModel = viewModel()) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val brothers by viewModel.brothers.collectAsStateWithLifecycle()
    val derived by viewModel.derived.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val search by viewModel.searchText.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    val expanded by viewModel.expandedIds.collectAsStateWithLifecycle()
    val geometries by viewModel.territoryGeometries.collectAsStateWithLifecycle()
    val imageUrls by viewModel.territoryImageUrls.collectAsStateWithLifecycle()
    val role by PermissionManager.currentUserRole.collectAsStateWithLifecycle()
    val canManage = remember(role) { PermissionManager.canManageBrothers }
    var showAdd by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<Person?>(null) }
    var toDelete by remember { mutableStateOf<Person?>(null) }
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun give(person: Person) {
        HapticManager.impact(HapticManager.Impact.Medium)
        AppRouter.openQuickAction(QuickActionResolution.ForPerson(person))
    }

    AppScreen(
        stringResource(R.string.brothers_title),
        leading = { CongregationSwitcher() },
        actions = {
            if (canManage) {
                GlassIconButton(Icons.Rounded.Add, stringResource(R.string.brothers_add_title), { HapticManager.selection(); showAdd = true }, tint = colors.accentDeep)
            }
        },
    ) {
        BrothersControls(viewModel, derived)
        when {
            isLoading && brothers.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.accent) }
            error != null && brothers.isEmpty() -> ContentUnavailable(
                stringResource(R.string.common_error), Icons.Rounded.Warning, description = error,
                actions = { AppButton(stringResource(R.string.common_retry), { scope.launch { viewModel.fetchBrothers() } }) },
            )
            else -> PullToRefreshBox(
                refreshing,
                onRefresh = {
                    refreshing = true
                    scope.launch {
                        viewModel.fetchBrothers()
                        HapticManager.notification(HapticManager.Notification.Success)
                        refreshing = false
                    }
                },
                modifier = Modifier.fillMaxSize(),
            ) {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = AppSpacing.md, end = AppSpacing.md, bottom = AppSpacing.xl + LocalTabBarPadding.current),
                    verticalArrangement = Arrangement.spacedBy(AppSpacing.xxs * 2),
                ) {
                    if (filter == BrotherFilter.All && brothers.isNotEmpty()) {
                        item(key = "summary") {
                            BrothersSummaryCard(derived.holderCount, derived.enabledCount, derived.assignmentDays, Modifier.appear(0).padding(bottom = AppSpacing.xs))
                        }
                    }
                    if (derived.display.isEmpty()) {
                        item(key = "empty") {
                            Column(Modifier.padding(top = AppSpacing.lg), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm), horizontalAlignment = Alignment.CenterHorizontally) {
                                CartoEmptyState(Icons.Rounded.PersonOff, stringResource(R.string.brothers_empty_filtered))
                                if (filter != BrotherFilter.All || search.isNotEmpty()) {
                                    AppButton(stringResource(R.string.brothers_clear_filters), {
                                        HapticManager.selection()
                                        viewModel.searchText.value = ""
                                        viewModel.filter.value = BrotherFilter.All
                                    })
                                }
                            }
                        }
                    } else {
                        items(derived.display, key = { it.id }) { brother ->
                            val leading = if (brother.enabled) listOf(
                                SwipeAction(stringResource(R.string.brothers_give), Icons.AutoMirrored.Rounded.Send, colors.accent) { give(brother) },
                            ) else emptyList()
                            val trailing = if (canManage) listOf(
                                SwipeAction(stringResource(R.string.common_delete), Icons.Rounded.Delete, colors.danger) { HapticManager.selection(); toDelete = brother },
                                SwipeAction(stringResource(R.string.common_edit), Icons.Rounded.Edit, colors.accent) { HapticManager.selection(); editing = brother },
                            ) else emptyList()
                            SwipeActionsRow(trailing, leadingActions = leading, modifier = Modifier.animateItem()) {
                                BrotherCard(
                                    person = brother,
                                    isExpanded = brother.id in expanded,
                                    onToggle = { viewModel.toggleExpanded(brother.id) },
                                    onGive = { give(brother) },
                                    onEdit = if (canManage) ({ HapticManager.selection(); editing = brother }) else null,
                                    geometry = { geometries[it] },
                                    imageUrl = { imageUrls[it] },
                                    onOpenTerritory = { navigator.push(TerritoryDetailRoute(it.territoryId, it.territoryName)) },
                                    modifier = Modifier.alpha(if (isLoading) 0.5f else 1f),
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAdd) AddBrotherSheet(viewModel, onDismiss = { showAdd = false })
    editing?.let { EditBrotherSheet(viewModel, it, onDismiss = { editing = null }) }
    toDelete?.let { person ->
        AppAlert(
            stringResource(R.string.brothers_delete_confirmation),
            confirmText = stringResource(R.string.brothers_delete),
            onConfirm = { toDelete = null; scope.launch { viewModel.deleteBrother(person) } },
            onDismiss = { toDelete = null },
            destructive = true,
        )
    }
}

@Composable
private fun BrothersControls(viewModel: BrothersViewModel, derived: BrothersDerivedState) {
    val colors = AppTheme.colors
    val search by viewModel.searchText.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val sort by viewModel.sortOption.collectAsStateWithLifecycle()
    val ascending by viewModel.sortAscending.collectAsStateWithLifecycle()
    var sortMenu by remember { mutableStateOf(false) }

    Column(Modifier.padding(bottom = AppSpacing.xs), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
        SearchCapsule(search, { viewModel.searchText.value = it }, stringResource(R.string.brothers_search_placeholder), Modifier.padding(horizontal = AppSpacing.md))
        LazyRow(
            contentPadding = PaddingValues(horizontal = AppSpacing.md),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            item {
                Box {
                    Box(Modifier.size(34.dp).glass(CircleShape).bounceClick { sortMenu = true }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.SwapVert, stringResource(R.string.brothers_sort_title), Modifier.size(16.dp), tint = colors.accentDeep)
                    }
                    DropdownMenu(sortMenu, { sortMenu = false }, Modifier.background(colors.surfaceRaised)) {
                        BrotherSortOption.entries.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(stringResource(option.title)) },
                                trailingIcon = { if (option == sort) Icon(Icons.Rounded.Check, null, tint = colors.accent) },
                                onClick = { viewModel.sortOption.value = option; sortMenu = false },
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
            items(BrotherFilter.entries) { option ->
                CountChip(
                    stringResource(option.title),
                    derived.filterCounts[option] ?: 0,
                    selected = option == filter,
                    onClick = { HapticManager.selection(); viewModel.filter.value = option },
                )
            }
        }
    }
}

/** Buscador en cápsula translúcida (mismo formato que el explorador de Territorios). */
@Composable
fun SearchCapsule(value: String, onValueChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(44.dp).glass(CircleShape), contentAlignment = Alignment.CenterStart) {
        SearchField(value, onValueChange, placeholder, Modifier.background(Color.Transparent))
    }
}

@Composable
fun CountChip(title: String, count: Int, selected: Boolean, onClick: () -> Unit) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .height(34.dp)
            .clip(CircleShape)
            .then(if (selected) Modifier.background(colors.accent) else Modifier.glass(CircleShape))
            .bounceClick(onClick = onClick)
            .padding(horizontal = AppSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(title, style = AppType.appCaption.copy(fontWeight = FontWeight.Medium), color = if (selected) Color.White else colors.textPrimary)
        Text(
            count.toString(),
            style = AppType.caption2.copy(fontWeight = FontWeight.Bold),
            color = if (selected) Color.White else colors.accent,
            modifier = Modifier
                .background(if (selected) Color.White.copy(alpha = 0.22f) else colors.accent.copy(alpha = 0.12f), CircleShape)
                .padding(horizontal = 6.dp, vertical = 2.dp),
        )
    }
}

/** "X hermanos tienen · Y territorios" + pictogramas + puntos por urgencia. */
@Composable
private fun BrothersSummaryCard(holderCount: Int, enabledCount: Int, assignmentDays: List<Int>, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val description = stringResource(R.string.brothers_summary_accessibility, holderCount, assignmentDays.size)
    Row(
        modifier.fillMaxWidth().paperCard().padding(AppSpacing.md).semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.md),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.brothers_summary_have, holderCount), style = AppType.appSubheadline, color = colors.textPrimary, maxLines = 1)
            Text(
                stringResource(R.string.brothers_summary_territories, assignmentDays.size),
                style = AppType.title3.copy(fontWeight = FontWeight.ExtraBold),
                color = colors.textPrimary,
                maxLines = 1,
            )
        }
        Box(Modifier.width(1.dp).height(48.dp).background(colors.hairline))
        // Pictogramas 2×6: proporción de hermanos activos con territorio.
        val total = enabledCount.coerceIn(0, 12)
        val green = if (enabledCount == 0) 0 else maxOf(if (holderCount > 0) 1 else 0, (holderCount.toDouble() / enabledCount * total).roundToInt())
        FlowRow(Modifier.width(16.dp * 6).appear(1), horizontalArrangement = Arrangement.spacedBy(3.dp), verticalArrangement = Arrangement.spacedBy(4.dp), maxItemsInEachRow = 6) {
            repeat(total) { i ->
                Icon(Icons.Rounded.Person, null, Modifier.size(13.dp), tint = if (i < green) colors.accent else colors.textSecondary.copy(alpha = 0.4f))
            }
        }
        // Un punto por territorio en uso, coloreado por antigüedad.
        FlowRow(Modifier.weight(1f).appear(2), horizontalArrangement = Arrangement.spacedBy(5.dp), verticalArrangement = Arrangement.spacedBy(5.dp), maxItemsInEachRow = 6) {
            assignmentDays.take(24).forEach { days ->
                Box(Modifier.padding(1.dp).size(7.dp).background(colors.urgency(days), CircleShape))
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BrotherCard(
    person: Person,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    onGive: () -> Unit,
    onEdit: (() -> Unit)?,
    geometry: (Int) -> TerritoryMapGeometry?,
    imageUrl: (Int) -> String?,
    onOpenTerritory: (TerritoryInUse) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val territories = person.territoriesInUse.orEmpty().sortedBy { it.givenDate }
    var menu by remember { mutableStateOf(false) }

    fun primaryTap() {
        if (territories.isNotEmpty()) {
            HapticManager.impact(HapticManager.Impact.Light)
            onToggle()
        } else if (person.enabled) {
            onGive()
        }
    }

    Column(modifier.paperCard().alpha(if (person.enabled) 1f else 0.72f).animateContentSize(spring(dampingRatio = 0.84f, stiffness = 400f))) {
        Box {
            Row(
                Modifier
                    .fillMaxWidth()
                    .combinedClickable(remember { MutableInteractionSource() }, null, onClick = ::primaryTap, onLongClick = { menu = true })
                    .padding(horizontal = AppSpacing.md, vertical = AppSpacing.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            ) {
                InitialsAvatar(person.name, size = 40.dp, tint = person.avatarTint(colors))
                Text(
                    person.name,
                    style = AppType.appHeadline,
                    color = if (person.enabled) colors.textPrimary else colors.textSecondary,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                when {
                    !person.enabled -> Row(
                        Modifier.background(colors.textSecondary.copy(alpha = 0.1f), CircleShape).padding(horizontal = AppSpacing.xs, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Icon(Icons.Rounded.Block, null, Modifier.size(11.dp), tint = colors.textSecondary)
                        Text(stringResource(R.string.brothers_status_inactive), style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold), color = colors.textSecondary)
                    }
                    territories.isEmpty() -> AppButton(
                        stringResource(R.string.brothers_give),
                        onGive,
                        icon = Icons.AutoMirrored.Rounded.Send,
                    )
                    else -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                        val tint = colors.urgency(person.maxDaysHeld ?: 0)
                        Row(
                            Modifier
                                .background(tint.copy(alpha = 0.13f), CircleShape)
                                .border(1.dp, tint.copy(alpha = 0.25f), CircleShape)
                                .padding(horizontal = AppSpacing.xs, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(Icons.Rounded.Map, null, Modifier.size(11.dp), tint = tint)
                            Text(territories.size.toString(), style = AppType.caption.copy(fontWeight = FontWeight.Bold), color = tint)
                        }
                        val rotation by animateFloatAsState(if (isExpanded) -180f else 0f, spring(dampingRatio = 0.78f), label = "chevron")
                        Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(18.dp).graphicsLayer { rotationZ = rotation }, tint = colors.textSecondary)
                    }
                }
            }
            DropdownMenu(menu, { menu = false }, Modifier.background(colors.surfaceRaised)) {
                if (person.enabled) DropdownMenuItem(
                    text = { Text(stringResource(R.string.brothers_give)) },
                    leadingIcon = { Icon(Icons.AutoMirrored.Rounded.Send, null) },
                    onClick = { menu = false; onGive() },
                )
                if (onEdit != null) DropdownMenuItem(
                    text = { Text(stringResource(R.string.brothers_edit_title)) },
                    leadingIcon = { Icon(Icons.Rounded.Edit, null) },
                    onClick = { menu = false; onEdit() },
                )
            }
        }
        AnimatedVisibility(isExpanded && territories.isNotEmpty(), enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
            Column(Modifier.padding(start = AppSpacing.sm, end = AppSpacing.sm, bottom = AppSpacing.sm), verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                territories.forEach { territory ->
                    AssignedTerritoryRow(territory, geometry(territory.territoryId), imageUrl(territory.territoryId)) {
                        HapticManager.selection()
                        onOpenTerritory(territory)
                    }
                }
            }
        }
    }
}

@Composable
private fun AssignedTerritoryRow(territory: TerritoryInUse, geometry: TerritoryMapGeometry?, imageUrl: String?, onOpen: () -> Unit) {
    val colors = AppTheme.colors
    val days = territory.daysHeld()
    val tint = colors.urgency(days)
    val shape = RoundedCornerShape(AppRadius.md)
    Row(
        Modifier
            .fillMaxWidth()
            .background(colors.appBackground.copy(alpha = 0.55f), shape)
            .border(1.dp, colors.hairline, shape)
            .bounceClick(onClick = onOpen)
            .padding(AppSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        val thumbShape = RoundedCornerShape(AppRadius.sm)
        Box(Modifier.size(72.dp, 56.dp).clip(thumbShape).border(1.dp, tint.copy(alpha = 0.28f), thumbShape)) {
            @Composable
            fun Fallback() {
                if (geometry != null) TerritorySnapshotBackdrop(geometry, Modifier.fillMaxSize(), stroke = tint, fill = tint, centersTerritory = true)
                else Box(Modifier.fillMaxSize().background(colors.textSecondary.copy(alpha = 0.1f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Map, null, Modifier.size(20.dp), tint = colors.textSecondary.copy(alpha = 0.35f))
                }
            }
            if (imageUrl != null) SubcomposeAsyncImage(imageUrl, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop, error = { Fallback() }, loading = { Fallback() })
            else Fallback()
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(territory.territoryCode, style = AppType.subheadline.copy(fontWeight = FontWeight.Bold), color = colors.accentDeep)
            Text(territory.territoryName, style = AppType.appSubheadline, color = colors.textPrimary, maxLines = 1)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.AutoMirrored.Rounded.Send, null, Modifier.size(9.dp), tint = colors.textSecondary)
                Text(DateFormats.long(territory.givenDate), style = AppType.caption2, color = colors.textSecondary)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                stringResource(R.string.brothers_days_format, days),
                style = AppType.caption.copy(fontWeight = FontWeight.Bold),
                color = tint,
                modifier = Modifier.background(tint.copy(alpha = 0.13f), CircleShape).padding(horizontal = AppSpacing.xs, vertical = 4.dp),
            )
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.size(14.dp), tint = colors.textSecondary)
        }
    }
}

// MARK: - Alta y edición

@Composable
private fun BrotherSheetScaffold(title: String, onDismiss: () -> Unit, content: @Composable () -> Unit) {
    AppSheet(onDismiss) {
        Box {
            LiquidBackground(Modifier.matchParentSize())
            Column(Modifier.imePadding().navigationBarsPadding().padding(bottom = 20.dp)) {
                Box(Modifier.fillMaxWidth().padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs)) {
                    GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), onDismiss, Modifier.align(Alignment.CenterStart), size = 36.dp)
                    Text(title, style = AppType.headline, color = AppTheme.colors.textPrimary, modifier = Modifier.align(Alignment.Center))
                }
                Spacer(Modifier.height(20.dp))
                content()
            }
        }
    }
}

@Composable
private fun AddBrotherSheet(viewModel: BrothersViewModel, onDismiss: () -> Unit) {
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var name by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    // El error es compartido por las hojas: que no arrastre el de una operación anterior.
    LaunchedEffect(Unit) { viewModel.errorMessage.value = null }
    fun save() {
        if (name.isEmpty()) return
        HapticManager.selection()
        scope.launch {
            if (viewModel.addBrother(name)) {
                HapticManager.notification(HapticManager.Notification.Success)
                onDismiss()
            }
        }
    }
    BrotherSheetScaffold(stringResource(R.string.brothers_add_title), onDismiss) {
        Column(Modifier.padding(horizontal = AppSpacing.md), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            GlassTextField(name, { name = it }, stringResource(R.string.brothers_name), onSubmit = ::save)
            error?.let { Text(it, style = AppType.caption, color = AppTheme.colors.danger) }
            PrimaryButton(stringResource(R.string.brothers_save), ::save, isLoading = isLoading, isDisabled = name.isEmpty())
        }
    }
}

@Composable
private fun EditBrotherSheet(viewModel: BrothersViewModel, person: Person, onDismiss: () -> Unit) {
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var name by remember { mutableStateOf(person.name) }
    var enabled by remember { mutableStateOf(person.enabled) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { viewModel.errorMessage.value = null }
    fun save() {
        if (name.isEmpty()) return
        HapticManager.selection()
        scope.launch {
            if (viewModel.updateBrother(person, name, enabled)) {
                HapticManager.notification(HapticManager.Notification.Success)
                onDismiss()
            }
        }
    }
    BrotherSheetScaffold(stringResource(R.string.brothers_edit_title), onDismiss) {
        Column(Modifier.padding(horizontal = AppSpacing.md), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            GlassTextField(name, { name = it }, stringResource(R.string.brothers_name), label = stringResource(R.string.brothers_name), onSubmit = ::save)
            Box(Modifier.glass(RoundedCornerShape(AppRadius.md))) {
                FormToggleRow(stringResource(R.string.brothers_enabled), enabled, { enabled = it })
            }
            error?.let { Text(it, style = AppType.caption, color = AppTheme.colors.danger) }
            PrimaryButton(stringResource(R.string.brothers_save), ::save, isLoading = isLoading, isDisabled = name.isEmpty())
        }
    }
}

