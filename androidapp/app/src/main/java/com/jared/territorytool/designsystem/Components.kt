package com.jared.territorytool.designsystem

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

// MARK: - Fondo cartográfico

/**
 * Fondo "cartográfico cálido": papel con curvas de nivel tenues y una veladura cálida.
 * Estático y barato de dibujar.
 */
@Composable
fun LiquidBackground(modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Canvas(modifier.fillMaxSize()) {
        drawRect(colors.appBackground)
        val radius = maxOf(size.width, size.height)
        drawRect(
            Brush.radialGradient(
                0f to Color.Transparent,
                (160f / 620f) to Color.Transparent,
                1f to colors.appBackgroundDeep.copy(alpha = 0.7f),
                center = center,
                radius = radius * 0.75f,
            ),
        )
        drawRect(
            Brush.radialGradient(
                listOf(colors.accent.copy(alpha = 0.10f), Color.Transparent),
                center = Offset(size.width * 0.92f, size.height * 0.06f),
                radius = 360.dp.toPx(),
            ),
        )
        val d = density
        data class Peak(val x: Float, val y: Float, val rings: Int, val base: Float, val gap: Float, val phase: Float)
        val peaks = listOf(
            Peak(size.width * 0.86f, size.height * 0.10f, 9, 30f, 34f, 0f),
            Peak(size.width * 0.08f, size.height * 0.74f, 8, 26f, 38f, 1.7f),
            Peak(size.width * 0.62f, size.height * 0.96f, 6, 40f, 42f, 3.1f),
        )
        val path = Path()
        for (peak in peaks) {
            for (i in 1..peak.rings) {
                val r0 = (peak.base + i * peak.gap) * d
                val wobble = (6 + i * 1.4f) * d
                val phase = peak.phase + i * 0.35f
                val steps = 72
                for (s in 0..steps) {
                    val t = s.toFloat() / steps * 2f * PI.toFloat()
                    val r = r0 + sin(t * 3 + phase) * wobble + cos(t * 5 + phase * 1.3f) * wobble * 0.45f
                    val x = peak.x + cos(t) * r
                    val y = peak.y + sin(t) * r
                    if (s == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                path.close()
            }
        }
        drawPath(path, colors.cartoLine.copy(alpha = 0.14f), style = Stroke(width = 1.dp.toPx()))
    }
}

// MARK: - Tarjeta de papel

/** Solo el fondo de papel: superficie + borde fino + sombra cálida. */
fun Modifier.paperCard(cornerRadius: Dp = AppRadius.lg, fill: Color? = null): Modifier = composed {
    val colors = AppTheme.colors
    val shape = RoundedCornerShape(cornerRadius)
    this
        .shadow(10.dp, shape, clip = false, ambientColor = colors.glassShadow, spotColor = colors.glassShadow.copy(alpha = 0.35f))
        .background(fill ?: colors.surface, shape)
        .border(1.dp, colors.hairline, shape)
}

/** Tarjeta de papel cálido. Padding `md` y radio `lg` por defecto. */
@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = AppRadius.lg,
    padding: Dp = AppSpacing.md,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.paperCard(cornerRadius).padding(padding), content = content)
}

/**
 * Relleno del "cristal" de iOS. Allí `glassEffect` difumina lo que hay detrás; Android no tiene
 * blur de fondo, así que el relleno debe ser casi opaco: con más transparencia, el mapa (calles,
 * etiquetas) se transparenta y el texto encima deja de leerse.
 */
val AppColors.frostedFill: Color get() = surfaceRaised.copy(alpha = if (isDark) 0.92f else 0.95f)

/** Superficie tipo "glass" (cristal) usada en campos, controles flotantes y hojas. */
fun Modifier.glass(shape: Shape = RoundedCornerShape(AppRadius.md)): Modifier = composed {
    val colors = AppTheme.colors
    this
        .clip(shape)
        .background(colors.frostedFill, shape)
        .border(1.dp, if (colors.isDark) Color.White.copy(alpha = 0.08f) else colors.hairline.copy(alpha = 0.7f), shape)
}

/** Equivalente a `glassEffect(.regular.tint(...))` de iOS: base de cristal + tinte encima. */
fun Modifier.tintedGlass(tint: Color, shape: Shape, tintAlpha: Float = 0.14f, borderColor: Color? = null): Modifier = composed {
    val colors = AppTheme.colors
    this
        .clip(shape)
        .background(colors.frostedFill, shape)
        .background(tint.copy(alpha = tintAlpha), shape)
        .border(1.dp, borderColor ?: tint.copy(alpha = 0.22f), shape)
}

// MARK: - Botones

