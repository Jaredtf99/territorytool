package com.jared.territorytool.features.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.QrCodeScanner
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.Strings
import com.jared.territorytool.designsystem.AppCard
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.shared.components.AppSheet
import com.jared.territorytool.shared.components.DateTimeField
import com.jared.territorytool.shared.components.QRScannerDialog
import com.jared.territorytool.shared.components.SearchSelectionSheet
import com.jared.territorytool.shared.components.SelectionRow
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.UndoHandleKind
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

@Composable
fun EditTransactionSheet(transactionEvent: TransactionEvent, onDismiss: () -> Unit, onComplete: suspend () -> Unit) {
    val colors = AppTheme.colors
    val api = DIContainer.apiService
    val tx = transactionEvent.transaction
    var selectedPerson by remember { mutableStateOf<Person?>(Person(tx.personId, tx.personName, true, null)) }
    var selectedTerritory by remember {
        mutableStateOf<Territory?>(Territory(tx.territoryId, "", tx.territoryName, "", null, null, null, null, null))
    }
    var givenDate by remember { mutableStateOf(tx.givenDateUtc) }
    var returnedDate by remember { mutableStateOf(tx.pickedDateUtc) }
    var deliveryFormat by remember { mutableStateOf(tx.deliveryFormat ?: DeliveryFormat.Physical) }
    var didChangeDeliveryFormat by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var allPersons by remember { mutableStateOf(emptyList<Person>()) }
    var allTerritories by remember { mutableStateOf(emptyList<Territory>()) }
    var isLoadingData by remember { mutableStateOf(false) }
    var showPersonSheet by remember { mutableStateOf(false) }
    var personSearch by remember { mutableStateOf("") }
    var showTerritorySheet by remember { mutableStateOf(false) }
    var territorySearch by remember { mutableStateOf("") }
    var showScanner by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        isLoadingData = true
        runCatching {
            coroutineScope {
                val persons = async { api.getPersons(null) }
                val territories = async { api.getTerritories() }
                persons.await() to territories.await()
            }
        }.onSuccess { (persons, territories) ->
            allPersons = persons
            allTerritories = territories
            persons.firstOrNull { it.id == tx.personId }?.let { selectedPerson = it }
            territories.firstOrNull { it.id == tx.territoryId }?.let { selectedTerritory = it }
        }
        isLoadingData = false
    }

    fun selectTerritory(scanned: String) {
        // El valor escaneado suele ser la URL del mapa; si no, el código.
        val sanitized = scanned.replace("&usp=sharing", "")
        val match = allTerritories.firstOrNull { it.mapUrl.replace("&usp=sharing", "") == sanitized }
            ?: allTerritories.firstOrNull { it.code.equals(scanned, ignoreCase = true) }
        if (match != null) {
            selectedTerritory = match
            HapticManager.notification(HapticManager.Notification.Success)
        } else {
            HapticManager.notification(HapticManager.Notification.Error)
            ToastManager.show(Strings.get(R.string.common_no_results), ToastStyle.Error)
        }
    }

    fun save() {
        val person = selectedPerson ?: return
        if (selectedTerritory == null) return
        isSaving = true
        HapticManager.selection()
        scope.launch {
            try {
                // Si el origen no traía el formato y no se ha tocado, no se envía para no pisarlo.
                val format = if (tx.deliveryFormat != null || didChangeDeliveryFormat) deliveryFormat else null
                val handle = api.updateTransactionUndoable(tx.id, person.id, givenDate, returnedDate, format).handle(UndoHandleKind.Domain)
                HapticManager.notification(HapticManager.Notification.Success)
                ToastManager.show("dashboard.edit_transaction.success", ToastStyle.Success, handle, handle.toastDurationMillis)
                onComplete()
                onDismiss()
            } catch (e: Exception) {
                HapticManager.notification(HapticManager.Notification.Error)
                ToastManager.show("common.error", ToastStyle.Error)
                isSaving = false
            }
        }
    }

    AppSheet(onDismiss = onDismiss) {
        Box {
            LiquidBackground(Modifier.matchParentSize())
            Column(Modifier.fillMaxWidth().imePadding().navigationBarsPadding()) {
                Box(Modifier.fillMaxWidth().padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs)) {
                    GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), onDismiss, Modifier.align(Alignment.CenterStart), size = 36.dp)
                    Text(stringResource(R.string.dashboard_edit_transaction_title_generic), style = AppType.headline, color = colors.textPrimary, modifier = Modifier.align(Alignment.Center))
                    Box(Modifier.align(Alignment.CenterEnd)) {
                        if (isSaving) CircularProgressIndicator(Modifier.size(24.dp), color = colors.accent, strokeWidth = 2.dp)
                        else GlassIconButton(
                            Icons.Rounded.Check,
                            stringResource(R.string.common_save),
                            ::save,
                            tint = colors.accent,
                            size = 36.dp,
                            enabled = selectedPerson != null && selectedTerritory != null,
                        )
                    }
                }
                Column(
                    Modifier.verticalScroll(rememberScrollState()).padding(AppSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    SelectionRow(
                        selectedPerson?.name,
                        stringResource(R.string.dashboard_edit_transaction_select_person),
                        Icons.Rounded.Person,
                        onClick = { showPersonSheet = true },
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        SelectionRow(
                            selectedTerritory?.let { if (it.code.isEmpty()) it.name else it.code },
                            stringResource(R.string.dashboard_edit_transaction_select_territory),
                            Icons.Rounded.Map,
                            onClick = { showTerritorySheet = true },
                            modifier = Modifier.weight(1f),
                        )
                        Box(
                            Modifier
                                .size(50.dp)
                                .shadow(5.dp, RoundedCornerShape(12.dp), ambientColor = colors.accent.copy(alpha = 0.3f), spotColor = colors.accent.copy(alpha = 0.3f))
                                .background(colors.accent, RoundedCornerShape(12.dp))
                                .bounceClick { showScanner = true },
                            contentAlignment = Alignment.Center,
                        ) { Icon(Icons.Rounded.QrCodeScanner, null, Modifier.size(24.dp), tint = Color.White) }
                    }

                    AppCard(cornerRadius = 16.dp) {
                        DateLabel(deliveryFormat.icon, stringResource(R.string.delivery_format_title))
                        Row(
                            Modifier.fillMaxWidth().padding(top = AppSpacing.xs).background(colors.hairline.copy(alpha = 0.5f), CircleShape).padding(3.dp),
                            horizontalArrangement = Arrangement.spacedBy(3.dp),
                        ) {
                            DeliveryFormat.entries.forEach { option ->
                                val selected = option == deliveryFormat
                                Row(
                                    Modifier
                                        .weight(1f)
                                        .clip(CircleShape)
                                        .background(if (selected) colors.accent else Color.Transparent)
                                        .bounceClick {
                                            if (!selected) {
                                                HapticManager.selection()
                                                deliveryFormat = option
                                                didChangeDeliveryFormat = true
                                            }
                                        }
                                        .padding(vertical = AppSpacing.xs),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Icon(option.icon, null, Modifier.size(16.dp), tint = if (selected) Color.White else colors.textPrimary)
                                    Text(
                                        stringResource(option.titleRes),
                                        style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                                        color = if (selected) Color.White else colors.textPrimary,
                                    )
                                }
                            }
                        }
                    }

                    AppCard(cornerRadius = 16.dp) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            DateLabel(Icons.AutoMirrored.Rounded.ArrowForward, stringResource(R.string.dashboard_edit_transaction_given_date), Modifier.weight(1f))
                            PillButton(stringResource(R.string.common_today)) { givenDate = Instant.now() }
                        }
                        DateTimeField(givenDate, { givenDate = it }, Modifier.align(Alignment.CenterHorizontally).padding(top = AppSpacing.xs))
                    }

                    AppCard(cornerRadius = 16.dp) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                            DateLabel(Icons.AutoMirrored.Rounded.Undo, stringResource(R.string.dashboard_edit_transaction_returned_date), Modifier.weight(1f))
                            if (returnedDate != null) {
                                PillButton(stringResource(R.string.common_today)) { returnedDate = Instant.now() }
                                Icon(Icons.Rounded.Cancel, null, Modifier.size(22.dp).bounceClick { returnedDate = null }, tint = colors.textSecondary)
                            } else {
                                PillButton(stringResource(R.string.common_add)) { returnedDate = Instant.now() }
                            }
                        }
                        returnedDate?.let { date ->
                            DateTimeField(date, { returnedDate = it }, Modifier.align(Alignment.CenterHorizontally).padding(top = AppSpacing.sm))
                        }
                    }
                }
            }
        }
    }

    if (showPersonSheet) {
        SearchSelectionSheet(
            title = stringResource(R.string.dashboard_edit_transaction_select_person),
            searchText = personSearch,
            onSearchTextChange = { personSearch = it },
            items = if (personSearch.isEmpty()) allPersons else allPersons.filter { it.name.contains(personSearch, ignoreCase = true) },
            isLoading = isLoadingData,
            key = { it.id },
            onSelect = { selectedPerson = it },
            onDismiss = { showPersonSheet = false },
        ) { Text(it.name, style = AppType.body, color = colors.textPrimary) }
    }
    if (showTerritorySheet) {
        SearchSelectionSheet(
            title = stringResource(R.string.dashboard_edit_transaction_select_territory),
            searchText = territorySearch,
            onSearchTextChange = { territorySearch = it },
            items = if (territorySearch.isEmpty()) allTerritories else allTerritories.filter {
                it.code.contains(territorySearch, ignoreCase = true) || it.name.contains(territorySearch, ignoreCase = true)
            },
            isLoading = isLoadingData,
            key = { it.id },
            onSelect = { selectedTerritory = it },
            onDismiss = { showTerritorySheet = false },
        ) {
            Row {
                Text(it.code, style = AppType.body.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, maxLines = 1, modifier = Modifier.width(56.dp))
                Text(it.name, style = AppType.body, color = colors.textPrimary)
            }
        }
    }
    if (showScanner) {
        QRScannerDialog(onDismiss = { showScanner = false }, onScan = ::selectTerritory)
    }
}

@Composable
private fun DateLabel(icon: ImageVector, text: String, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, Modifier.size(16.dp), tint = colors.textSecondary)
        Text(text, style = AppType.subheadline, color = colors.textSecondary)
    }
}

@Composable
private fun PillButton(text: String, onClick: () -> Unit) {
    Text(
        text,
        style = AppType.caption2.copy(fontWeight = FontWeight.Bold),
        color = Color.White,
        modifier = Modifier
            .background(AppTheme.colors.accent, CircleShape)
            .bounceClick(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}
