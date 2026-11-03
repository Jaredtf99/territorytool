package com.jared.territorytool.features.territories

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Ubicación bajo demanda (sólo cuando el usuario pide territorios cercanos). */
class TerritoryLocationService(private val context: Context) {
    private val client = LocationServices.getFusedLocationProviderClient(context)
    private val _location = MutableStateFlow<Location?>(null)
    val location: StateFlow<Location?> = _location
    private val _denied = MutableStateFlow(false)
    val isDenied: StateFlow<Boolean> = _denied
    internal var permissionLauncher: (() -> Unit)? = null

    val canShowLocation: Boolean
        get() = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    fun requestLocation() {
        if (canShowLocation) fetch() else permissionLauncher?.invoke()
    }

    internal fun onPermissionResult(granted: Boolean) {
        _denied.value = !granted
        if (granted) fetch()
    }

    @SuppressLint("MissingPermission")
    private fun fetch() {
        if (!canShowLocation) return
        client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token)
            .addOnSuccessListener { loc ->
                if (loc != null) _location.value = loc
                // Sin ubicación por red (sin SIM/Wi-Fi), BALANCED no enciende el GPS: se reintenta con él,
                // como hace CoreLocation en iOS.
                else client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, CancellationTokenSource().token)
                    .addOnSuccessListener { precise -> if (precise != null) _location.value = precise }
            }
    }
}

@Composable
fun rememberTerritoryLocationService(): TerritoryLocationService {
    val context = LocalContext.current
    val service = remember { TerritoryLocationService(context.applicationContext) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        service.onPermissionResult(result.values.any { it })
    }
    service.permissionLauncher = {
        launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }
    return service
}
