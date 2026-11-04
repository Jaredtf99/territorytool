package com.jared.territorytool.features.territories

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.Strings
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.GlassTextField
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.PrimaryButton
import com.jared.territorytool.designsystem.glass
import com.jared.territorytool.shared.components.AppSheet
import com.jared.territorytool.shared.components.ExcludeFromSuggestionsToggle
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.models.Territory
import kotlinx.coroutines.launch

/** Traduce los códigos de error del backend al alta/edición de territorios. */
private fun mapTerritoryError(e: Exception): String {
    val message = e.localizedMessage ?: ""
    return when {
        // El backend actual devuelve un único código para cualquier duplicado (código, nombre o URL).
        "TERRITORY_ALREADY_EXISTS" in message -> Strings.get(R.string.error_territory_already_exists)
        "CODE_EXIST" in message -> Strings.get(R.string.error_territory_code_exists)
        "NAME_EXIST" in message -> Strings.get(R.string.error_territory_name_exists)
        "MAPURL_EXIST" in message -> Strings.get(R.string.error_territory_map_url_exists)
        "TERRITORY_NOT_FOUND" in message -> Strings.get(R.string.error_territory_not_found)
        "INVALID_PARAMETERS" in message -> Strings.get(R.string.error_invalid_parameters)
        else -> "Error: $message"
    }
}

@Composable
fun AddTerritorySheet(onDismiss: () -> Unit) {
    TerritoryFormSheet(
        title = stringResource(R.string.territory_add_title),
        initial = null,
        onDismiss = onDismiss,
    ) { code, name, mapUrl, exclude ->
        val handle = DIContainer.apiService.addTerritoryUndoable(code, name, mapUrl, exclude).handle(UndoHandleKind.Domain)
        ToastManager.show("territory.add.success", ToastStyle.Success, handle, handle.toastDurationMillis)
    }
}

@Composable
fun EditTerritorySheet(territory: Territory, onDismiss: () -> Unit, onSuccess: (() -> Unit)? = null) {
    EditTerritorySheet(territory.id, territory.code, territory.name, territory.mapUrl, territory.excludeFromSuggestions, onDismiss, onSuccess)
}

/**
 * [excludeFromSuggestions] es el valor guardado; `null` si la fuente no lo trae. En ese caso
 * sólo se envía si el usuario lo activa, para no pisar el valor guardado.
 */
@Composable
fun EditTerritorySheet(
    id: Int,
    code: String,
    name: String,
    mapUrl: String,
    excludeFromSuggestions: Boolean?,
    onDismiss: () -> Unit,
    onSuccess: (() -> Unit)? = null,
) {
    TerritoryFormSheet(
        title = stringResource(R.string.territory_edit_title),
        initial = TerritoryFormValues(code, name, mapUrl, excludeFromSuggestions ?: false),
        onDismiss = onDismiss,
    ) { c, n, m, exclude ->
        val toSend = if (excludeFromSuggestions != null || exclude) exclude else null
        val handle = DIContainer.apiService.updateTerritoryUndoable(id, c, n, m, toSend).handle(UndoHandleKind.Domain)
        ToastManager.show("territory.edit.success", ToastStyle.Success, handle, handle.toastDurationMillis)
        HapticManager.notification(HapticManager.Notification.Success)
        onSuccess?.invoke()
    }
}

private data class TerritoryFormValues(val code: String, val name: String, val mapUrl: String, val excludeFromSuggestions: Boolean)

@Composable
private fun TerritoryFormSheet(
    title: String,
    initial: TerritoryFormValues?,
    onDismiss: () -> Unit,
    save: suspend (code: String, name: String, mapUrl: String, excludeFromSuggestions: Boolean) -> Unit,
) {
    val colors = AppTheme.colors
    var code by remember { mutableStateOf(initial?.code ?: "") }
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var mapUrl by remember { mutableStateOf(initial?.mapUrl ?: "") }
    var excludeFromSuggestions by remember { mutableStateOf(initial?.excludeFromSuggestions ?: false) }
    var isLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    AppSheet(onDismiss) {
        Box {
            LiquidBackground(Modifier.matchParentSize())
            Column(Modifier.imePadding().navigationBarsPadding().padding(bottom = 20.dp)) {
                Box(Modifier.fillMaxWidth().padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs)) {
                    GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), onDismiss, Modifier.align(Alignment.CenterStart), size = 36.dp)
                    Text(title, style = AppType.headline, color = colors.textPrimary, modifier = Modifier.align(Alignment.Center))
                }
                Column(Modifier.padding(AppSpacing.md).padding(top = 20.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        GlassTextField(code, { code = it }, stringResource(R.string.territory_code), label = stringResource(R.string.territory_code) + " *", autoCapitalize = false, imeAction = ImeAction.Next)
                        GlassTextField(name, { name = it }, stringResource(R.string.territory_name), label = stringResource(R.string.territory_name) + " *", imeAction = ImeAction.Next)
                        GlassTextField(mapUrl, { mapUrl = it }, stringResource(R.string.territory_mapUrl), label = stringResource(R.string.territory_mapUrl) + " *", keyboardType = KeyboardType.Uri, autoCapitalize = false)
                        ExcludeFromSuggestionsToggle(
                            excludeFromSuggestions,
                            { excludeFromSuggestions = it },
                            Modifier.glass().padding(AppSpacing.md),
                        )
                    }
                    error?.let { Text(it, style = AppType.caption, color = colors.danger, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
                    PrimaryButton(
                        stringResource(R.string.common_save),
                        {
                            isLoading = true
                            error = null
                            scope.launch {
                                try {
                                    save(code, name, mapUrl, excludeFromSuggestions)
                                    onDismiss()
                                } catch (e: Exception) {
                                    error = mapTerritoryError(e)
                                    HapticManager.notification(HapticManager.Notification.Error)
                                } finally {
                                    isLoading = false
                                }
                            }
                        },
                        isLoading = isLoading,
                        isDisabled = name.isEmpty() || code.isEmpty() || mapUrl.isEmpty(),
                    )
                }
            }
        }
    }
}
