package com.jared.territorytool.core

import com.jared.territorytool.core.network.ApiService
import com.jared.territorytool.core.network.NetworkManager

/** Única factoría de servicios; los ViewModels piden aquí su `ApiService`. */
object DIContainer {
    val apiService: ApiService by lazy { NetworkManager() }
}
