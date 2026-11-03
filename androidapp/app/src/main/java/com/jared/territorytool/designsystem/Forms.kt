package com.jared.territorytool.designsystem

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// MARK: - Barra superior estilo iOS (título inline + acciones)

@Composable
fun AppTopBar(
    title: String?,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    leading: (@Composable RowScope.() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    Box(
        modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .height(52.dp)
            .padding(horizontal = AppSpacing.sm),
    ) {
        Row(Modifier.align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            if (onBack != null) {
                GlassIconButton(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.common_back), onBack, tint = colors.accentDeep)
            }
            leading?.invoke(this)
        }
        if (title != null) {
            Text(
                title,
                style = AppType.headline,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).widthIn(max = 230.dp),
            )
        }
        Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            actions?.invoke(this)
        }
    }
}

/** Pantalla con fondo cartográfico, barra superior y contenido. */
@Composable
fun AppScreen(
    title: String?,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    leading: (@Composable RowScope.() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    background: @Composable BoxScope.() -> Unit = { LiquidBackground() },
    showTopBar: Boolean = true,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(modifier.fillMaxSize()) {
        background()
        Column(Modifier.fillMaxSize()) {
            if (showTopBar) AppTopBar(title, onBack = onBack, leading = leading, actions = actions)
            content()
        }
    }
}

// MARK: - Formularios agrupados (equivalente a `Form` + `Section`)

@Composable
fun FormScreen(
    title: String?,
    onBack: (() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    AppScreen(title, onBack = onBack, actions = actions) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppSpacing.md)
                .padding(top = AppSpacing.xs, bottom = AppSpacing.xl)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.lg),
            content = content,
        )
    }
}

@Composable
fun FormSection(
    header: String? = null,
    footer: String? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = AppTheme.colors
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (header != null) {
            Text(
                header.uppercase(),
                style = AppType.footnote,
                color = colors.textSecondary,
                modifier = Modifier.padding(start = AppSpacing.md),
            )
        }
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(AppRadius.md + 2.dp))
                .background(colors.surface),
            content = content,
        )
        if (footer != null) {
            Text(footer, style = AppType.footnote, color = colors.textSecondary, modifier = Modifier.padding(horizontal = AppSpacing.md))
        }
    }
}

@Composable
fun FormDivider() {
    Box(Modifier.fillMaxWidth().padding(start = AppSpacing.md).height(0.6.dp).background(AppTheme.colors.hairline))
}

@Composable
fun FormRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .then(if (onClick != null) Modifier.clickable(enabled = enabled, onClick = onClick) else Modifier)
            .padding(horizontal = AppSpacing.md, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        content = content,
    )
}

@Composable
fun FormNavRow(title: String, icon: ImageVector? = null, trailing: String? = null, onClick: () -> Unit) {
    val colors = AppTheme.colors
    FormRow(onClick = onClick) {
        if (icon != null) Icon(icon, null, Modifier.size(22.dp), tint = colors.accent)
        Text(title, style = AppType.body, color = colors.textPrimary, modifier = Modifier.weight(1f))
        if (trailing != null) Text(trailing, style = AppType.body, color = colors.textSecondary)
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.size(20.dp), tint = colors.textSecondary.copy(alpha = 0.6f))
    }
}

@Composable
fun FormButtonRow(title: String, onClick: () -> Unit, destructive: Boolean = false, enabled: Boolean = true, centered: Boolean = false, loading: Boolean = false) {
    val colors = AppTheme.colors
    val color = if (destructive) colors.danger else colors.accent
    FormRow(onClick = onClick, enabled = enabled && !loading) {
        if (centered) Spacer(Modifier.weight(1f))
        if (loading) androidx.compose.material3.CircularProgressIndicator(Modifier.size(18.dp), color = color, strokeWidth = 2.dp)
        else Text(title, style = AppType.body, color = color.copy(alpha = if (enabled) 1f else 0.4f))
        if (centered) Spacer(Modifier.weight(1f))
    }
}

@Composable
fun FormToggleRow(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit, subtitle: String? = null) {
    val colors = AppTheme.colors
    FormRow(onClick = { onCheckedChange(!checked) }) {
        Column(Modifier.weight(1f)) {
            Text(title, style = AppType.body, color = colors.textPrimary)
            if (subtitle != null) Text(subtitle, style = AppType.caption, color = colors.textSecondary)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedTrackColor = colors.accent, checkedThumbColor = Color.White),
        )
    }
}

/** Selector tipo menú (equivalente a `Picker` con `.menu`). */
@Composable
fun <T> FormMenuPickerRow(title: String, options: List<T>, selected: T, label: @Composable (T) -> String, onSelect: (T) -> Unit) {
    val colors = AppTheme.colors
    var expanded by remember { mutableStateOf(false) }
    Box {
        FormRow(onClick = { expanded = true }) {
            Text(title, style = AppType.body, color = colors.textPrimary, modifier = Modifier.weight(1f))
            Text(label(selected), style = AppType.body, color = colors.textSecondary)
            Icon(Icons.Rounded.UnfoldMore, null, Modifier.size(16.dp), tint = colors.textSecondary)
        }
        DropdownMenu(expanded, onDismissRequest = { expanded = false }, modifier = Modifier.background(colors.surfaceRaised)) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(label(option), style = AppType.body, color = colors.textPrimary) },
                    trailingIcon = { if (option == selected) Icon(Icons.Rounded.Check, null, tint = colors.accent) },
                    onClick = { expanded = false; onSelect(option) },
                )
            }
        }
    }
}

