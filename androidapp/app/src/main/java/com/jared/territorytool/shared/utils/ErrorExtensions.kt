package com.jared.territorytool.shared.utils

import com.jared.territorytool.R
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.network.NetworkError
import kotlinx.coroutines.CancellationException
import java.io.InterruptedIOException

/** `true` cuando el error es una cancelación normal (corrutina o petición cancelada). */
val Throwable.isCancellation: Boolean
    get() = this is CancellationException || (this is InterruptedIOException && message == "Canceled") ||
        (this is java.io.IOException && message == "Canceled")

/**
 * Mensaje claro para el usuario a partir de un error de backend. Si hay traducción para
 * `error.code.<CÓDIGO>` se usa; si parece un código sin traducir, mensaje genérico.
 */
val Throwable.userFriendlyMessage: String
    get() {
        val raw = (this as? NetworkError.Server)?.serverMessage ?: localizedMessage ?: ""
        val trimmed = raw.trim()
        val key = "error.code.$trimmed"
        if (trimmed.isNotEmpty() && Strings.hasKey(key)) return Strings.key(key)
        if (Regex("^[A-Z][A-Z0-9_]+$").matches(trimmed)) return Strings.get(R.string.error_action_failed)
        return trimmed.ifEmpty { Strings.get(R.string.error_action_failed) }
    }
