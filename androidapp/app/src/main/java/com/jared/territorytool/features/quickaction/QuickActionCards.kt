package com.jared.territorytool.features.quickaction

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.GradientIconCircle
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.TerritoryStatusIcon
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.designsystem.rememberStatusPresentation
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.TerritoryOperationalStatus

sealed interface CompactRowAccessory {
    data object Chevron : CompactRowAccessory
    data class Selection(val on: Boolean) : CompactRowAccessory
    data object None : CompactRowAccessory
}

@Composable
private fun Accessory(accessory: CompactRowAccessory) {
    val colors = AppTheme.colors
    when (accessory) {
        CompactRowAccessory.Chevron -> Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.size(18.dp), tint = colors.textSecondary)
        is CompactRowAccessory.Selection -> Icon(
            if (accessory.on) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
            null,
            Modifier.size(24.dp),
            tint = if (accessory.on) colors.accent else colors.textSecondary.copy(alpha = 0.4f),
        )
        CompactRowAccessory.None -> Unit
    }
}

/** Fila de territorio compacta: icono de estado + código + nombre + línea de estado. */
@Composable
fun CompactTerritoryRow(territory: Territory, modifier: Modifier = Modifier, accessory: CompactRowAccessory = CompactRowAccessory.Chevron) {
    val colors = AppTheme.colors
    val status = territory.operationalStatus()
    val presentation = rememberStatusPresentation(status)
    val detail = when (status) {
        TerritoryOperationalStatus.Available -> territory.daysFree()?.let { stringResource(R.string.quick_action_free_since, it) }
            ?: stringResource(R.string.territory_status_available)
        is TerritoryOperationalStatus.Assigned -> stringResource(R.string.quick_action_assigned_days, territory.personName ?: "", status.days)
        is TerritoryOperationalStatus.Attention -> stringResource(R.string.quick_action_assigned_days, territory.personName ?: "", status.days)
    }
    val selected = (accessory as? CompactRowAccessory.Selection)?.on == true
    val shape = RoundedCornerShape(AppRadius.lg)
    Row(
        modifier
            .fillMaxWidth()
            .background(colors.surface, shape)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) colors.accent else colors.hairline, shape)
            .padding(AppSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Box(Modifier.size(38.dp), contentAlignment = Alignment.Center) { TerritoryStatusIcon(presentation) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(territory.code, style = AppType.subheadline.copy(fontWeight = FontWeight.Bold), color = presentation.color)
                Text(territory.name, style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary, maxLines = 1)
            }
            Text(detail, style = AppType.appCaption, color = colors.textSecondary, maxLines = 1)
        }
        Accessory(accessory)
    }
}

/** Fila de persona compacta: avatar + nombre + estado operativo. */
@Composable
fun PersonQuickRow(person: Person, modifier: Modifier = Modifier, accessory: CompactRowAccessory = CompactRowAccessory.Chevron) {
    val colors = AppTheme.colors
    val tint = if (person.hasActiveTerritory) colors.accentSecondary else colors.accent
    val active = person.primaryActiveTerritory
    val subtitle = when {
        active == null -> stringResource(R.string.quick_action_person_no_territory)
        person.activeTerritoryCount > 1 -> stringResource(R.string.quick_action_person_territory_count, person.activeTerritoryCount)
        else -> stringResource(R.string.quick_action_has_territory, active.territoryCode)
    }
    val selected = (accessory as? CompactRowAccessory.Selection)?.on == true
    val shape = RoundedCornerShape(AppRadius.lg)
    Row(
        modifier
            .fillMaxWidth()
            .background(colors.surface, shape)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) colors.accent else colors.hairline, shape)
            .padding(AppSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        InitialsAvatar(person.name, size = 38.dp, tint = tint)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(person.name, style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary, maxLines = 1)
            Text(subtitle, style = AppType.appCaption, color = colors.textSecondary, maxLines = 1)
        }
        Accessory(accessory)
    }
}

/** Barra de búsqueda anclada abajo (cápsula translúcida a ancho completo). */
@Composable
fun QuickActionSearchBar(
    placeholder: String,
    text: String,
    onTextChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester = FocusRequester(),
    onFocusChange: (Boolean) -> Unit = {},
) {
    val colors = AppTheme.colors
    Box(modifier.fillMaxWidth().navigationBarsPadding().imePadding().padding(horizontal = AppSpacing.sm).padding(bottom = AppSpacing.xs)) {
        Row(
            Modifier.fillMaxWidth().height(52.dp).glass(CircleShape).padding(horizontal = AppSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            Icon(Icons.Rounded.Search, null, Modifier.size(20.dp), tint = colors.textSecondary)
            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                singleLine = true,
                textStyle = AppType.appBody.copy(color = colors.textPrimary),
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search, autoCorrectEnabled = false, capitalization = KeyboardCapitalization.None),
                modifier = Modifier.weight(1f).focusRequester(focusRequester).onFocusChanged { onFocusChange(it.isFocused) },
                decorationBox = { inner ->
                    Box {
                        if (text.isEmpty()) Text(placeholder, style = AppType.appBody, color = colors.textSecondary)
                        inner()
                    }
                },
            )
            if (text.isNotEmpty()) {
                Icon(Icons.Rounded.Cancel, stringResource(R.string.common_clear), Modifier.size(22.dp).bounceClick { onTextChange("") }, tint = colors.textSecondary)
            }
        }
    }
}

/** Cabecera de sección simple (sin línea de puntos). */
@Composable
fun QASectionHeader(title: String, icon: ImageVector, tint: Color = AppTheme.colors.accent) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        Icon(icon, null, Modifier.size(18.dp), tint = tint)
        Text(title, style = AppType.headline.copy(fontWeight = FontWeight.Bold), color = AppTheme.colors.textPrimary, maxLines = 1)
    }
}

/** Cabecera de persona: avatar grande + nombre + nº de territorios. */
@Composable
fun PersonHero(person: Person, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Row(
        modifier.fillMaxWidth().paperCard(AppRadius.xl).padding(AppSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        InitialsAvatar(person.name, size = 52.dp, tint = if (person.hasActiveTerritory) colors.accentSecondary else colors.accent)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(person.name, style = AppType.title3.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, maxLines = 1)
            Text(
                if (person.hasActiveTerritory) stringResource(R.string.quick_action_person_territory_count, person.activeTerritoryCount)
                else stringResource(R.string.quick_action_person_no_territory),
                style = AppType.appSubheadline,
                color = colors.textSecondary,
            )
        }
    }
}

/** Tarjeta-prompt de acción: icono + título + subtítulo + chevron. */
@Composable
fun ActionPromptCard(icon: ImageVector, title: String, subtitle: String, modifier: Modifier = Modifier, tint: Color = AppTheme.colors.accentDeep) {
    val colors = AppTheme.colors
    Row(
        modifier.fillMaxWidth().paperCard(AppRadius.lg).padding(AppSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        GradientIconCircle(icon, tint, size = 40.dp, iconSize = 17.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = AppType.appHeadline, color = colors.textPrimary)
            Text(subtitle, style = AppType.appCaption, color = colors.textSecondary)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = colors.textSecondary)
    }
}
