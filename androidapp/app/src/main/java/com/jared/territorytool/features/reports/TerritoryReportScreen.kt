package com.jared.territorytool.features.reports

import android.app.Application
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.IosShare
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jared.territorytool.R
import com.jared.territorytool.core.DIContainer
import com.jared.territorytool.core.Strings
import com.jared.territorytool.core.navigation.LocalNavigator
import com.jared.territorytool.core.network.SupabaseAuthService
import com.jared.territorytool.core.network.TokenManager
import com.jared.territorytool.designsystem.AppSpacing
import com.jared.territorytool.designsystem.AppTheme
import com.jared.territorytool.designsystem.AppType
import com.jared.territorytool.designsystem.FormDivider
import com.jared.territorytool.designsystem.FormRow
import com.jared.territorytool.designsystem.FormScreen
import com.jared.territorytool.designsystem.FormSection
import com.jared.territorytool.designsystem.bounceClick
import com.jared.territorytool.shared.components.AppSheet
import com.jared.territorytool.shared.components.DateTimeField
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class TerritoryReportViewModel(app: Application) : AndroidViewModel(app) {
    private val api = DIContainer.apiService
    val startDate = MutableStateFlow(ZonedDateTime.now().minusMonths(1).toInstant())
    val endDate = MutableStateFlow(Instant.now())
    val isGenerating = MutableStateFlow(false)
    val errorMessage = MutableStateFlow<String?>(null)
    val generatedReport = MutableStateFlow<File?>(null)

    private fun day(instant: Instant): LocalDate = instant.atZone(ZoneId.systemDefault()).toLocalDate()

    val isRangeValid: Boolean get() = !day(startDate.value).isAfter(day(endDate.value))

    fun generate() {
        if (isGenerating.value) return
        errorMessage.value = null
        if (!isRangeValid) {
            errorMessage.value = Strings.get(R.string.reports_error_invalid_range)
            return
        }
        isGenerating.value = true
        viewModelScope.launch {
            try {
                // El rango cubre los días completos elegidos.
                val zone = ZoneId.systemDefault()
                val start = day(startDate.value).atStartOfDay(zone).toInstant()
                val end = day(endDate.value).plusDays(1).atStartOfDay(zone).toInstant().minusSeconds(1)
                val response = api.getTerritoryReport(start, end)
                if (response.entries.isEmpty()) {
                    errorMessage.value = Strings.get(R.string.reports_error_empty)
                    return@launch
                }
                val data = TerritoryReportData(response.entries, response.totalTerritories, start, end, activeCongregationName())
                val dir = File(getApplication<Application>().cacheDir, "reports").apply { mkdirs() }
                val file = File(dir, "TerritoryReport_${day(start)}_${day(end)}.pdf")
                withContext(Dispatchers.IO) { TerritoryReportPdfBuilder(getApplication(), data).writePdf(file) }
                generatedReport.value = file
            } catch (e: Exception) {
                errorMessage.value = e.localizedMessage
            } finally {
                isGenerating.value = false
            }
        }
    }

    private fun activeCongregationName(): String? {
        val list = TokenManager.getCongregationsJson()?.let(SupabaseAuthService::decodeCongregations) ?: return null
        val activeId = TokenManager.getActiveCongregationId()
        return list.firstOrNull { it.id == activeId }?.name ?: list.firstOrNull { it.isActive }?.name
    }
}

