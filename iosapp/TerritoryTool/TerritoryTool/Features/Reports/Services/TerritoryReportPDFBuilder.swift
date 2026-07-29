import UIKit

/// Genera el PDF del informe de movimientos de territorios con el estilo
/// "cartográfico cálido" de la app: papel, verde bosque, ámbar y terracota.
/// El PDF usa siempre la variante clara de la paleta (es un documento impreso).
final class TerritoryReportPDFBuilder {

    private let data: TerritoryReportData
    private let locale: Locale
    private let bundle: Bundle

    init(data: TerritoryReportData) {
        self.data = data
        self.locale = LanguageManager.shared.locale
        self.bundle = Self.localizationBundle()
    }

    // MARK: - Layout

    private let pageSize = CGSize(width: 595.2, height: 841.8) // A4
    private let margin: CGFloat = 44
    private var contentWidth: CGFloat { pageSize.width - margin * 2 }
    private var bottomLimit: CGFloat { pageSize.height - margin - 24 }

    // Columnas de la tabla de movimientos.
    private let colPerson: CGFloat = 230
    private let colDate: CGFloat = 90
    private let colGap: CGFloat = 12

    // MARK: - Paleta (valores claros de Color+Extensions)

    private let paper       = UIColor(rgb: 0xFBF8F1)
    private let paperDeep   = UIColor(rgb: 0xF4EFE6)
    private let ink         = UIColor(rgb: 0x2C271F)
    private let inkSoft     = UIColor(rgb: 0x756A56)
    private let forest      = UIColor(rgb: 0x2F6B4F)
    private let forestDeep  = UIColor(rgb: 0x234E39)
    private let amber       = UIColor(rgb: 0xD98A2B)
    private let terracotta  = UIColor(rgb: 0xC4633B)
    private let hairline    = UIColor(rgb: 0xDED3BE)

    // MARK: - Estado de paginación

    private var cursorY: CGFloat = 0
    private var pageNumber = 0
    private var rendererContext: UIGraphicsPDFRendererContext?

    // MARK: - API

    /// Escribe el PDF y devuelve la URL del archivo generado.
    func writePDF(to url: URL) throws {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: L("reports.title"),
            kCGPDFContextCreator as String: "Territory Tool"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        try renderer.writePDF(to: url) { context in
            rendererContext = context
            beginPage()
            drawHeader()
            drawSummary()
            for group in data.groups {
                drawGroup(group)
            }
        }
    }

    // MARK: - Páginas

    private func beginPage() {
        guard let context = rendererContext else { return }
        context.beginPage()
        pageNumber += 1

        // Fondo papel + marco fino, como las tarjetas de la app.
        paper.setFill()
        context.cgContext.fill(CGRect(origin: .zero, size: pageSize))
        let frame = CGRect(x: 16, y: 16, width: pageSize.width - 32, height: pageSize.height - 32)
        let border = UIBezierPath(roundedRect: frame, cornerRadius: 10)
        hairline.setStroke()
        border.lineWidth = 1
        border.stroke()

        drawFooter()
        cursorY = margin
    }

    private func drawFooter() {
        let periodText = "\(L("reports.title")) · \(formattedRange())"
        draw(periodText, font: roundedFont(size: 8.5, weight: .regular), color: inkSoft,
             at: CGPoint(x: margin, y: pageSize.height - margin + 14))
        let pageText = String(format: L("reports.pdf.page"), pageNumber)
        drawRightAligned(pageText, font: roundedFont(size: 8.5, weight: .regular), color: inkSoft,
                         rightEdge: pageSize.width - margin, y: pageSize.height - margin + 14)
    }

    /// Salta de página si no queda sitio para `height` puntos.
    private func ensureSpace(_ height: CGFloat) {
        if cursorY + height > bottomLimit {
            beginPage()
        }
    }

    // MARK: - Cabecera

    private func drawHeader() {
        draw(L("reports.title"), font: roundedFont(size: 30, weight: .bold), color: forestDeep,
             at: CGPoint(x: margin, y: cursorY))
        cursorY += 42

        var subtitle = formattedRange()
        if let congregation = data.congregationName, !congregation.isEmpty {
            subtitle = "\(congregation) · \(subtitle)"
        }
        draw(subtitle, font: roundedFont(size: 12, weight: .semibold), color: ink,
             at: CGPoint(x: margin, y: cursorY))

        let generated = String(format: L("reports.pdf.generated_on"), formattedDate(Date()))
        drawRightAligned(generated, font: roundedFont(size: 9, weight: .regular), color: inkSoft,
                         rightEdge: pageSize.width - margin, y: cursorY + 3)
        cursorY += 24

        drawDivider()
        cursorY += 18
    }

