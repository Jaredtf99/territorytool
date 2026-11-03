package com.jared.territorytool.designsystem

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.jared.territorytool.R

/**
 * Tipografía redondeada (equivalente a `design: .rounded` de iOS) con Nunito variable.
 * Tamaños según los text styles de iOS (largeTitle 34 … caption2 11).
 */
@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
private fun nunito(weight: FontWeight) = Font(
    R.font.nunito,
    weight = weight,
    variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)),
)

val Rounded = FontFamily(
    nunito(FontWeight.Normal),
    nunito(FontWeight.Medium),
    nunito(FontWeight.SemiBold),
    nunito(FontWeight.Bold),
    nunito(FontWeight.ExtraBold),
    nunito(FontWeight.Black),
)

private fun style(size: TextUnit, weight: FontWeight = FontWeight.Normal, line: TextUnit = (size.value * 1.25f).sp) =
    TextStyle(fontFamily = Rounded, fontSize = size, fontWeight = weight, lineHeight = line)

/** Text styles de iOS en versión redondeada. Usar `.copy(fontWeight = …)` para variar el peso. */
object AppType {
    val largeTitle = style(34.sp)
    val title = style(28.sp)
    val title2 = style(22.sp)
    val title3 = style(20.sp)
    val headline = style(17.sp, FontWeight.SemiBold)
    val body = style(17.sp)
    val callout = style(16.sp)
    val subheadline = style(15.sp)
    val footnote = style(13.sp)
    val caption = style(12.sp)
    val caption2 = style(11.sp)

    // Tokens de la guía de diseño
    val appLargeTitle = largeTitle.copy(fontWeight = FontWeight.Bold)
    val appTitle = title2.copy(fontWeight = FontWeight.SemiBold)
    val appHeadline = headline
    val appBody = body
    val appSubheadline = subheadline.copy(fontWeight = FontWeight.Medium)
    val appCaption = caption
}

val AppMaterialTypography = Typography(
    displayLarge = AppType.largeTitle,
    displayMedium = AppType.title,
    displaySmall = AppType.title2,
    headlineLarge = AppType.title,
    headlineMedium = AppType.title2,
    headlineSmall = AppType.title3,
    titleLarge = AppType.title3.copy(fontWeight = FontWeight.SemiBold),
    titleMedium = AppType.headline,
    titleSmall = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
    bodyLarge = AppType.body,
    bodyMedium = AppType.subheadline,
    bodySmall = AppType.caption,
    labelLarge = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
    labelMedium = AppType.caption.copy(fontWeight = FontWeight.Medium),
    labelSmall = AppType.caption2.copy(fontWeight = FontWeight.Medium),
)
