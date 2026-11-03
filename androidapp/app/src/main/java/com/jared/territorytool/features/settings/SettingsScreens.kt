package com.jared.territorytool.features.settings

import android.text.format.Formatter
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.Apartment
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.ManageAccounts
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.AppLanguage
import com.jared.territorytool.core.AppTheme as ThemeOption
import com.jared.territorytool.core.CongregationStore
import com.jared.territorytool.core.LanguageManager
import com.jared.territorytool.core.ThemeManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.core.network.CongregationSummary
import com.jared.territorytool.core.network.SupabaseAuthService
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.FormButtonRow
import com.jared.territorytool.designsystem.FormDivider
import com.jared.territorytool.designsystem.FormMenuPickerRow
import com.jared.territorytool.designsystem.FormNavRow
import com.jared.territorytool.designsystem.FormRow
import com.jared.territorytool.designsystem.FormScreen
import com.jared.territorytool.designsystem.FormSection
import com.jared.territorytool.designsystem.GlassTextField
import com.jared.territorytool.designsystem.SegmentedControl
import com.jared.territorytool.designsystem.SwipeAction
import com.jared.territorytool.designsystem.SwipeActionsRow
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.features.main.ChangePasswordRoute
import com.jared.territorytool.features.main.CongregationsRoute
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.features.main.TerritoryReportRoute
import com.jared.territorytool.features.main.UsersRoute
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.map.TerritorySnapshotCache
import com.jared.territorytool.shared.utils.PermissionManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen() {
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val theme by ThemeManager.currentTheme.collectAsStateWithLifecycle()
    val language by LanguageManager.currentLanguage.collectAsStateWithLifecycle()
    val role by PermissionManager.currentUserRole.collectAsStateWithLifecycle()
    var showLogout by remember { mutableStateOf(false) }
    var showClearCache by remember { mutableStateOf(false) }
    var cacheBytes by remember { mutableLongStateOf(0L) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { cacheBytes = TerritorySnapshotCache.diskSizeBytes(context) }

    val canManageUsers = remember(role) { PermissionManager.canManageUsers }
    val canManageCongregations = remember(role) { PermissionManager.canManageCongregations }

    FormScreen(stringResource(R.string.settings_title), onBack = navigator::pop) {
        if (canManageUsers || canManageCongregations) {
            FormSection(stringResource(R.string.settings_administration)) {
                if (canManageUsers) FormNavRow(stringResource(R.string.users_title), Icons.Rounded.ManageAccounts) { navigator.push(UsersRoute) }
                if (canManageUsers && canManageCongregations) FormDivider()
                if (canManageCongregations) FormNavRow(stringResource(R.string.congregations_title), Icons.Rounded.Apartment) { navigator.push(CongregationsRoute) }
            }
        }

        FormSection(stringResource(R.string.settings_reports)) {
            FormNavRow(stringResource(R.string.reports_title), Icons.Rounded.Description) { navigator.push(TerritoryReportRoute) }
        }

        FormSection(stringResource(R.string.settings_appearance)) {
            Box(Modifier.padding(12.dp)) {
                SegmentedControl(ThemeOption.entries, theme, { stringResource(it.title) }, ThemeManager::set)
            }
        }

        FormSection(stringResource(R.string.settings_language)) {
            FormMenuPickerRow(stringResource(R.string.settings_language), AppLanguage.entries, language, { it.displayName }, LanguageManager::set)
        }

        FormSection(stringResource(R.string.settings_storage), footer = stringResource(R.string.settings_map_cache_description)) {
            FormRow {
                Icon(Icons.Rounded.Map, null, Modifier.size(22.dp), tint = AppTheme.colors.accent)
                Text(stringResource(R.string.settings_map_cache_title), style = AppType.body, color = AppTheme.colors.textPrimary, modifier = Modifier.weight(1f))
                Text(Formatter.formatFileSize(context, cacheBytes), style = AppType.body, color = AppTheme.colors.textSecondary)
            }
            FormDivider()
            FormButtonRow(stringResource(R.string.settings_map_cache_clear), { showClearCache = true }, destructive = true, enabled = cacheBytes > 0)
        }

        FormSection(stringResource(R.string.settings_account)) {
            FormNavRow(stringResource(R.string.change_password_title), Icons.Rounded.Key) { navigator.push(ChangePasswordRoute) }
            FormDivider()
            FormButtonRow(stringResource(R.string.logout_title), { showLogout = true }, destructive = true)
        }

        Box(Modifier.padding(bottom = LocalTabBarPadding.current))
    }

    if (showLogout) {
        AppAlert(
            stringResource(R.string.logout_title),
            stringResource(R.string.settings_logout_confirmation),
            stringResource(R.string.logout_title),
            onConfirm = { showLogout = false; AppEvents.post(AppEvent.UserRequestedLogout) },
            onDismiss = { showLogout = false },
            dismissText = stringResource(R.string.cancel),
            destructive = true,
        )
    }
    if (showClearCache) {
        AppAlert(
            stringResource(R.string.settings_map_cache_clear),
            stringResource(R.string.settings_map_cache_clear_confirmation),
            stringResource(R.string.settings_map_cache_clear),
            onConfirm = {
                showClearCache = false
                scope.launch {
                    TerritorySnapshotCache.clear(context)
                    cacheBytes = TerritorySnapshotCache.diskSizeBytes(context)
                }
            },
            onDismiss = { showClearCache = false },
            dismissText = stringResource(R.string.cancel),
            destructive = true,
        )
    }
}

@Composable
fun ChangePasswordScreen() {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    var newPassword by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val isValid = newPassword.length >= 4 && newPassword == confirm

    FormScreen(stringResource(R.string.change_password_title), onBack = navigator::pop) {
        FormSection(stringResource(R.string.change_password_new)) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                GlassTextField(newPassword, { newPassword = it }, stringResource(R.string.change_password_new_placeholder), isPassword = true)
                GlassTextField(confirm, { confirm = it }, stringResource(R.string.change_password_confirm_placeholder), isPassword = true)
            }
        }
        if (newPassword.isNotEmpty() && newPassword != confirm) {
            Text(stringResource(R.string.change_password_mismatch), style = AppType.caption, color = colors.danger, modifier = Modifier.padding(horizontal = 16.dp))
        }
        FormSection {
            FormButtonRow(
                stringResource(R.string.change_password_save),
                {
                    saving = true
                    scope.launch {
                        try {
                            SupabaseAuthService.changeOwnPassword(newPassword)
                            ToastManager.show("change_password.success", ToastStyle.Success)
                            navigator.pop()
                        } catch (e: Exception) {
                            error = e.localizedMessage
                        } finally {
                            saving = false
                        }
                    }
                },
                enabled = isValid,
                centered = true,
                loading = saving,
            )
        }
    }
    error?.let {
        AppAlert(stringResource(R.string.common_error), it, stringResource(R.string.common_ok), { error = null }, { error = null }, dismissText = null)
    }
}