    // MARK: - Resumen

    private func drawSummary() {
        let stats: [(String, String, UIColor)] = [
            ("\(data.territoriesWorked)", L("reports.pdf.worked"), forest),
            ("\(data.territoriesNotWorked)", L("reports.pdf.not_worked"), terracotta)
        ]

        let gap: CGFloat = 10
        let boxWidth = (contentWidth - gap * CGFloat(stats.count - 1)) / CGFloat(stats.count)
        let boxHeight: CGFloat = 58
        ensureSpace(boxHeight + 20)

        for (index, stat) in stats.enumerated() {
            let x = margin + CGFloat(index) * (boxWidth + gap)
            let box = CGRect(x: x, y: cursorY, width: boxWidth, height: boxHeight)
            let path = UIBezierPath(roundedRect: box, cornerRadius: 10)
            UIColor.white.setFill()
            path.fill()
            hairline.setStroke()
            path.lineWidth = 1
            path.stroke()

            drawCentered(stat.0, font: roundedFont(size: 22, weight: .bold), color: stat.2,
                         centerX: box.midX, y: box.minY + 8)
            drawCentered(stat.1.uppercased(), font: roundedFont(size: 7.5, weight: .semibold),
                         color: inkSoft, centerX: box.midX, y: box.minY + 38, kern: 0.6)
        }
        cursorY += boxHeight + 22
    }

    // MARK: - Grupos por territorio

    private func drawGroup(_ group: TerritoryReportData.TerritoryGroup) {
        ensureSpace(58) // cabecera de grupo + al menos una fila
        drawGroupHeader(group, continued: false)
        drawColumnHeaders()

        for (index, entry) in group.entries.enumerated() {
            if cursorY + 22 > bottomLimit {
                beginPage()
                drawGroupHeader(group, continued: true)
                drawColumnHeaders()
            }
            drawRow(entry, striped: index.isMultiple(of: 2))
        }
        cursorY += 16
    }

    private func drawGroupHeader(_ group: TerritoryReportData.TerritoryGroup, continued: Bool) {
        let badgeFont = roundedFont(size: 10, weight: .bold)
        let badgeText = attributed(group.code, font: badgeFont, color: .white)
        let badgeSize = badgeText.size()
        let badge = CGRect(x: margin, y: cursorY, width: badgeSize.width + 14, height: 20)
        let badgePath = UIBezierPath(roundedRect: badge, cornerRadius: 6)
        forest.setFill()
        badgePath.fill()
        badgeText.draw(at: CGPoint(x: badge.minX + 7, y: badge.minY + (badge.height - badgeSize.height) / 2))

        var name = group.name
        if continued {
            name += " " + L("reports.pdf.continued")
        }
        draw(name, font: roundedFont(size: 12, weight: .bold), color: ink,
             at: CGPoint(x: badge.maxX + 8, y: cursorY + 3))

        let count = group.entries.count == 1
            ? L("reports.pdf.assignments_one")
            : String(format: L("reports.pdf.assignments_count"), group.entries.count)
        drawRightAligned(count, font: roundedFont(size: 9, weight: .regular), color: inkSoft,
                         rightEdge: pageSize.width - margin, y: cursorY + 5)
        cursorY += 28
    }

    private func drawColumnHeaders() {
        let font = roundedFont(size: 7.5, weight: .semibold)
        let y = cursorY
        var x = margin
        draw(L("reports.pdf.person").uppercased(), font: font, color: inkSoft, at: CGPoint(x: x, y: y), kern: 0.5)
        x += colPerson + colGap
        draw(L("reports.pdf.given_date").uppercased(), font: font, color: inkSoft, at: CGPoint(x: x, y: y), kern: 0.5)
        x += colDate + colGap
        draw(L("reports.pdf.picked_date").uppercased(), font: font, color: inkSoft, at: CGPoint(x: x, y: y), kern: 0.5)
        x += colDate + colGap
        draw(L("reports.pdf.days").uppercased(), font: font, color: inkSoft, at: CGPoint(x: x, y: y), kern: 0.5)
        cursorY += 14

        guard let cg = rendererContext?.cgContext else { return }
        cg.setStrokeColor(hairline.cgColor)
        cg.setLineWidth(0.7)
        cg.move(to: CGPoint(x: margin, y: cursorY - 2))
        cg.addLine(to: CGPoint(x: pageSize.width - margin, y: cursorY - 2))
        cg.strokePath()
    }

