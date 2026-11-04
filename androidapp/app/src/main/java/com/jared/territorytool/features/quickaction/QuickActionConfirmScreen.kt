package com.jared.territorytool.features.quickaction

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.SyncAlt
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.jared.territorytool.R
import com.jared.territorytool.core.AppEvent
import com.jared.territorytool.core.AppEvents
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.core.Strings
import com.jared.territorytool.designsystem.AppButton
import com.jared.territorytool.designsystem.AppButtonStyle
import com.jared.territorytool.designsystem.AppRadius
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.InitialsAvatar
import com.jared.territorytool.designsystem.PrimaryButton
import com.jared.territorytool.designsystem.Rounded
import com.jared.territorytool.designsystem.TerritoryStatusIndicator
import com.jared.territorytool.designsystem.appear
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.designsystem.paperCard
import com.jared.territorytool.designsystem.rememberStatusPresentation
import com.jared.territorytool.shared.components.DateFormats
import com.jared.territorytool.shared.components.DateTimeField
import com.jared.territorytool.shared.components.ToastManager
import com.jared.territorytool.shared.components.ToastStyle
import com.jared.territorytool.shared.map.TerritorySnapshotBackdrop
import com.jared.territorytool.shared.components.VirtualDeliveryToggle
import com.jared.territorytool.shared.models.DeliveryFormat
import com.jared.territorytool.shared.models.Territory
import com.jared.territorytool.shared.models.UndoHandleKind
import com.jared.territorytool.shared.utils.userFriendlyMessage
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Confirmación: resumen visual de lo que se va a hacer + fecha + acción prominente. Al
 * confirmar se ejecuta (con toast deshacible) y se vuelve al tablero.
 */