class CongregationsManagementViewModel : ViewModel() {
    val congregations = MutableStateFlow<List<CongregationSummary>>(emptyList())
    val isLoading = MutableStateFlow(false)

    init {
        viewModelScope.launch { load() }
    }

    suspend fun load() {
        isLoading.value = true
        CongregationStore.refresh()
        congregations.value = CongregationStore.congregations.value
        isLoading.value = false
    }

    suspend fun create(name: String) {
        SupabaseAuthService.createCongregation(name.trim())
        load()
    }

    suspend fun rename(id: String, name: String) {
        SupabaseAuthService.renameCongregation(id, name.trim())
        load()
    }

    suspend fun delete(id: String) {
        SupabaseAuthService.deleteCongregation(id)
        load()
    }
}

@Composable
fun CongregationsManagementScreen(viewModel: CongregationsManagementViewModel = viewModel()) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val congregations by viewModel.congregations.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    var newName by remember { mutableStateOf("") }
    var renameTarget by remember { mutableStateOf<CongregationSummary?>(null) }
    var renameText by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val existsMsg = stringResource(R.string.congregations_error_exists)
    val notEmptyMsg = stringResource(R.string.congregations_error_not_empty)

    fun present(e: Exception) {
        val raw = e.localizedMessage ?: ""
        error = when {
            raw.contains("CONGREGATION_ALREADY_EXISTS") -> existsMsg
            raw.contains("CONGREGATION_NOT_EMPTY") -> notEmptyMsg
            else -> raw
        }
    }

    Box {
        FormScreen(stringResource(R.string.congregations_title), onBack = navigator::pop) {
            FormSection(stringResource(R.string.congregations_new)) {
                FormRow {
                    GlassTextField(newName, { newName = it }, stringResource(R.string.congregations_name_placeholder), Modifier.weight(1f))
                    Icon(
                        Icons.Rounded.AddCircle,
                        stringResource(R.string.common_add),
                        Modifier.size(30.dp).bounceClick(newName.isNotBlank()) {
                            val name = newName
                            scope.launch {
                                try { viewModel.create(name); newName = "" } catch (e: Exception) { present(e) }
                            }
                        },
                        tint = colors.accent.copy(alpha = if (newName.isNotBlank()) 1f else 0.4f),
                    )
                }
            }
            FormSection(stringResource(R.string.congregations_title)) {
                if (congregations.isEmpty()) {
                    FormRow { Text(stringResource(R.string.congregations_empty), style = AppType.body, color = colors.textSecondary) }
                }
                congregations.forEachIndexed { index, congregation ->
                    if (index > 0) FormDivider()
                    SwipeActionsRow(
                        listOf(SwipeAction(stringResource(R.string.common_delete), Icons.Rounded.Delete, colors.danger) {
                            scope.launch { try { viewModel.delete(congregation.id) } catch (e: Exception) { present(e) } }
                        }),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(0.dp),
                    ) {
                        FormRow(Modifier.background(colors.surface)) {
                            Column(Modifier.weight(1f)) {
                                Text(congregation.name, style = AppType.body, color = colors.textPrimary)
                                if (congregation.isActive) Text(stringResource(R.string.congregations_active), style = AppType.caption, color = colors.success)
                            }
                            Icon(
                                Icons.Rounded.Edit,
                                stringResource(R.string.congregations_rename),
                                Modifier.size(22.dp).bounceClick { renameTarget = congregation; renameText = congregation.name },
                                tint = colors.accent,
                            )
                        }
                    }
                }
            }
        }
        if (isLoading) CircularProgressIndicator(Modifier.align(Alignment.Center), color = colors.accent)
    }

    renameTarget?.let { target ->
        AppAlert(
            stringResource(R.string.congregations_rename),
            confirmText = stringResource(R.string.common_save),
            onConfirm = {
                val name = renameText
                renameTarget = null
                scope.launch { try { viewModel.rename(target.id, name) } catch (e: Exception) { present(e) } }
            },
            onDismiss = { renameTarget = null },
        ) {
            GlassTextField(renameText, { renameText = it }, stringResource(R.string.congregations_name_placeholder), Modifier.fillMaxWidth())
        }
    }
    error?.let {
        AppAlert(stringResource(R.string.common_error), it, stringResource(R.string.common_ok), { error = null }, { error = null }, dismissText = null)
    }
}