    private func drawRow(_ entry: TerritoryReportEntry, striped: Bool) {
        let rowHeight: CGFloat = 21

        if striped {
            paperDeep.withAlphaComponent(0.55).setFill()
            UIBezierPath(roundedRect: CGRect(x: margin - 4, y: cursorY - 2, width: contentWidth + 8, height: rowHeight),
                         cornerRadius: 5).fill()
        }

        let textY = cursorY + 3
        var x = margin
        let person = entry.personName ?? "—"
        draw(truncated(person, maxWidth: colPerson, font: roundedFont(size: 9.5, weight: .medium)),
             font: roundedFont(size: 9.5, weight: .medium), color: ink, at: CGPoint(x: x, y: textY))
        x += colPerson + colGap

        draw(entry.givenAt.map(formattedShortDate) ?? "—", font: roundedFont(size: 9, weight: .regular), color: ink,
             at: CGPoint(x: x, y: textY))
        x += colDate + colGap

        let isOpen = entry.pickedAt == nil
        draw(entry.pickedAt.map(formattedShortDate) ?? L("reports.pdf.in_progress"),
             font: roundedFont(size: 9, weight: isOpen ? .semibold : .regular),
             color: isOpen ? amber : ink, at: CGPoint(x: x, y: textY))
        x += colDate + colGap

        draw(durationDays(entry), font: roundedFont(size: 9, weight: .regular), color: inkSoft, at: CGPoint(x: x, y: textY))
        cursorY += rowHeight
    }

    // MARK: - Utilidades de dibujo

    private func drawDivider() {
        guard let cg = rendererContext?.cgContext else { return }
        cg.setStrokeColor(hairline.cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: margin, y: cursorY))
        cg.addLine(to: CGPoint(x: pageSize.width - margin, y: cursorY))
        cg.strokePath()
    }

    private func attributed(_ text: String, font: UIFont, color: UIColor, kern: CGFloat = 0) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: kern
        ])
    }

    @discardableResult
    private func draw(_ text: String, font: UIFont, color: UIColor, at point: CGPoint, kern: CGFloat = 0) -> CGFloat {
        let attributedText = attributed(text, font: font, color: color, kern: kern)
        attributedText.draw(at: point)
        return attributedText.size().width
    }

    private func drawRightAligned(_ text: String, font: UIFont, color: UIColor, rightEdge: CGFloat, y: CGFloat) {
        let attributedText = attributed(text, font: font, color: color)
        attributedText.draw(at: CGPoint(x: rightEdge - attributedText.size().width, y: y))
    }

    private func drawCentered(_ text: String, font: UIFont, color: UIColor, centerX: CGFloat, y: CGFloat, kern: CGFloat = 0) {
        let attributedText = attributed(text, font: font, color: color, kern: kern)
        attributedText.draw(at: CGPoint(x: centerX - attributedText.size().width / 2, y: y))
    }

    /// SF Rounded, la misma tipografía que los tokens de la app (Font+Extensions).
    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    private func truncated(_ text: String, maxWidth: CGFloat, font: UIFont) -> String {
        var result = text
        while result.count > 4,
              attributed(result + "…", font: font, color: ink).size().width > maxWidth {
            result = String(result.dropLast())
        }
        return result == text ? text : result + "…"
    }

    // MARK: - Formato

    private func formattedRange() -> String {
        "\(formattedDate(data.startDate)) – \(formattedDate(data.endDate))"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMyy")
        return formatter.string(from: date)
    }

    private func durationDays(_ entry: TerritoryReportEntry) -> String {
        guard let given = entry.givenAt else { return "—" }
        let end = entry.pickedAt ?? min(Date(), data.endDate)
        let days = max(0, Calendar.current.dateComponents([.day], from: given, to: end).day ?? 0)
        return "\(days)"
    }

    // MARK: - Localización

    private func L(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// El PDF debe salir en el idioma elegido en la app, no en el del sistema.
    private static func localizationBundle() -> Bundle {
        let code: String?
        switch LanguageManager.shared.currentLanguage {
        case .english: code = "en"
        case .spanish: code = "es"
        case .system: code = nil
        }
        guard let code,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