/** Escala al pulsar (equivalente a `ScaleButtonStyle`). */
fun Modifier.pressScale(interaction: MutableInteractionSource, pressedScale: Float = 0.97f): Modifier = composed {
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) pressedScale else 1f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMedium), label = "press")
    this.graphicsLayer { scaleX = scale; scaleY = scale }
}

fun Modifier.bounceClick(enabled: Boolean = true, onClick: () -> Unit): Modifier = composed {
    val interaction = remember { MutableInteractionSource() }
    this
        .pressScale(interaction)
        .clickable(interactionSource = interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
}

enum class AppButtonStyle { Prominent, Glass, Bordered, Plain }

/**
 * Botón cápsula. `Prominent` = relleno de color (glassProminent), `Glass` = tinte suave
 * translúcido (glass), `Bordered` = contorno.
 */
@Composable
fun AppButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    tint: Color = AppTheme.colors.accent,
    style: AppButtonStyle = AppButtonStyle.Prominent,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    large: Boolean = false,
    fillWidth: Boolean = false,
    textStyle: TextStyle = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
) {
    val interaction = remember { MutableInteractionSource() }
    val active = enabled && !isLoading
    val shape = CircleShape
    val (bg, fg) = when (style) {
        AppButtonStyle.Prominent -> tint.copy(alpha = if (active) 1f else 0.4f) to Color.White
        // El fondo de Glass lo pinta `tintedGlass` (base opaca + tinte); aquí solo el color del contenido.
        AppButtonStyle.Glass -> Color.Transparent to tint
        AppButtonStyle.Bordered -> tint.copy(alpha = 0.10f) to tint
        AppButtonStyle.Plain -> Color.Transparent to tint
    }
    Row(
        modifier
            .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
            .pressScale(interaction)
            .then(
                if (style == AppButtonStyle.Prominent && active)
                    Modifier.shadow(8.dp, shape, ambientColor = tint.copy(alpha = 0.3f), spotColor = tint.copy(alpha = 0.3f))
                else Modifier,
            )
            .then(if (style == AppButtonStyle.Glass) Modifier.tintedGlass(tint, shape) else Modifier)
            .clip(shape)
            .background(bg, shape)
            .clickable(interactionSource = interaction, indication = null, enabled = active, role = Role.Button, onClick = onClick)
            .alpha(if (active || style == AppButtonStyle.Prominent) 1f else 0.5f)
            .padding(horizontal = if (large) 20.dp else 16.dp, vertical = if (large) 14.dp else 10.dp),
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isLoading) {
            CircularProgressIndicator(Modifier.size(18.dp), color = fg, strokeWidth = 2.dp)
        } else {
            if (icon != null) Icon(icon, null, Modifier.size(18.dp), tint = fg)
            Text(text, style = textStyle, color = fg, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

/** CTA primario de ancho completo. */
@Composable
fun PrimaryButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    isDisabled: Boolean = false,
    icon: ImageVector? = null,
    tint: Color = AppTheme.colors.accent,
) {
    AppButton(
        text = title,
        onClick = onClick,
        modifier = modifier,
        icon = icon,
        tint = tint,
        enabled = !isDisabled,
        isLoading = isLoading,
        large = true,
        fillWidth = true,
        textStyle = AppType.body.copy(fontWeight = FontWeight.SemiBold),
    )
}

/** Botón circular de icono (barras de herramientas, cerrar…). */
@Composable
fun GlassIconButton(
    icon: ImageVector,
    contentDescription: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = AppTheme.colors.textPrimary,
    size: Dp = 40.dp,
    enabled: Boolean = true,
) {
    Box(
        modifier
            .size(size)
            .glass(CircleShape)
            .bounceClick(enabled, onClick)
            .semantics { if (contentDescription != null) this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(size * 0.48f), tint = tint.copy(alpha = if (enabled) 1f else 0.4f))
    }
}

// MARK: - Campos

@Composable
fun GlassTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    label: String? = null,
    leadingIcon: ImageVector? = null,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Done,
    onSubmit: (() -> Unit)? = null,
    singleLine: Boolean = true,
    autoCapitalize: Boolean = true,
) {
    val colors = AppTheme.colors
    Column(modifier, verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        if (label != null) {
            Text(label, style = AppType.appCaption, color = colors.textSecondary, modifier = Modifier.padding(start = AppSpacing.xxs))
        }
        Row(
            Modifier.fillMaxWidth().glass().padding(AppSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            if (leadingIcon != null) Icon(leadingIcon, null, Modifier.size(20.dp), tint = colors.textSecondary)
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.weight(1f),
                singleLine = singleLine,
                textStyle = AppType.body.copy(color = colors.textPrimary),
                cursorBrush = SolidColor(colors.accent),
                visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (isPassword) KeyboardType.Password else keyboardType,
                    imeAction = imeAction,
                    autoCorrectEnabled = !isPassword && autoCapitalize,
                    capitalization = if (autoCapitalize && !isPassword) androidx.compose.ui.text.input.KeyboardCapitalization.Sentences
                    else androidx.compose.ui.text.input.KeyboardCapitalization.None,
                ),
                keyboardActions = KeyboardActions(onAny = { onSubmit?.invoke() }),
                decorationBox = { inner ->
                    Box {
                        if (value.isEmpty()) Text(placeholder, style = AppType.body, color = colors.textSecondary.copy(alpha = 0.7f))
                        inner()
                    }
                },
            )
        }
    }
}

