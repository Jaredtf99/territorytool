package com.jared.territorytool.shared.components

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.FlashlightOff
import androidx.compose.material.icons.rounded.FlashlightOn
import androidx.compose.material.icons.rounded.NoPhotography
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.jared.territorytool.R
import com.jared.territorytool.core.HapticManager
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.bounceClick
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Previsualización de cámara que lee códigos QR (CameraX + ML Kit). Equivale a
 * `CameraScannerSession`: tras una lectura congela el análisis hasta que `isScanning`
 * vuelva a activarse.
 */
@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
@Composable
fun CameraScannerPreview(
    isScanning: Boolean,
    torchOn: Boolean,
    onScan: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnScan by rememberUpdatedState(onScan)
    val reported = remember { AtomicBoolean(false) }
    val scanningFlag = remember { AtomicBoolean(isScanning) }
    var camera by remember { mutableStateOf<Camera?>(null) }
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }

    LaunchedEffect(isScanning) {
        scanningFlag.set(isScanning)
        if (isScanning) reported.set(false)
    }
    LaunchedEffect(torchOn, camera) {
        camera?.takeIf { it.cameraInfo.hasFlashUnit() }?.cameraControl?.enableTorch(torchOn)
    }

    DisposableEffect(lifecycleOwner) {
        val executor = Executors.newSingleThreadExecutor()
        val scanner = BarcodeScanning.getClient(BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build())
        val providerFuture = ProcessCameraProvider.getInstance(context)
        var provider: ProcessCameraProvider? = null
        providerFuture.addListener({
            val p = providerFuture.get()
            provider = p
            val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            analysis.setAnalyzer(executor) { proxy ->
                val media = proxy.image
                if (media == null || !scanningFlag.get() || reported.get()) {
                    proxy.close()
                    return@setAnalyzer
                }
                scanner.process(InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees))
                    .addOnSuccessListener { codes ->
                        val value = codes.firstNotNullOfOrNull { it.rawValue }
                        if (value != null && scanningFlag.get() && reported.compareAndSet(false, true)) {
                            HapticManager.notification(HapticManager.Notification.Success)
                            currentOnScan(value)
                        }
                    }
                    .addOnCompleteListener { proxy.close() }
            }
            runCatching {
                p.unbindAll()
                camera = p.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            }
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            provider?.unbindAll()
            scanner.close()
            executor.shutdown()
        }
    }

    AndroidView({ previewView }, modifier)
}

fun Context.hasCameraPermission() =
    ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

fun Context.openAppSettings() {
    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
}

enum class CameraAuth { Authorized, NotDetermined, Denied }

/** Estado del permiso de cámara; lo solicita al montarse si aún no se ha concedido. */
@Composable
fun rememberCameraAuthorization(): CameraAuth {
    val context = LocalContext.current
    var status by remember { mutableStateOf(if (context.hasCameraPermission()) CameraAuth.Authorized else CameraAuth.NotDetermined) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        status = if (granted) CameraAuth.Authorized else CameraAuth.Denied
    }
    LaunchedEffect(Unit) {
        if (status == CameraAuth.NotDetermined) launcher.launch(Manifest.permission.CAMERA)
    }
    return status
}

/** Escáner QR a pantalla completa (equivale a `QRScannerView`). */
@Composable
fun QRScannerDialog(onDismiss: () -> Unit, onScan: (String) -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        val auth = rememberCameraAuthorization()
        var torch by remember { mutableStateOf(false) }
        val context = LocalContext.current
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            when (auth) {
                CameraAuth.Authorized -> CameraScannerPreview(true, torch, { onScan(it); onDismiss() }, Modifier.fillMaxSize())
                CameraAuth.NotDetermined -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White)
                CameraAuth.Denied -> Column(
                    Modifier.align(Alignment.Center).padding(AppSpacing.lg),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
                ) {
                    Icon(Icons.Rounded.NoPhotography, null, Modifier.size(40.dp), tint = Color.White)
                    Text(stringResource(R.string.camera_permission_needed), style = AppType.body, color = Color.White, textAlign = TextAlign.Center)
                    Text(
                        stringResource(R.string.open_settings),
                        style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = Color.White,
                        modifier = Modifier.border(1.dp, Color.White.copy(alpha = 0.4f), CircleShape).bounceClick { context.openAppSettings() }
                            .padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs),
                    )
                }
            }
            Row(
                Modifier.fillMaxWidth().statusBarsPadding().padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Icon(
                    if (torch) Icons.Rounded.FlashlightOn else Icons.Rounded.FlashlightOff,
                    stringResource(R.string.scanner_torch),
                    Modifier.size(44.dp).background(Color.White.copy(alpha = 0.18f), CircleShape).bounceClick { torch = !torch }.padding(10.dp),
                    tint = Color.White,
                )
                Icon(
                    Icons.Rounded.Cancel,
                    stringResource(R.string.common_close),
                    Modifier.size(44.dp).bounceClick(onClick = onDismiss),
                    tint = Color.White,
                )
            }
        }
    }
}
