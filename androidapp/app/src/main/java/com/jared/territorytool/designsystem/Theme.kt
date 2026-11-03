package com.jared.territorytool.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.unit.dp

// MARK: - Tokens de color. Tema "Cartográfico cálido": papel cálido, verde bosque,
// ámbar y terracota. Todos dinámicos claro/oscuro. Ver docs/DESIGN_GUIDE.md de iOS.

@Immutable
data class AppColors(
    val accent: Color,
    val accentDeep: Color,
    val accentSecondary: Color,
    val accentTertiary: Color,
    val success: Color,
    val warning: Color,
    val danger: Color,
    val info: Color,
    val appBackground: Color,
    val appBackgroundDeep: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val cartoLine: Color,
    val hairline: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val glassShadow: Color,
    val isDark: Boolean,
) {
    /** Color según los días asignado (ámbar → warning → terracota). */
    fun urgency(days: Int): Color = when {
        days < 150 -> accentSecondary
        days < 240 -> warning
        else -> accentTertiary
    }
}

private fun c(rgb: Long) = Color(0xFF000000 or rgb)

val LightAppColors = AppColors(
    accent = c(0x2F6B4F), accentDeep = c(0x234E39), accentSecondary = c(0xD98A2B), accentTertiary = c(0xC4633B),
    success = c(0x2F6B4F), warning = c(0xC8821F), danger = c(0xBC4B2E), info = c(0x3E6B8C),
    appBackground = c(0xF4EFE6), appBackgroundDeep = c(0xE7DECB), surface = c(0xFBF8F1), surfaceRaised = c(0xFFFFFF),
    cartoLine = c(0x9C8A6E), hairline = c(0xDED3BE), textPrimary = c(0x2C271F), textSecondary = c(0x756A56),
    glassShadow = c(0x4A3F2A).copy(alpha = 0.10f), isDark = false,
)

val DarkAppColors = AppColors(
    accent = c(0x5FB389), accentDeep = c(0x6FC298), accentSecondary = c(0xE8A857), accentTertiary = c(0xD98A63),
    success = c(0x5FB389), warning = c(0xE8A857), danger = c(0xE07A52), info = c(0x7FAAC9),
    appBackground = c(0x1A1714), appBackgroundDeep = c(0x12100D), surface = c(0x252019), surfaceRaised = c(0x2E2820),
    cartoLine = c(0x6E6354), hairline = c(0x3A3329), textPrimary = c(0xEFE9DD), textSecondary = c(0xACA290),
    glassShadow = Color.Black.copy(alpha = 0.10f), isDark = true,
)

val LocalAppColors = staticCompositionLocalOf { LightAppColors }

/** Acceso corto: `AppTheme.colors.accent`. */
object AppTheme {
    val colors: AppColors
        @Composable get() = LocalAppColors.current
}

/** Mezcla lineal en sRGB (`amount` 0 = this, 1 = other). */
fun Color.blended(with: Color, amount: Float): Color = lerp(this, with, amount.coerceIn(0f, 1f))

/** Escala de espaciado base 8. */
object AppSpacing {
    val xxs = 4.dp
    val xs = 8.dp
    val sm = 12.dp
    val md = 16.dp
    val lg = 24.dp
    val xl = 32.dp
}

/** Radios de esquina. */
object AppRadius {
    val sm = 8.dp
    val md = 12.dp
    val lg = 20.dp
    val xl = 26.dp
}

private fun AppColors.toMaterial(): ColorScheme {
    val base = if (isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = accent,
        onPrimary = Color.White,
        primaryContainer = accent.copy(alpha = 0.16f),
        onPrimaryContainer = accentDeep,
        secondary = accentSecondary,
        onSecondary = Color.White,
        tertiary = accentTertiary,
        error = danger,
        background = appBackground,
        onBackground = textPrimary,
        surface = surface,
        onSurface = textPrimary,
        surfaceVariant = surfaceRaised,
        onSurfaceVariant = textSecondary,
        surfaceContainer = surface,
        surfaceContainerHigh = surfaceRaised,
        surfaceContainerHighest = surfaceRaised,
        surfaceContainerLow = surface,
        surfaceContainerLowest = appBackground,
        outline = hairline,
        outlineVariant = hairline,
        secondaryContainer = accent.copy(alpha = 0.18f),
        onSecondaryContainer = accentDeep,
    )
}

@Composable
fun TerritoryToolTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (darkTheme) DarkAppColors else LightAppColors
    CompositionLocalProvider(LocalAppColors provides colors) {
        MaterialTheme(colorScheme = colors.toMaterial(), typography = AppMaterialTypography, content = content)
    }
}
