package com.jared.territorytool.shared.models

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Smartphone
import androidx.compose.ui.graphics.vector.ImageVector
import com.jared.territorytool.R
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Cómo se entregó un territorio: en papel (por defecto) o en formato digital. `raw` = `delivery_format`. */
@Serializable
enum class DeliveryFormat(val raw: String, @StringRes val titleRes: Int, val icon: ImageVector) {
    @SerialName("physical") Physical("physical", R.string.delivery_format_physical, Icons.Rounded.Description),
    @SerialName("virtual") Virtual("virtual", R.string.delivery_format_virtual, Icons.Rounded.Smartphone);

    companion object {
        /** Filas sin la columna (o con un valor desconocido) cuentan como físicas. */
        fun from(raw: String?): DeliveryFormat = entries.firstOrNull { it.raw == raw } ?: Physical
    }
}
