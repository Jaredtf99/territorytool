import SwiftUI

/// Marca de entrega virtual para líneas de información (lista, detalle, trayectoria).
///
/// Va en línea con el texto que la acompaña ("Desde hace 34 días · Virtual"), con la
/// misma tipografía y sin cápsula: así se lee como un dato más y no se confunde con
/// los chips de filtro. Usa el color de la familia "formato de entrega", distinto de
/// los colores de estado. Físico es el formato por defecto y no se marca.
struct DeliveryFormatBadge: View {
    let format: DeliveryFormat
    /// Antepone un "·" para encadenarla tras otro dato de la misma línea.
    var leadingSeparator = false

    var body: some View {
        if format == .virtual {
            HStack(spacing: AppSpacing.xxs) {
                if leadingSeparator {
                    Text(verbatim: "·")
                        .foregroundStyle(Color.textSecondary)
                }
                HStack(spacing: 3) {
                    Image(systemName: format.systemImage)
                        .imageScale(.small)
                        .fontWeight(.bold)
                    Text(format.title)
                }
                .foregroundStyle(format.tint)
            }
            .font(.appCaption().weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("delivery_format.delivered_virtually"))
        }
    }
}