/** Control segmentado estilo iOS. */
@Composable
fun <T> SegmentedControl(
    options: List<T>,
    selected: T,
    label: @Composable (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(9.dp))
            .background(colors.textSecondary.copy(alpha = 0.12f))
            .padding(2.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            val bg by animateColorAsState(if (isSelected) colors.surfaceRaised else Color.Transparent, label = "seg")
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(7.dp))
                    .background(bg)
                    .clickable { onSelect(option) }
                    .padding(vertical = 7.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label(option),
                    style = AppType.footnote.copy(fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium),
                    color = colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Chip de filtro en cápsula. */
@Composable
fun FilterChip(text: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier, tint: Color = AppTheme.colors.accent, icon: ImageVector? = null) {
    val colors = AppTheme.colors
    Row(
        modifier
            .clip(CircleShape)
            .background(if (selected) tint else colors.surface)
            .then(if (!selected) Modifier.background(colors.surface) else Modifier)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Icon(icon, null, Modifier.size(14.dp), tint = if (selected) Color.White else tint)
        Text(text, style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = if (selected) Color.White else colors.textPrimary, maxLines = 1)
    }
}

// MARK: - Alertas

@Composable
fun AppAlert(
    title: String,
    message: String? = null,
    confirmText: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    dismissText: String? = stringResource(R.string.common_cancel),
    destructive: Boolean = false,
    content: (@Composable () -> Unit)? = null,
) {
    val colors = AppTheme.colors
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surfaceRaised,
        title = { Text(title, style = AppType.headline, color = colors.textPrimary) },
        text = if (message != null || content != null) {
            {
                Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                    if (message != null) Text(message, style = AppType.subheadline, color = colors.textSecondary)
                    content?.invoke()
                }
            }
        } else null,
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(confirmText, style = AppType.body.copy(fontWeight = FontWeight.SemiBold), color = if (destructive) colors.danger else colors.accent)
            }
        },
        dismissButton = dismissText?.let {
            { TextButton(onClick = onDismiss) { Text(it, style = AppType.body, color = colors.accent) } }
        },
    )
}

// MARK: - Acciones de deslizamiento (equivalente a `.swipeActions`)

data class SwipeAction(val label: String, val icon: ImageVector, val color: Color, val onClick: () -> Unit)

/**
 * Fila que revela botones al deslizar (izquierda = `actions`, derecha = `leadingActions`),
 * como `.swipeActions` en iOS. Sin acciones, la fila se pinta tal cual.
 */
@Composable
fun SwipeActionsRow(
    actions: List<SwipeAction>,
    modifier: Modifier = Modifier,
    leadingActions: List<SwipeAction> = emptyList(),
    shape: RoundedCornerShape = RoundedCornerShape(AppRadius.lg),
    content: @Composable () -> Unit,
) {
    if (actions.isEmpty() && leadingActions.isEmpty()) {
        Box(modifier) { content() }
        return
    }
    val density = LocalDensity.current
    val actionWidth = 76.dp
    val maxTrailing = with(density) { (actionWidth * actions.size).toPx() }
    val maxLeading = with(density) { (actionWidth * leadingActions.size).toPx() }
    val offset = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()

    @Composable
    fun ActionButton(action: SwipeAction) {
        Column(
            Modifier
                .width(actionWidth)
                .fillMaxHeight()
                .background(action.color)
                .clickable {
                    scope.launch { offset.animateTo(0f, spring()) }
                    action.onClick()
                },
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(action.icon, action.label, Modifier.size(20.dp), tint = Color.White)
            Text(action.label, style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1)
        }
    }

    Box(modifier.clip(shape)) {
        Row(Modifier.matchParentSize()) {
            if (offset.value > 0) leadingActions.forEach { ActionButton(it) }
            Spacer(Modifier.weight(1f))
            if (offset.value < 0) actions.forEach { ActionButton(it) }
        }
        Box(
            Modifier
                .offset { IntOffset(offset.value.roundToInt(), 0) }
                .pointerInput(maxTrailing, maxLeading) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            scope.launch {
                                val target = when {
                                    offset.value < -maxTrailing / 2 -> -maxTrailing
                                    offset.value > maxLeading / 2 -> maxLeading
                                    else -> 0f
                                }
                                offset.animateTo(target, spring(dampingRatio = 0.85f))
                            }
                        },
                        onHorizontalDrag = { change, delta ->
                            change.consume()
                            scope.launch { offset.snapTo((offset.value + delta).coerceIn(-maxTrailing * 1.1f, maxLeading * 1.1f)) }
                        },
                    )
                },
        ) { content() }
    }
}

val ZeroPadding = PaddingValues(0.dp)
