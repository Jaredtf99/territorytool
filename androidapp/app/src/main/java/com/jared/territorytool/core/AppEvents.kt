package com.jared.territorytool.core

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.filter

/** Equivalente a las `Notification.Name` de iOS: eventos internos de la app en un solo sitio. */
enum class AppEvent {
    AuthChanged,
    SessionExpired,
    CongregationChanged,
    UserRequestedLogout,
    TerritoryDeleted,
    TerritoryDataChanged,
    UserDataChanged,
}

object AppEvents {
    private val events = MutableSharedFlow<AppEvent>(extraBufferCapacity = 64)
    val flow: SharedFlow<AppEvent> = events.asSharedFlow()

    fun post(event: AppEvent) {
        events.tryEmit(event)
    }

    fun of(vararg types: AppEvent) = flow.filter { it in types }
}
