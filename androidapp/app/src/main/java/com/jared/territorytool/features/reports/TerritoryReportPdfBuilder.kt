package com.jared.territorytool.features.reports

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import androidx.core.content.res.ResourcesCompat
import com.jared.territorytool.R
import com.jared.territorytool.core.Strings
import com.jared.territorytool.shared.models.daysBetween
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Genera el PDF del informe con el estilo "cartográfico cálido" de la app. Usa siempre
 * la paleta clara (es un documento impreso) y el idioma elegido en la app.
 */
class TerritoryReportPdfBuilder(private val context: Context, private val data: TerritoryReportData) {

    // MARK: Layout (A4 en puntos)
    private val pageW = 595.2f
    private val pageH = 841.8f
    private val margin = 44f
    private val contentWidth get() = pageW - margin * 2
    private val bottomLimit get() = pageH - margin - 24

    private val colPerson = 230f
    private val colDate = 90f
    private val colGap = 12f

    // MARK: Paleta clara
    private val paper = 0xFFFBF8F1.toInt()
    private val paperDeep = 0xFFF4EFE6.toInt()
    private val ink = 0xFF2C271F.toInt()
    private val inkSoft = 0xFF756A56.toInt()
    private val forest = 0xFF2F6B4F.toInt()
    private val forestDeep = 0xFF234E39.toInt()
    private val amber = 0xFFD98A2B.toInt()
    private val terracotta = 0xFFC4633B.toInt()
    private val hairline = 0xFFDED3BE.toInt()

    private val baseTypeface: Typeface = ResourcesCompat.getFont(context, R.font.nunito) ?: Typeface.DEFAULT
    private val locale = Strings.currentLocale

    private lateinit var document: PdfDocument
    private var page: PdfDocument.Page? = null
    private val canvas: Canvas get() = page!!.canvas
    private var cursorY = 0f
    private var pageNumber = 0

    fun writePdf(file: File) {
        document = PdfDocument()
        beginPage()
        drawHeader()
        drawSummary()
        data.groups.forEach(::drawGroup)
        page?.let(document::finishPage)
        FileOutputStream(file).use(document::writeTo)
        document.close()
    }

    // MARK: - Páginas

    private fun beginPage() {
        page?.let(document::finishPage)
        pageNumber += 1
        page = document.startPage(PdfDocument.PageInfo.Builder(pageW.toInt(), pageH.toInt(), pageNumber).create())
        canvas.drawRect(0f, 0f, pageW, pageH, fill(paper))
        canvas.drawRoundRect(RectF(16f, 16f, pageW - 16, pageH - 16), 10f, 10f, stroke(hairline, 1f))
        drawFooter()
        cursorY = margin
    }

    private fun drawFooter() {
        val font = font(8.5f, 400)
        draw("${L(R.string.reports_title)} · ${formattedRange()}", font, inkSoft, margin, pageH - margin + 14)
        drawRight(L(R.string.reports_pdf_page, pageNumber), font, inkSoft, pageW - margin, pageH - margin + 14)
    }

    private fun ensureSpace(height: Float) {
        if (cursorY + height > bottomLimit) beginPage()
    }

    // MARK: - Cabecera y resumen

    private fun drawHeader() {
        draw(L(R.string.reports_title), font(30f, 700), forestDeep, margin, cursorY)
        cursorY += 42
        var subtitle = formattedRange()
        data.congregationName?.takeIf { it.isNotEmpty() }?.let { subtitle = "$it · $subtitle" }
        draw(subtitle, font(12f, 600), ink, margin, cursorY)
        drawRight(L(R.string.reports_pdf_generated_on, formattedDate(Instant.now())), font(9f, 400), inkSoft, pageW - margin, cursorY + 3)
        cursorY += 24
        canvas.drawLine(margin, cursorY, pageW - margin, cursorY, stroke(hairline, 1f))
        cursorY += 18
    }

    private fun drawSummary() {
        val stats = listOf(
                Triple(data.territoriesWorked.toString(), L(R.string.reports_pdf_worked), forest),
                Triple(data.territoriesNotWorked.toString(), L(R.string.reports_pdf_not_worked), terracotta),
        )
        val gap = 10f
        val boxW = (contentWidth - gap * (stats.size - 1)) / stats.size
        val boxH = 58f
        ensureSpace(boxH + 20)
        stats.forEachIndexed { i, (value, label, color) ->
            val x = margin + i * (boxW + gap)
            val box = RectF(x, cursorY, x + boxW, cursorY + boxH)
            canvas.drawRoundRect(box, 10f, 10f, fill(android.graphics.Color.WHITE))
            canvas.drawRoundRect(box, 10f, 10f, stroke(hairline, 1f))
            drawCentered(value, font(22f, 700), color, box.centerX(), box.top + 8)
            drawCentered(label.uppercase(locale), font(7.5f, 600, letterSpacing = 0.08f), inkSoft, box.centerX(), box.top + 38)
        }
        cursorY += boxH + 22
    }

    // MARK: - Grupos

    private fun drawGroup(group: TerritoryReportData.TerritoryGroup) {
        ensureSpace(58f)
        drawGroupHeader(group, continued = false)
        drawColumnHeaders()
        group.entries.forEachIndexed { index, entry ->
            if (cursorY + 22 > bottomLimit) {
                beginPage()
                drawGroupHeader(group, continued = true)
                drawColumnHeaders()
            }
            drawRow(entry, striped = index % 2 == 0)
        }
        cursorY += 16
    }

