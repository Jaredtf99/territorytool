package com.jared.territorytool.shared.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.shared.models.DeliveryFormat

/**
 * Color de la familia "formato de entrega" (filtros, marca virtual, interruptor). Azul pizarra:
 * verde, ámbar y terracota quedan reservados al *estado* del territorio, así que no se confunden.
 */
val DeliveryFormat.Companion.familyTint: Color
    @Composable get() = AppTheme.colors.info

/** Color de la marca en un elemento concreto: solo lo virtual se destaca. */
val DeliveryFormat.tint: Color
    @Composable get() = when (this) {
        DeliveryFormat.Physical -> AppTheme.colors.textSecondary
        DeliveryFormat.Virtual -> DeliveryFormat.familyTint
    }

/**
 * Marca de entrega virtual para líneas de información (lista, detalle, trayectoria). Va en línea
 * con el texto que la acompaña ("Desde hace 34 días · Virtual"), con la misma tipografía y sin
 * cápsula, para leerse como un dato más y no confundirse con los chips de filtro. Físico es el
 * formato por defecto y no se marca.
 */
@Composable
fun DeliveryFormatBadge(format: DeliveryFormat, modifier: Modifier = Modifier, leadingSeparator: Boolean = false) {
    if (format != DeliveryFormat.Virtual) return
    val tint = format.tint
    val description = stringResource(R.string.delivery_format_delivered_virtually)
    val style = AppType.appCaption.copy(fontWeight = FontWeight.SemiBold)
    Row(
        modifier.clearAndSetSemantics { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (leadingSeparator) Text("·", style = style, color = AppTheme.colors.textSecondary)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            Icon(format.icon, null, Modifier.size(12.dp), tint = tint)
            Text(stringResource(format.titleRes), style = style, color = tint, maxLines = 1, softWrap = false)
        }
    }
}

/**
 * Coloca la marca virtual detrás de [detail] si cabe entera en la línea; si no (texto grande,
 * poco ancho), la baja a una segunda línea. La marca nunca se pierde ni recorta el dato.
 */
@Composable
fun DetailWithVirtualMark(format: DeliveryFormat?, modifier: Modifier = Modifier, detail: @Composable () -> Unit) {
    if (format != DeliveryFormat.Virtual) {
        Row(modifier) { detail() }
        return
    }
    val gap = 4.dp
    val lineGap = 2.dp
    Layout(
        content = {
            detail()
            DeliveryFormatBadge(format, leadingSeparator = true)
            DeliveryFormatBadge(format)
        },
        modifier = modifier,
    ) { measurables, constraints ->
        val gapPx = gap.roundToPx()
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val inlineBadge = measurables[1].measure(loose.copy(maxWidth = Constraints.Infinity))
        val detailNatural = measurables[0].maxIntrinsicWidth(constraints.maxHeight)
        val fitsInline = constraints.maxWidth == Constraints.Infinity ||
            detailNatural + gapPx + inlineBadge.width <= constraints.maxWidth
        if (fitsInline) {
            val detailPlaceable = measurables[0].measure(loose)
            val height = maxOf(detailPlaceable.height, inlineBadge.height)
            val width = detailPlaceable.width + gapPx + inlineBadge.width
            layout(width.coerceAtMost(constraints.maxWidth), height) {
                detailPlaceable.placeRelative(0, (height - detailPlaceable.height) / 2)
                inlineBadge.placeRelative(detailPlaceable.width + gapPx, (height - inlineBadge.height) / 2)
            }
        } else {
            val detailPlaceable = measurables[0].measure(loose)
            val stacked = measurables[2].measure(loose)
            val lineGapPx = lineGap.roundToPx()
            val width = maxOf(detailPlaceable.width, stacked.width).coerceAtMost(constraints.maxWidth)
            layout(width, detailPlaceable.height + lineGapPx + stacked.height) {
                detailPlaceable.placeRelative(0, 0)
                stacked.placeRelative(0, detailPlaceable.height + lineGapPx)
            }
        }
    }
}