@Composable
fun QuickActionConfirmScreen(
    action: QuickActionAction,
    onDone: () -> Unit,
    onDeliverAnother: ((String) -> Unit)?,
    onClose: (() -> Unit)?,
) {
    val colors = AppTheme.colors
    val api = DIContainer.apiService
    var dateExpanded by remember { mutableStateOf(false) }
    var customized by remember { mutableStateOf(false) }
    var pickedDate by remember { mutableStateOf(Instant.now()) }
    var submitting by remember { mutableStateOf(false) }
    // Solo en entrega: físico por defecto.
    var deliveryFormat by remember { mutableStateOf(DeliveryFormat.Physical) }
    // Si llegó sin geometría (p. ej. desde la decisión de persona) se hidrata con el completo.
    var hydrated by remember { mutableStateOf<Territory?>(null) }
    val territory = hydrated ?: action.territory
    val scope = rememberCoroutineScope()

    LaunchedEffect(action) {
        if (action.territory.mapGeometry == null && hydrated == null) {
            hydrated = runCatching { api.getTerritory(action.territory.id) }.getOrNull()
        }
    }

    fun submit(deliverAnother: Boolean = false) {
        submitting = true
        // Al encadenar guardamos a quién tenía el territorio antes de recogerlo.
        val previousHolder = territory.personName
        val date = if (customized) pickedDate else null
        scope.launch {
            try {
                val personName = action.personName
                val (response, toastKey) = if (personName != null) {
                    api.giveTerritoryUndoable(territory.code, personName, date, deliveryFormat) to R.string.assignment_success
                } else {
                    api.pickTerritoryUndoable(territory.code, date) to R.string.return_success
                }
                val handle = response.handle(UndoHandleKind.Domain)
                ToastManager.show(Strings.get(toastKey), ToastStyle.Success, handle, handle.toastDurationMillis)
                AppEvents.post(AppEvent.TerritoryDataChanged)
                if (deliverAnother && previousHolder != null && onDeliverAnother != null) onDeliverAnother(previousHolder) else onDone()
            } catch (e: Exception) {
                // Mensaje claro por toast en vez del código crudo.
                ToastManager.show(e.userFriendlyMessage, ToastStyle.Error)
            } finally {
                submitting = false
            }
        }
    }

    QuickActionScreen(
        stringResource(if (action.isDeliver) R.string.assignment_title else R.string.return_title),
        onClose,
        bottomBar = {
            Column(
                Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = AppSpacing.md).padding(top = AppSpacing.sm, bottom = AppSpacing.sm),
                verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            ) {
                // Devolución con opción de encadenar: dos acciones a ancho completo.
                if (!action.isDeliver && territory.personName != null && onDeliverAnother != null) {
                    AppButton(
                        stringResource(R.string.quick_action_return_deliver), { submit(deliverAnother = true) },
                        icon = Icons.Rounded.SyncAlt, tint = colors.accentSecondary, style = AppButtonStyle.Glass,
                        enabled = !submitting, large = true, fillWidth = true,
                    )
                    AppButton(
                        stringResource(R.string.quick_action_action_return), { submit() },
                        icon = Icons.Rounded.MoveToInbox, tint = colors.accentSecondary,
                        enabled = !submitting, isLoading = submitting, large = true, fillWidth = true,
                    )
                } else {
                    PrimaryButton(
                        stringResource(if (action.isDeliver) R.string.quick_action_confirm_deliver else R.string.quick_action_confirm_return),
                        { submit() },
                        isLoading = submitting,
                        isDisabled = submitting,
                        icon = if (action.isDeliver) Icons.AutoMirrored.Rounded.Send else Icons.Rounded.MoveToInbox,
                        tint = if (action.isDeliver) colors.accent else colors.accentSecondary,
                    )
                }
            }
        },
    ) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = AppSpacing.md).padding(top = AppSpacing.sm, bottom = 150.dp),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        ) {
            ConfirmTerritoryHero(territory, Modifier.appear(0))

            action.personName?.let { name ->
                Row(
                    Modifier.appear(1).fillMaxWidth().paperCard(AppRadius.lg).padding(AppSpacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
                ) {
                    InitialsAvatar(name, size = 46.dp)
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(stringResource(R.string.quick_action_deliver_target), style = AppType.appCaption, color = colors.textSecondary)
                        Text(name, style = AppType.appTitle, color = colors.textPrimary, maxLines = 1)
                    }
                }
            }

            // Fecha: fila tocable + selector expandible.
            Column(Modifier.appear(2).fillMaxWidth().paperCard(AppRadius.lg).animateContentSize()) {
                Row(
                    Modifier.fillMaxWidth().clickable { HapticManager.selection(); dateExpanded = !dateExpanded }.padding(AppSpacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
                ) {
                    Box(Modifier.size(40.dp).background(colors.accent.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Schedule, null, Modifier.size(18.dp), tint = colors.accentDeep)
                    }
                    Text(
                        if (customized) DateFormats.dateTime(pickedDate)
                        else stringResource(R.string.quick_action_date_now) + " · " + DateFormats.dateTime(Instant.now()),
                        style = AppType.appHeadline,
                        color = colors.textPrimary,
                        modifier = Modifier.weight(1f),
                    )
                    val rotation by animateFloatAsState(if (dateExpanded) 180f else 0f, label = "chevron")
                    Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(18.dp).graphicsLayer { rotationZ = rotation }, tint = colors.textSecondary)
                }
                AnimatedVisibility(dateExpanded, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                    Column(
                        Modifier.fillMaxWidth().padding(start = AppSpacing.md, end = AppSpacing.md, bottom = AppSpacing.md),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
                    ) {
                        DateTimeField(pickedDate, { pickedDate = it; customized = true }, maxDate = Instant.now())
                        if (customized) {
                            Row(
                                Modifier.bounceClick { customized = false; pickedDate = Instant.now() },
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Icon(Icons.AutoMirrored.Rounded.Undo, null, Modifier.size(16.dp), tint = colors.accent)
                                Text(stringResource(R.string.quick_action_date_now), style = AppType.appSubheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.accent)
                            }
                        }
                    }
                }
            }

            if (action.isDeliver) {
                VirtualDeliveryToggle(
                    deliveryFormat,
                    { deliveryFormat = it },
                    Modifier.appear(3).paperCard(AppRadius.lg).padding(AppSpacing.md),
                )
            }
        }
    }
}