@Composable
fun TerritoryReportScreen(viewModel: TerritoryReportViewModel = viewModel()) {
    val navigator = LocalNavigator.current
    val colors = AppTheme.colors
    val start by viewModel.startDate.collectAsStateWithLifecycle()
    val end by viewModel.endDate.collectAsStateWithLifecycle()
    val generating by viewModel.isGenerating.collectAsStateWithLifecycle()
    val error by viewModel.errorMessage.collectAsStateWithLifecycle()
    val report by viewModel.generatedReport.collectAsStateWithLifecycle()

    FormScreen(stringResource(R.string.reports_title), onBack = navigator::pop) {
        FormSection(stringResource(R.string.reports_date_range), footer = stringResource(R.string.reports_description)) {
            FormRow {
                Text(stringResource(R.string.reports_start_date), style = AppType.body, color = colors.textPrimary, modifier = Modifier.weight(1f))
                DateTimeField(start, { viewModel.startDate.value = it }, includeTime = false, maxDate = end)
            }
            FormDivider()
            FormRow {
                Text(stringResource(R.string.reports_end_date), style = AppType.body, color = colors.textPrimary, modifier = Modifier.weight(1f))
                DateTimeField(end, { viewModel.endDate.value = it }, includeTime = false)
            }
        }
        FormSection {
            val enabled = !generating && viewModel.isRangeValid
            FormRow(onClick = viewModel::generate, enabled = enabled) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    if (generating) {
                        CircularProgressIndicator(Modifier.size(18.dp), color = colors.accent, strokeWidth = 2.dp)
                        Text(stringResource(R.string.reports_generating), style = AppType.body, color = colors.accent, modifier = Modifier.padding(start = 8.dp))
                    } else {
                        Icon(Icons.Rounded.Description, null, Modifier.size(20.dp), tint = colors.accent.copy(alpha = if (enabled) 1f else 0.4f))
                        Text(stringResource(R.string.reports_generate), style = AppType.body, color = colors.accent.copy(alpha = if (enabled) 1f else 0.4f), modifier = Modifier.padding(start = 8.dp))
                    }
                }
            }
        }
        error?.let {
            FormSection {
                FormRow {
                    Icon(Icons.Rounded.Warning, null, Modifier.size(18.dp), tint = colors.warning)
                    Text(it, style = AppType.footnote, color = colors.warning)
                }
            }
        }
    }

    report?.let { ReportPreviewSheet(it, onDismiss = { viewModel.generatedReport.value = null }) }
}

/** Previsualización del PDF generado con opción de compartir. */
@Composable
private fun ReportPreviewSheet(file: File, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val colors = AppTheme.colors
    var pages by remember(file) { mutableStateOf<List<Bitmap>?>(null) }
    LaunchedEffect(file) {
        pages = withContext(Dispatchers.IO) {
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    (0 until renderer.pageCount).map { index ->
                        renderer.openPage(index).use { page ->
                            Bitmap.createBitmap(page.width * 2, page.height * 2, Bitmap.Config.ARGB_8888).also {
                                it.eraseColor(android.graphics.Color.WHITE)
                                page.render(it, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            }
                        }
                    }
                }
            }
        }
    }

    fun share() {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, Strings.get(R.string.share_report)))
    }

    AppSheet(onDismiss) {
        Column(Modifier.fillMaxHeight(0.94f)) {
            Box(Modifier.fillMaxWidth().padding(horizontal = AppSpacing.md, vertical = AppSpacing.xs)) {
                Text(
                    stringResource(R.string.cancel),
                    style = AppType.body,
                    color = colors.accent,
                    modifier = Modifier.align(Alignment.CenterStart).bounceClick(onClick = onDismiss),
                )
                Text(stringResource(R.string.reports_title), style = AppType.headline, color = colors.textPrimary, modifier = Modifier.align(Alignment.Center))
                Row(
                    Modifier.align(Alignment.CenterEnd).bounceClick(onClick = ::share),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(Icons.Rounded.IosShare, null, Modifier.size(18.dp), tint = colors.accent)
                    Text(stringResource(R.string.reports_share), style = AppType.body, color = colors.accent)
                }
            }
            Box(Modifier.fillMaxWidth().background(Color(0xFFE7DECB)), contentAlignment = Alignment.TopCenter) {
                val list = pages
                if (list == null) {
                    CircularProgressIndicator(Modifier.padding(AppSpacing.xl), color = colors.accent)
                } else {
                    LazyColumn(contentPadding = androidx.compose.foundation.layout.PaddingValues(AppSpacing.md), verticalArrangement = Arrangement.spacedBy(AppSpacing.md)) {
                        items(list) { bitmap ->
                            Image(
                                bitmap.asImageBitmap(),
                                null,
                                Modifier.fillMaxWidth().shadow(6.dp),
                                contentScale = ContentScale.FillWidth,
                            )
                        }
                    }
                }
            }
        }
    }
}