// MARK: - Avatares e insignias

/** Avatar de iniciales: círculo con degradado del tinte e iniciales en blanco. */
@Composable
fun InitialsAvatar(name: String, modifier: Modifier = Modifier, size: Dp = 40.dp, tint: Color = AppTheme.colors.accent) {
    val initials = name.split(" ").filter { it.isNotBlank() }.take(2).mapNotNull { it.firstOrNull()?.toString() }
        .joinToString("").uppercase()
    Box(
        modifier
            .size(size)
            .shadow(4.dp, CircleShape, ambientColor = tint.copy(alpha = 0.35f), spotColor = tint.copy(alpha = 0.35f))
            .background(Brush.linearGradient(listOf(tint, tint.copy(alpha = 0.78f))), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            initials.ifEmpty { "?" },
            style = TextStyle(fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = (size.value * 0.38f).sp),
            color = Color.White,
        )
    }
}

/** Círculo con degradado e icono blanco (usado en stat tiles, estados, movimientos). */
@Composable
fun GradientIconCircle(
    icon: ImageVector,
    tint: Color,
    modifier: Modifier = Modifier,
    size: Dp = 36.dp,
    iconSize: Dp = size * 0.42f,
    glow: Boolean = true,
) {
    Box(
        modifier
            .size(size)
            .then(if (glow) Modifier.shadow(4.dp, CircleShape, ambientColor = tint.copy(alpha = 0.35f), spotColor = tint.copy(alpha = 0.35f)) else Modifier)
            .background(Brush.linearGradient(listOf(tint, tint.copy(alpha = 0.78f))), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(iconSize), tint = Color.White)
    }
}

/** Badge del código de territorio con degradado de acento. */
@Composable
fun TerritoryCodeBadge(
    code: String,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = AppType.title3,
    paddingHorizontal: Dp = AppSpacing.sm,
    paddingVertical: Dp = AppSpacing.xs,
) {
    val colors = AppTheme.colors
    Text(
        code,
        style = textStyle.copy(fontWeight = FontWeight.Bold),
        color = Color.White,
        maxLines = 1,
        modifier = modifier
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(colors.accent, colors.accentSecondary)))
            .padding(horizontal = paddingHorizontal, vertical = paddingVertical),
    )
}

/** Cápsula con texto e icono opcional sobre un tinte suave. */
@Composable
fun TintedCapsule(
    text: String,
    tint: Color,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    textStyle: TextStyle = AppType.caption.copy(fontWeight = FontWeight.Bold),
    filled: Boolean = false,
    contentPadding: PaddingValues = PaddingValues(horizontal = AppSpacing.xs, vertical = 3.dp),
) {
    Row(
        modifier
            .clip(CircleShape)
            .background(if (filled) tint else tint.copy(alpha = 0.14f))
            .padding(contentPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xxs),
    ) {
        if (icon != null) Icon(icon, null, Modifier.size(12.dp), tint = if (filled) Color.White else tint)
        Text(text, style = textStyle, color = if (filled) Color.White else tint, maxLines = 1)
    }
}

// MARK: - Piezas cartográficas

/** Número que "rueda" de 0 al valor al aparecer. */
@Composable
fun CountUpText(
    value: Int,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle(fontFamily = Rounded, fontSize = 32.sp, fontWeight = FontWeight.ExtraBold),
    color: Color = AppTheme.colors.textPrimary,
) {
    val anim = remember { Animatable(0f) }
    LaunchedEffect(value) {
        anim.animateTo(value.toFloat(), tween(if (anim.value == 0f) 800 else 500, easing = FastOutSlowInEasing))
    }
    Text(anim.value.toInt().toString(), modifier, style = style.copy(fontFeatureSettings = "tnum"), color = color)
}

