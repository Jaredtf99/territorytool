import SwiftUI

/// Interruptor "Entregado en virtual". Apagado = físico (el formato por defecto).
/// No pinta fondo: cada pantalla lo envuelve con su propia tarjeta.
struct VirtualDeliveryToggle: View {
    @Binding var format: DeliveryFormat
    /// Se llama solo cuando el usuario cambia el interruptor.
    var onChange: ((DeliveryFormat) -> Void)? = nil

    private var isVirtual: Bool { format == .virtual }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isVirtual },
            set: { newValue in
                let newFormat: DeliveryFormat = newValue ? .virtual : .physical
                guard newFormat != format else { return }
                withAnimation(.snappy) { format = newFormat }
                HapticManager.shared.selection()
                onChange?(newFormat)
            }
        )) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: format.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isVirtual ? DeliveryFormat.familyTint : Color.textSecondary)
                    .frame(width: 40, height: 40)
                    .background((isVirtual ? DeliveryFormat.familyTint : Color.textSecondary).opacity(0.12), in: Circle())
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text("delivery_format.toggle.title")
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                    Text(isVirtual ? "delivery_format.toggle.virtual_hint" : "delivery_format.toggle.physical_hint")
                        .font(.appCaption())
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(DeliveryFormat.familyTint)
    }
}
