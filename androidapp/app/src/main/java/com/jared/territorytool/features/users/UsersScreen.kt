package com.jared.territorytool.features.users

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.HowToReg
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.PersonOff
import androidx.compose.material.icons.rounded.PersonRemove
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.designsystem.AppAlert
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppButtonStyle
import com.jared.territorytool.designsystem.AppScreen
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.ContentUnavailable
import com.jared.territorytool.designsystem.GlassIconButton
import com.jared.territorytool.designsystem.GlassTextField
import com.jared.territorytool.designsystem.LiquidBackground
import com.jared.territorytool.designsystem.PrimaryButton
import com.jared.territorytool.designsystem.SwipeAction
import com.jared.territorytool.designsystem.SwipeActionsRow
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.features.main.LocalTabBarPadding
import com.jared.territorytool.shared.components.AppSheet
import com.jared.territorytool.shared.components.SearchField
import com.jared.territorytool.shared.models.User
import com.jared.territorytool.shared.models.UserRole
import kotlinx.coroutines.launch

@Composable
fun UsersScreen(viewModel: UsersViewModel = viewModel()) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val users by viewModel.users.collectAsStateWithLifecycle()
    val filtered by viewModel.filteredUsers.collectAsStateWithLifecycle()
    val search by viewModel.searchText.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var showAdd by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<User?>(null) }
    var showDeactivated by remember { mutableStateOf(false) }
    var toDelete by remember { mutableStateOf<User?>(null) }
    var menu by remember { mutableStateOf(false) }
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    AppScreen(
        stringResource(R.string.users_title),
        onBack = navigator::pop,
        actions = {
            Box {
                GlassIconButton(Icons.Rounded.MoreHoriz, stringResource(R.string.users_more_options), { menu = true }, tint = colors.accentDeep)
                DropdownMenu(menu, { menu = false }, Modifier.background(colors.surfaceRaised)) {
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.users_deactivated_title)) },
                        leadingIcon = { Icon(Icons.Rounded.PersonOff, null) },
                        onClick = { menu = false; HapticManager.selection(); showDeactivated = true },
                    )
                }
            }
            GlassIconButton(Icons.Rounded.Add, stringResource(R.string.users_add_title), { showAdd = true }, tint = colors.accentDeep)
        },
    ) {
        SearchField(search, { viewModel.searchText.value = it }, stringResource(R.string.users_search_placeholder), Modifier.padding(horizontal = AppSpacing.md))
        PullToRefreshBox(
            refreshing,
            onRefresh = {
                refreshing = true
                scope.launch {
                    viewModel.fetchUsers()
                    HapticManager.notification(HapticManager.Notification.Success)
                    refreshing = false
                }
            },
            modifier = Modifier.fillMaxSize(),
        ) {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = AppSpacing.md, end = AppSpacing.md, top = AppSpacing.sm, bottom = AppSpacing.xl + LocalTabBarPadding.current),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                when {
                    isLoading && users.isEmpty() -> item {
                        Box(Modifier.fillMaxWidth().heightIn(min = 200.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.accent) }
                    }
                    error != null && users.isEmpty() -> item {
                        ContentUnavailable(
                            stringResource(R.string.common_error), Icons.Rounded.Warning, description = error,
                            actions = { AppButton(stringResource(R.string.common_retry), { scope.launch { viewModel.fetchUsers() } }, style = AppButtonStyle.Bordered) },
                        )
                    }
                    filtered.isEmpty() -> item { ContentUnavailable(stringResource(R.string.common_no_results), Icons.Rounded.PersonRemove) }
                    else -> items(filtered, key = { it.id }) { user ->
                        val canEdit = viewModel.canEdit(user)
                        val actions = buildList {
                            if (viewModel.canDelete(user)) add(SwipeAction(stringResource(R.string.common_delete), Icons.Rounded.Delete, colors.danger) { HapticManager.selection(); toDelete = user })
                            if (canEdit) add(SwipeAction(stringResource(R.string.common_edit), Icons.Rounded.Edit, colors.accent) { HapticManager.selection(); editing = user })
                        }
                        SwipeActionsRow(actions, shape = RoundedCornerShape(12.dp)) {
                            UserRow(user, Modifier.then(if (canEdit) Modifier.bounceClick { HapticManager.selection(); editing = user } else Modifier))
                        }
                    }
                }
            }
        }
    }

    if (showAdd) {
        AddEditUserSheet(viewModel, null, onDismiss = { showAdd = false; scope.launch { viewModel.fetchUsers() } })
    }
    editing?.let { user ->
        AddEditUserSheet(viewModel, user, onDismiss = { editing = null; scope.launch { viewModel.fetchUsers() } })
    }
    if (showDeactivated) DeactivatedUsersSheet(viewModel, onDismiss = { showDeactivated = false })
    toDelete?.let { user ->
        AppAlert(
            stringResource(R.string.users_delete_title),
            stringResource(R.string.users_delete_message),
            stringResource(R.string.common_delete),
            onConfirm = { toDelete = null; scope.launch { viewModel.deleteUser(user) } },
            onDismiss = { toDelete = null },
            destructive = true,
        )
    }
}