/** Resumen del territorio: información a la izquierda y el mapa sangrando por la derecha. */
@Composable
private fun ConfirmTerritoryHero(territory: Territory, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val presentation = rememberStatusPresentation(territory.operationalStatus())
    val tint = presentation.color
    val shape = RoundedCornerShape(AppRadius.xl)

    @Composable
    fun Divider() = Box(Modifier.padding(vertical = AppSpacing.xxs).width(96.dp).size(96.dp, 1.dp).background(colors.hairline))

    @Composable
    fun DaysBlock(label: String, days: Int) {
        Column {
            Text(label, style = AppType.appCaption, color = colors.textSecondary)
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(days.toString(), style = TextStyle(fontFamily = Rounded, fontSize = 42.sp, fontWeight = FontWeight.Black), color = colors.textPrimary)
                Text(stringResource(R.string.common_days), style = AppType.appHeadline, color = colors.textSecondary, modifier = Modifier.padding(bottom = 8.dp))
            }
        }
    }

    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 200.dp)
            .shadow(14.dp, shape, ambientColor = colors.glassShadow, spotColor = colors.glassShadow)
            .clip(shape)
            .background(colors.surface)
            .border(1.dp, Brush.linearGradient(listOf(tint.copy(alpha = 0.7f), tint.copy(alpha = 0.22f))), shape),
    ) {
        Box(
            Modifier
                .matchParentSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .drawWithContent {
                    drawContent()
                    drawRect(
                        Brush.horizontalGradient(0f to Color.Transparent, 0.32f to Color.Black.copy(alpha = 0.35f), 0.55f to Color.Black.copy(alpha = 0.8f), 0.72f to Color.Black, 1f to Color.Black),
                        blendMode = BlendMode.DstIn,
                    )
                },
        ) {
            val geometry = territory.mapGeometry
            when {
                geometry != null -> TerritorySnapshotBackdrop(geometry, Modifier.fillMaxSize(), stroke = tint, fill = tint, verticalBias = 0.1)
                territory.imgUrl != null -> AsyncImage(territory.imgUrl, null, Modifier.fillMaxSize().background(tint.copy(alpha = 0.08f)), contentScale = ContentScale.Crop)
                else -> Box(Modifier.fillMaxSize().background(tint.copy(alpha = 0.06f)))
            }
        }
        Column(Modifier.padding(AppSpacing.md).padding(end = 104.dp), verticalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
                Text(territory.code, style = AppType.title.copy(fontWeight = FontWeight.Black), color = colors.accentDeep, maxLines = 1)
                Text("· ${territory.name}", style = AppType.title3.copy(fontWeight = FontWeight.SemiBold), color = colors.textPrimary, maxLines = 1, modifier = Modifier.padding(bottom = 3.dp))
            }
            val person = territory.personName
            if (territory.isAssigned && person != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                    InitialsAvatar(person, size = 38.dp, tint = tint)
                    Text(person, style = AppType.appHeadline, color = colors.textPrimary, maxLines = 1)
                }
                territory.givenDateUtc?.let {
                    Text(stringResource(R.string.territories_drawer_assigned_on, DateFormats.abbreviated(it)), style = AppType.appSubheadline, color = colors.textSecondary)
                }
                Divider()
                territory.daysAssigned()?.let { DaysBlock(stringResource(R.string.quick_action_in_use_since), it) }
            } else {
                TerritoryStatusIndicator(presentation)
                val free = territory.daysFree()
                if (free != null) {
                    Divider()
                    DaysBlock(stringResource(R.string.quick_action_free_since_label), free)
                } else {
                    Text(stringResource(R.string.territories_drawer_never_picked), style = AppType.appSubheadline, color = colors.textSecondary)
                }
            }
        }
    }
}