/** Fundido + desplazamiento de entrada. `index` escalona el retardo. */
fun Modifier.appear(index: Int = 0, base: Long = 40): Modifier = composed {
    var visible by rememberSaveable { mutableStateOf(false) }
    val progress = remember { Animatable(if (visible) 1f else 0f) }
    LaunchedEffect(Unit) {
        if (!visible) {
            kotlinx.coroutines.delay(index * base)
            progress.animateTo(1f, spring(dampingRatio = 0.85f, stiffness = 180f))
            visible = true
        }
    }
    this.graphicsLayer {
        alpha = progress.value
        translationY = (1f - progress.value) * 16.dp.toPx()
    }
}

/** Cabecera de sección: icono + título + línea de ruta punteada + contador. */
@Composable
fun CartoSectionHeader(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    count: Int? = null,
    tint: Color = AppTheme.colors.accent,
) {
    val colors = AppTheme.colors
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        Icon(icon, null, Modifier.size(16.dp), tint = tint)
        Text(title, style = AppType.headline.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, maxLines = 1)
        DottedLine(Modifier.weight(1f), colors.hairline)
        if (count != null) {
            TintedCapsule(count.toString(), tint, contentPadding = PaddingValues(horizontal = AppSpacing.xs, vertical = 2.dp))
        }
    }
}

@Composable
fun DottedLine(modifier: Modifier = Modifier, color: Color = AppTheme.colors.hairline) {
    Canvas(modifier.height(2.dp)) {
        drawLine(
            color,
            Offset(0f, size.height / 2),
            Offset(size.width, size.height / 2),
            strokeWidth = 1.5.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 4.dp.toPx())),
        )
    }
}

/** Tarjeta de estadística: icono + número animado + etiqueta. */
@Composable
fun StatTile(value: Int, label: String, icon: ImageVector, modifier: Modifier = Modifier, tint: Color = AppTheme.colors.accent) {
    Column(modifier.paperCard().padding(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        GradientIconCircle(icon, tint, size = 36.dp, iconSize = 16.dp)
        CountUpText(value, Modifier.padding(top = 2.dp))
        Text(label, style = AppType.caption.copy(fontWeight = FontWeight.Medium), color = AppTheme.colors.textSecondary, maxLines = 2)
    }
}

/** Estado vacío amable con icono en círculo y mensaje. */
@Composable
fun CartoEmptyState(icon: ImageVector, message: String, modifier: Modifier = Modifier, tint: Color = AppTheme.colors.accent) {
    Row(
        modifier.fillMaxWidth().paperCard().padding(AppSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Box(Modifier.size(44.dp).background(tint.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(22.dp), tint = tint)
        }
        Text(message, style = AppType.subheadline, color = AppTheme.colors.textSecondary, modifier = Modifier.weight(1f))
    }
}

/** Contenido "no disponible" centrado (equivalente a `ContentUnavailableView`). */
@Composable
fun ContentUnavailable(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    description: String? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    Column(
        modifier.fillMaxWidth().padding(AppSpacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        Icon(icon, null, Modifier.size(44.dp), tint = colors.textSecondary)
        Text(title, style = AppType.title3.copy(fontWeight = FontWeight.Bold), color = colors.textPrimary, textAlign = TextAlign.Center)
        if (description != null) {
            Text(description, style = AppType.subheadline, color = colors.textSecondary, textAlign = TextAlign.Center)
        }
        if (actions != null) Row(Modifier.padding(top = AppSpacing.xs), content = actions)
    }
}

/** Fila de separación horizontal fina. */
@Composable
fun Hairline(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(1.dp).background(AppTheme.colors.hairline))
}

@Composable
fun FlexSpacer(scope: RowScope) = with(scope) { Spacer(Modifier.weight(1f)) }

@Composable
fun VSpace(height: Dp) = Spacer(Modifier.height(height))

@Composable
fun HSpace(width: Dp) = Spacer(Modifier.width(width))

/** Anillo de progreso circular (cuenta atrás, porcentajes). */
@Composable
fun ProgressRing(progress: Float, color: Color, modifier: Modifier = Modifier, lineWidth: Dp = 2.dp, trackAlpha: Float = 0.22f) {
    Canvas(modifier) {
        val stroke = lineWidth.toPx()
        val inset = stroke / 2
        drawArc(color.copy(alpha = trackAlpha), 0f, 360f, false, Offset(inset, inset), size.copy(size.width - stroke, size.height - stroke), style = Stroke(stroke))
        drawArc(color, -90f, 360f * progress.coerceIn(0f, 1f), false, Offset(inset, inset), size.copy(size.width - stroke, size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
    }
}

@Composable
fun BoxWithBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier.fillMaxSize()) {
        LiquidBackground()
        content()
    }
}

fun Modifier.drawHairlineBottom(color: Color): Modifier = drawBehind {
    drawLine(color, Offset(0f, size.height), Offset(size.width, size.height), 1.dp.toPx())
}
