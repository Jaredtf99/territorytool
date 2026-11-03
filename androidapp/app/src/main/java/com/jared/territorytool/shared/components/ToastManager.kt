package com.jared.territorytool.shared.components

import com.jared.territorytool.shared.models.UndoHandle
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class ToastStyle { Success, Error, Info, Warning }

/**
 * `message` es una clave de localización (como en iOS) o un texto ya legible; se
 * resuelve al pintarse.
 */
data class ToastMessage(
    val message: String,
    val style: ToastStyle,
    val undoHandle: UndoHandle? = null,
    val durationMillis: Long = 3000,
    val stamp: Long = System.nanoTime(),
)

object ToastManager {
    private val pending = MutableStateFlow<ToastMessage?>(null)
    val pendingMessage: StateFlow<ToastMessage?> = pending

    fun show(message: String, style: ToastStyle = ToastStyle.Success, undoHandle: UndoHandle? = null, durationMillis: Long = 3000) {
        pending.value = ToastMessage(message, style, undoHandle, durationMillis)
    }

    fun clearPending() {
        pending.value = null
    }
}
