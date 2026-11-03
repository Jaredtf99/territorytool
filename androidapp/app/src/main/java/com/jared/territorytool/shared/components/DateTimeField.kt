package com.jared.territorytool.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.jared.territorytool.R
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** Formatos de fecha localizados (equivalentes a `.formatted(date:time:)`). */
object DateFormats {
    private val zone get() = ZoneId.systemDefault()
    private val locale get() = com.jared.territorytool.core.Strings.currentLocale

    fun abbreviated(instant: Instant): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(instant.atZone(zone))

    fun long(instant: Instant): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale).format(instant.atZone(zone))

    fun dateTime(instant: Instant): String =
        DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT).withLocale(locale).format(instant.atZone(zone))

    fun time(instant: Instant): String =
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(instant.atZone(zone))

    fun pattern(instant: Instant, pattern: String): String =
        DateTimeFormatter.ofPattern(pattern, locale).format(instant.atZone(zone))

    /** Texto relativo ("hace 3 días"), como `Text(date, style: .relative)`. */
    fun relative(instant: Instant): String =
        android.text.format.DateUtils.getRelativeTimeSpanString(
            instant.toEpochMilli(),
            System.currentTimeMillis(),
            android.text.format.DateUtils.MINUTE_IN_MILLIS,
            android.text.format.DateUtils.FORMAT_ABBREV_RELATIVE,
        ).toString()
}

/**
 * Selector compacto de fecha (y opcionalmente hora), como `DatePicker` compacto de iOS:
 * cápsulas que abren el diálogo correspondiente.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateTimeField(
    value: Instant,
    onValueChange: (Instant) -> Unit,
    modifier: Modifier = Modifier,
    includeTime: Boolean = true,
    maxDate: Instant? = null,
) {
    val colors = AppTheme.colors
    val zone = ZoneId.systemDefault()
    val zoned = value.atZone(zone)
    var showDate by remember { mutableStateOf(false) }
    var showTime by remember { mutableStateOf(false) }

    Row(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Chip(DateFormats.abbreviated(value)) { showDate = true }
        if (includeTime) Chip(DateFormats.time(value)) { showTime = true }
    }

    if (showDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = zoned.toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : androidx.compose.material3.SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    maxDate == null || utcTimeMillis <= maxDate.atZone(zone).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
            },
        )
        DatePickerDialog(
            onDismissRequest = { showDate = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { millis ->
                        val date = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                        onValueChange(ZonedDateTime.of(date, zoned.toLocalTime(), zone).toInstant())
                    }
                    showDate = false
                }) { Text(stringResource(R.string.common_ok), color = colors.accent) }
            },
            dismissButton = { TextButton(onClick = { showDate = false }) { Text(stringResource(R.string.common_cancel), color = colors.accent) } },
            colors = DatePickerDefaults.colors(containerColor = colors.surfaceRaised),
        ) {
            DatePicker(
                state = state,
                colors = DatePickerDefaults.colors(
                    containerColor = colors.surfaceRaised,
                    selectedDayContainerColor = colors.accent,
                    todayDateBorderColor = colors.accent,
                    todayContentColor = colors.accent,
                ),
            )
        }
    }

    if (showTime) {
        val is24 = android.text.format.DateFormat.is24HourFormat(LocalContext.current)
        val state = rememberTimePickerState(zoned.hour, zoned.minute, is24)
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showTime = false },
            containerColor = colors.surfaceRaised,
            confirmButton = {
                TextButton(onClick = {
                    onValueChange(ZonedDateTime.of(zoned.toLocalDate(), LocalTime.of(state.hour, state.minute), zone).toInstant())
                    showTime = false
                }) { Text(stringResource(R.string.common_ok), color = colors.accent) }
            },
            dismissButton = { TextButton(onClick = { showTime = false }) { Text(stringResource(R.string.common_cancel), color = colors.accent) } },
            text = {
                TimePicker(
                    state = state,
                    colors = TimePickerDefaults.colors(
                        selectorColor = colors.accent,
                        timeSelectorSelectedContainerColor = colors.accent.copy(alpha = 0.2f),
                        timeSelectorSelectedContentColor = colors.accentDeep,
                    ),
                )
            },
        )
    }
}

@Composable
private fun Chip(text: String, onClick: () -> Unit) {
    val colors = AppTheme.colors
    Text(
        text,
        style = AppType.body,
        color = colors.textPrimary,
        modifier = Modifier
            .background(colors.textSecondary.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp),
    )
}

fun LocalDate.startOfDay(): Instant = atStartOfDay(ZoneId.systemDefault()).toInstant()