    private fun drawGroupHeader(group: TerritoryReportData.TerritoryGroup, continued: Boolean) {
        val badgeFont = font(10f, 700)
        val badgeW = badgeFont.measureText(group.code)
        val badge = RectF(margin, cursorY, margin + badgeW + 14, cursorY + 20)
        canvas.drawRoundRect(badge, 6f, 6f, fill(forest))
        draw(group.code, badgeFont, android.graphics.Color.WHITE, badge.left + 7, badge.top + (20 - lineHeight(badgeFont)) / 2)

        val name = if (continued) "${group.name} ${L(R.string.reports_pdf_continued)}" else group.name
        draw(name, font(12f, 700), ink, badge.right + 8, cursorY + 3)
        val count = if (group.entries.size == 1) L(R.string.reports_pdf_assignments_one)
        else L(R.string.reports_pdf_assignments_count, group.entries.size)
        drawRight(count, font(9f, 400), inkSoft, pageW - margin, cursorY + 5)
        cursorY += 28
    }

    private fun drawColumnHeaders() {
        val font = font(7.5f, 600, letterSpacing = 0.07f)
        var x = margin
        draw(L(R.string.reports_pdf_person).uppercase(locale), font, inkSoft, x, cursorY)
        x += colPerson + colGap
        draw(L(R.string.reports_pdf_given_date).uppercase(locale), font, inkSoft, x, cursorY)
        x += colDate + colGap
        draw(L(R.string.reports_pdf_picked_date).uppercase(locale), font, inkSoft, x, cursorY)
        x += colDate + colGap
        draw(L(R.string.reports_pdf_days).uppercase(locale), font, inkSoft, x, cursorY)
        cursorY += 14
        canvas.drawLine(margin, cursorY - 2, pageW - margin, cursorY - 2, stroke(hairline, 0.7f))
    }

    private fun drawRow(entry: TerritoryReportEntry, striped: Boolean) {
        val rowH = 21f
        if (striped) {
            val paint = fill(paperDeep).apply { alpha = (0.55f * 255).toInt() }
            canvas.drawRoundRect(RectF(margin - 4, cursorY - 2, margin + contentWidth + 4, cursorY - 2 + rowH), 5f, 5f, paint)
        }
        val y = cursorY + 3
        var x = margin
        val personFont = font(9.5f, 500)
        draw(truncated(entry.personName ?: "—", colPerson, personFont), personFont, ink, x, y)
        x += colPerson + colGap
        draw(entry.givenAt?.let(::formattedShortDate) ?: "—", font(9f, 400), ink, x, y)
        x += colDate + colGap
        val open = entry.pickedAt == null
        draw(entry.pickedAt?.let(::formattedShortDate) ?: L(R.string.reports_pdf_in_progress), font(9f, if (open) 600 else 400), if (open) amber else ink, x, y)
        x += colDate + colGap
        draw(durationDays(entry), font(9f, 400), inkSoft, x, y)
        cursorY += rowH
    }

    // MARK: - Dibujo

    private fun font(size: Float, weight: Int, letterSpacing: Float = 0f) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        typeface = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Typeface.create(baseTypeface, weight, false)
        else Typeface.create(baseTypeface, if (weight >= 600) Typeface.BOLD else Typeface.NORMAL)
        this.letterSpacing = letterSpacing
    }

    private fun fill(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color; style = Paint.Style.FILL }
    private fun stroke(color: Int, width: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color; style = Paint.Style.STROKE; strokeWidth = width }
    private fun lineHeight(paint: Paint) = paint.fontMetrics.let { it.descent - it.ascent }

    /** Dibuja con origen en la esquina superior izquierda (como `NSAttributedString.draw(at:)`). */
    private fun draw(text: String, paint: Paint, color: Int, x: Float, top: Float) {
        paint.color = color
        canvas.drawText(text, x, top - paint.fontMetrics.ascent, paint)
    }

    private fun drawRight(text: String, paint: Paint, color: Int, right: Float, top: Float) =
        draw(text, paint, color, right - paint.measureText(text), top)

    private fun drawCentered(text: String, paint: Paint, color: Int, cx: Float, top: Float) =
        draw(text, paint, color, cx - paint.measureText(text) / 2, top)

    private fun truncated(text: String, maxWidth: Float, paint: Paint): String {
        var result = text
        while (result.length > 4 && paint.measureText("$result…") > maxWidth) result = result.dropLast(1)
        return if (result == text) text else "$result…"
    }

    // MARK: - Formato

    private fun formattedRange() = "${formattedDate(data.startDate)} – ${formattedDate(data.endDate)}"

    private fun formattedDate(instant: Instant) =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(instant.atZone(ZoneId.systemDefault()))

    private fun formattedShortDate(instant: Instant): String {
        val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "dMMMyy")
        return DateTimeFormatter.ofPattern(pattern, locale).format(instant.atZone(ZoneId.systemDefault()))
    }

    private fun durationDays(entry: TerritoryReportEntry): String {
        val given = entry.givenAt ?: return "—"
        val end = entry.pickedAt ?: minOf(Instant.now(), data.endDate)
        return daysBetween(given, end).coerceAtLeast(0).toString()
    }

    private fun L(id: Int, vararg args: Any) = Strings.get(id, *args)
}