@Composable
fun UserRow(user: User, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().paperCard(12.dp).padding(AppSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(user.userName, style = AppType.headline, color = AppTheme.colors.textPrimary, modifier = Modifier.weight(1f))
        RoleBadge(user.role)
    }
}

@Composable
fun RoleBadge(role: UserRole) {
    val colors = AppTheme.colors
    val tint = when (role) {
        UserRole.SuperAdmin -> colors.danger
        UserRole.Admin -> colors.warning
        UserRole.User -> colors.accent
    }
    Text(
        role.raw,
        style = AppType.caption2.copy(fontWeight = FontWeight.Bold),
        color = tint,
        modifier = Modifier.background(tint.copy(alpha = 0.2f), RoundedCornerShape(8.dp)).padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
private fun SheetHeader(title: String, onClose: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs)) {
        GlassIconButton(Icons.Rounded.Close, stringResource(R.string.common_close), onClose, Modifier.align(Alignment.CenterStart), size = 36.dp)
        Text(title, style = AppType.headline, color = AppTheme.colors.textPrimary, modifier = Modifier.align(Alignment.Center))
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title.uppercase(),
        style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold),
        color = AppTheme.colors.textSecondary,
        modifier = Modifier.padding(start = 8.dp),
    )
}

/** Alta o edición de usuario. `user == null` es alta. */
@Composable
fun AddEditUserSheet(viewModel: UsersViewModel, user: User?, onDismiss: () -> Unit) {
    val colors = AppTheme.colors
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    var userName by remember { mutableStateOf(user?.userName ?: "") }
    var role by remember { mutableStateOf(user?.role ?: UserRole.User) }
    var password by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    val roles = viewModel.availableRolesForAssignment()
    val showSecurity = user == null || viewModel.canChangePassword(user)
    val scope = rememberCoroutineScope()

    val isValid = userName.isNotEmpty() &&
        (password.isEmpty() || (password == confirm && password.length >= 4)) &&
        (user != null || (password.isNotEmpty() && confirm.isNotEmpty()))

    fun save() {
        scope.launch {
            val success = if (user == null) {
                viewModel.addUser(userName, role, password)
            } else {
                val updated = viewModel.updateUser(user, userName, role)
                val pwd = if (password.isNotEmpty()) viewModel.changePassword(user, password) else true
                updated && pwd
            }
            if (success) onDismiss()
        }
    }

    AppSheet(onDismiss) {
        Box {
            LiquidBackground(Modifier.matchParentSize())
            Column(Modifier.imePadding().navigationBarsPadding()) {
                SheetHeader(stringResource(if (user == null) R.string.users_add_title else R.string.users_edit_title), onDismiss)
                Column(
                    Modifier.verticalScroll(rememberScrollState()).padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    error?.let { Text(it, style = AppType.caption, color = colors.danger, modifier = Modifier.fillMaxWidth()) }

                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        SectionHeader(stringResource(R.string.users_section_info))
                        Column(Modifier.paperCard().padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            GlassTextField(userName, { userName = it }, stringResource(R.string.users_username), autoCapitalize = false, imeAction = ImeAction.Next)
                            if (roles.isNotEmpty()) {
                                Text(stringResource(R.string.users_role), style = AppType.caption, color = colors.textSecondary, modifier = Modifier.padding(start = 4.dp))
                                Row(
                                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.textSecondary.copy(alpha = 0.08f)).padding(4.dp),
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    roles.forEach { option ->
                                        val selected = option == role
                                        Box(
                                            Modifier
                                                .weight(1f)
                                                .clip(RoundedCornerShape(12.dp))
                                                .background(if (selected) colors.accent else Color.Transparent)
                                                .then(if (!selected) Modifier.border(1.dp, colors.textSecondary.copy(alpha = 0.3f), RoundedCornerShape(12.dp)) else Modifier)
                                                .bounceClick { role = option }
                                                .padding(vertical = 12.dp),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text(
                                                option.raw,
                                                style = AppType.body.copy(fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal),
                                                color = if (selected) Color.White else colors.textPrimary,
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (showSecurity) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            SectionHeader(stringResource(R.string.users_section_security))
                            Column(Modifier.paperCard().padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                                if (user != null) Text(stringResource(R.string.users_new_password_optional), style = AppType.caption, color = colors.textSecondary)
                                GlassTextField(password, { password = it }, stringResource(R.string.users_password), isPassword = true, imeAction = ImeAction.Next)
                                if (password.isNotEmpty()) {
                                    GlassTextField(confirm, { confirm = it }, stringResource(R.string.users_confirm_password), isPassword = true, onSubmit = { if (isValid) save() })
                                    if (confirm.isNotEmpty() && password != confirm) {
                                        Text(stringResource(R.string.users_passwords_do_not_match), style = AppType.caption, color = colors.danger)
                                    }
                                }
                            }
                        }
                    }

                    PrimaryButton(
                        stringResource(if (user == null) R.string.common_create else R.string.common_save),
                        ::save,
                        isLoading = isLoading,
                        isDisabled = !isValid,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                }
            }
        }
    }
}

@Composable
fun DeactivatedUsersSheet(viewModel: UsersViewModel, onDismiss: () -> Unit) {
    val colors = AppTheme.colors
    val users by viewModel.deactivatedUsers.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoadingDeactivated.collectAsStateWithLifecycle()
    val error by viewModel.deactivatedErrorMessage.collectAsStateWithLifecycle()
    var reactivating by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { viewModel.fetchDeactivatedUsers() }

    AppSheet(onDismiss) {
        Box {
            LiquidBackground(Modifier.matchParentSize())
            Column(Modifier.navigationBarsPadding().heightIn(min = 360.dp)) {
                SheetHeader(stringResource(R.string.users_deactivated_title), onDismiss)
                when {
                    isLoading && users.isEmpty() -> Box(Modifier.fillMaxWidth().heightIn(min = 200.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = colors.accent)
                    }
                    error != null && users.isEmpty() -> ContentUnavailable(
                        stringResource(R.string.common_error), Icons.Rounded.Warning, description = error,
                        actions = { AppButton(stringResource(R.string.common_retry), { scope.launch { viewModel.fetchDeactivatedUsers() } }, style = AppButtonStyle.Bordered) },
                    )
                    users.isEmpty() -> ContentUnavailable(
                        stringResource(R.string.users_deactivated_empty), Icons.Rounded.HowToReg,
                        description = stringResource(R.string.users_deactivated_info),
                    )
                    else -> LazyColumn(
                        contentPadding = PaddingValues(AppSpacing.md),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        items(users, key = { it.id }) { user ->
                            Row(Modifier.fillMaxWidth().paperCard(12.dp).padding(AppSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(user.userName, style = AppType.headline, color = colors.textSecondary)
                                    RoleBadge(user.role)
                                }
                                if (reactivating == user.id) {
                                    CircularProgressIndicator(Modifier.size(22.dp), color = colors.accent, strokeWidth = 2.dp)
                                } else {
                                    AppButton(
                                        stringResource(R.string.users_reactivate),
                                        {
                                            HapticManager.selection()
                                            reactivating = user.id
                                            scope.launch { viewModel.reactivateUser(user); reactivating = null }
                                        },
                                        style = AppButtonStyle.Bordered,
                                        enabled = reactivating == null,
                                    )
                                }
                            }
                        }
                        item {
                            Text(stringResource(R.string.users_deactivated_info), style = AppType.footnote, color = colors.textSecondary, modifier = Modifier.padding(top = 8.dp))
                        }
                    }
                }
            }
        }
    }
}
