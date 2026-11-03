package com.jared.territorytool.features.quickaction

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.PersonAddAlt1
import androidx.compose.material.icons.rounded.PersonOff
import androidx.compose.material.icons.rounded.WrongLocation
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.CartoEmptyState
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.shared.models.Person
import com.jared.territorytool.shared.models.Territory

/** Entregar un territorio libre: elegir persona. */
@Composable
fun QuickActionPickPersonScreen(territory: Territory, @Suppress("UNUSED_PARAMETER") onDone: () -> Unit, onClose: (() -> Unit)?) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val vm: QuickActionPickerViewModel = viewModel(factory = QuickActionPickerViewModel.Factory(QuickActionPickerViewModel.Mode.Persons))
    val persons by vm.persons.collectAsStateWithLifecycle()
    val isLoading by vm.isLoading.collectAsStateWithLifecycle()
    val search by vm.search.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { if (vm.persons.value.isEmpty()) vm.loadInitial() }

    QuickActionScreen(
        stringResource(R.string.assignment_title),
        onClose,
        bottomBar = { QuickActionSearchBar(stringResource(R.string.quick_action_search_publisher), search, { vm.search.value = it }) },
    ) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = AppSpacing.md).padding(top = AppSpacing.sm, bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        ) {
            CompactTerritoryRow(territory, Modifier.appear(0), accessory = CompactRowAccessory.None)
            QASectionHeader(stringResource(R.string.quick_action_who_deliver), Icons.Rounded.PersonAddAlt1)
            when {
                isLoading && persons.isEmpty() -> Box(Modifier.fillMaxWidth().padding(vertical = AppSpacing.lg), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.accent)
                }
                persons.isEmpty() -> CartoEmptyState(Icons.Rounded.PersonOff, stringResource(R.string.common_no_results))
                else -> Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                    persons.forEach { person ->
                        PersonQuickRow(person, Modifier.bounceClick {
                            HapticManager.selection()
                            navigator.push(ConfirmRoute(QuickActionAction.Deliver(territory, person.name)))
                        })
                    }
                }
            }
        }
    }
}

/** Persona seleccionada: recoger uno de sus territorios o entregar otro. */
@Composable
fun QuickActionPersonScreen(person: Person, @Suppress("UNUSED_PARAMETER") onDone: () -> Unit, onClose: (() -> Unit)?) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val vm: QuickActionPickerViewModel = viewModel(factory = QuickActionPickerViewModel.Factory(QuickActionPickerViewModel.Mode.FreeTerritories))
    val territories by vm.territories.collectAsStateWithLifecycle()
    val isLoading by vm.isLoading.collectAsStateWithLifecycle()
    val search by vm.search.collectAsStateWithLifecycle()
    var pickTerritory by rememberSaveable { mutableStateOf(!person.hasActiveTerritory) }

    LaunchedEffect(pickTerritory) { if (pickTerritory) vm.loadInitial() }

    fun switchToPick() {
        pickTerritory = true
        vm.loadInitial()
    }

    QuickActionScreen(
        person.name,
        onClose,
        bottomBar = if (pickTerritory) ({ QuickActionSearchBar(stringResource(R.string.quick_action_search_territory), search, { vm.search.value = it }) }) else null,
    ) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = AppSpacing.md).padding(top = AppSpacing.sm, bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.lg),
        ) {
            PersonHero(person, Modifier.appear(0))
            if (!pickTerritory) {
                Column(Modifier.appear(1), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                    QASectionHeader(stringResource(R.string.quick_action_return_one), Icons.Rounded.MoveToInbox, colors.accentSecondary)
                    Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                        person.territoriesInUse.orEmpty().forEach { assignment ->
                            val territory = assignment.asTerritory(person.name)
                            CompactTerritoryRow(territory, Modifier.bounceClick {
                                HapticManager.selection()
                                navigator.push(ConfirmRoute(QuickActionAction.Return(territory)) {
                                    // Recogido: continúa entregando otro a esta misma persona.
                                    navigator.pop()
                                    switchToPick()
                                })
                            })
                        }
                    }
                }
                ActionPromptCard(
                    Icons.AutoMirrored.Rounded.Send,
                    stringResource(R.string.quick_action_deliver_other_territory),
                    stringResource(R.string.quick_action_deliver_other_hint),
                    Modifier.appear(2).bounceClick { HapticManager.selection(); switchToPick() },
                    tint = colors.accent,
                )
            } else {
                Column(Modifier.appear(1), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                    QASectionHeader(stringResource(R.string.quick_action_choose_territory), Icons.Rounded.Eco)
                    when {
                        isLoading && territories.isEmpty() -> Box(Modifier.fillMaxWidth().padding(vertical = AppSpacing.lg), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = colors.accent)
                        }
                        territories.isEmpty() -> CartoEmptyState(Icons.Rounded.WrongLocation, stringResource(R.string.common_no_results))
                        else -> Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                            territories.forEach { territory ->
                                CompactTerritoryRow(territory, Modifier.bounceClick {
                                    HapticManager.selection()
                                    navigator.push(ConfirmRoute(QuickActionAction.Deliver(territory, person.name)))
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
