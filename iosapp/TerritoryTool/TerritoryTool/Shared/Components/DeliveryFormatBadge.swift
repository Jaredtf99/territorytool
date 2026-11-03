import SwiftUI

/// Indicador compacto del formato de entrega (físico/virtual).
struct DeliveryFormatBadge: View {
    let format: DeliveryFormat
    var showsTitle = true

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: format.systemImage)
            if showsTitle {
                Text(format.title)
            }
        }
        .font(.appCaption().weight(.medium))
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.textSecondary.opacity(0.12), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(format.title))
    }
}
