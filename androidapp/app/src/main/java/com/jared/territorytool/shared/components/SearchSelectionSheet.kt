package com.jared.territorytool.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.FormDivider
import com.jared.territorytool.designsystem.GlassIconButton
import kotlinx.coroutines.launch

/** Hoja modal con estilo de la app (equivale a `.sheet`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppSheet(
    onDismiss: () -> Unit,
    skipPartiallyExpanded: Boolean = true,
    sheetState: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = skipPartiallyExpanded),
    content: @Composable () -> Unit,
) {
    val colors = AppTheme.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.appBackground,
        contentColor = colors.textPrimary,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
    ) {
        content()
    }
}

@Composable
fun SearchField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    filled: Boolean = true,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .then(if (filled) Modifier.background(colors.textSecondary.copy(alpha = 0.12f), RoundedCornerShape(12.dp)) else Modifier)
            .padding(horizontal = AppSpacing.sm, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs),
    ) {
        Icon(Icons.Rounded.Search, null, Modifier.size(18.dp), tint = colors.textSecondary)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = AppType.body.copy(color = colors.textPrimary),
            cursorBrush = SolidColor(colors.accent),
            modifier = Modifier.weight(1f),
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) Text(placeholder, style = AppType.body, color = colors.textSecondary)
                    inner()
                }
            },
        )
        if (value.isNotEmpty()) {
            Icon(Icons.Rounded.Cancel, null, Modifier.size(18.dp).clickable { onValueChange("") }, tint = colors.textSecondary)
        }
    }
}

/** Hoja de búsqueda y selección (equivale a `SearchSelectionSheet`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> SearchSelectionSheet(
    title: String,
    searchText: String,
    onSearchTextChange: (String) -> Unit,
    items: List<T>,
    isLoading: Boolean,
    key: (T) -> Any,
    onSelect: (T) -> Unit,
    onDismiss: () -> Unit,
    row: @Composable (T) -> Unit,
) {
    val colors = AppTheme.colors
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val scope = rememberCoroutineScope()
    fun close(after: () -> Unit = {}) {
        scope.launch { state.hide() }.invokeOnCompletion { onDismiss(); after() }
    }
    AppSheet(onDismiss = onDismiss, skipPartiallyExpanded = false, sheetState = state) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(0.92f).imePadding()) {
            Box(Modifier.fillMaxWidth().padding(horizontal = AppSpacing.md)) {
                GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), { close() }, Modifier.align(Alignment.CenterStart), size = 36.dp)
                Text(title, style = AppType.headline, color = colors.textPrimary, modifier = Modifier.align(Alignment.Center))
            }
            SearchField(searchText, onSearchTextChange, stringResource(R.string.common_search), Modifier.padding(AppSpacing.md))
            when {
                isLoading -> Box(Modifier.fillMaxWidth().padding(AppSpacing.xl), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.accent)
                }
                items.isEmpty() && searchText.isNotEmpty() -> Text(
                    stringResource(R.string.common_no_results),
                    style = AppType.body,
                    color = colors.textSecondary,
                    modifier = Modifier.padding(AppSpacing.md),
                )
                else -> LazyColumn(
                    Modifier
                        .padding(horizontal = AppSpacing.md)
                        .background(colors.surface, RoundedCornerShape(14.dp)),
                ) {
                    items(items, key = key) { item ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .clickable { onSelect(item); close() }
                                .padding(horizontal = AppSpacing.md, vertical = 14.dp),
                        ) { row(item) }
                        FormDivider()
                    }
                }
            }
        }
    }
}
