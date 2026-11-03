package com.jared.territorytool.core

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Equivalente a `HapticManager` de iOS sobre el vibrador del sistema. */
@SuppressLint("StaticFieldLeak")
object HapticManager {
    enum class Notification { Success, Warning, Error }
    enum class Impact { Light, Medium, Heavy }

    private var vibrator: Vibrator? = null

    fun init(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    fun notification(type: Notification) = when (type) {
        Notification.Success -> waveform(longArrayOf(0, 18, 60, 26), intArrayOf(0, 120, 0, 200))
        Notification.Warning -> waveform(longArrayOf(0, 26, 80, 18), intArrayOf(0, 200, 0, 120))
        Notification.Error -> waveform(longArrayOf(0, 24, 50, 24, 50, 30), intArrayOf(0, 200, 0, 200, 0, 255))
    }

    fun impact(style: Impact) = when (style) {
        Impact.Light -> predefined(VibrationEffect.EFFECT_TICK, 10)
        Impact.Medium -> predefined(VibrationEffect.EFFECT_CLICK, 18)
        Impact.Heavy -> predefined(VibrationEffect.EFFECT_HEAVY_CLICK, 28)
    }

    fun selection() = predefined(VibrationEffect.EFFECT_TICK, 8)

    private fun predefined(effect: Int, fallbackMs: Long) {
        val v = vibrator ?: return
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) v.vibrate(VibrationEffect.createPredefined(effect))
            else v.vibrate(VibrationEffect.createOneShot(fallbackMs, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }

    private fun waveform(timings: LongArray, amplitudes: IntArray) {
        val v = vibrator ?: return
        runCatching {
            if (v.hasAmplitudeControl()) v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            else v.vibrate(VibrationEffect.createWaveform(timings, -1))
        }
    }
}
