import SwiftUI

/// Interruptor "No sugerir para entregar": el territorio deja de aparecer en las
/// sugerencias de territorios libres (asignar y acción rápida).
/// No pinta fondo: cada pantalla lo envuelve con su propia tarjeta.
struct ExcludeFromSuggestionsToggle: View {
    @Binding var isExcluded: Bool

    var body: some View {
        Toggle(isOn: Binding(
            get: { isExcluded },
            set: { newValue in
                guard newValue != isExcluded else { return }
                withAnimation(.snappy) { isExcluded = newValue }
                HapticManager.shared.selection()
            }
        )) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: isExcluded ? "lightbulb.slash.fill" : "lightbulb.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.accentDeep)
                    .frame(width: 40, height: 40)
                    .background(Color.accent.opacity(0.12), in: Circle())
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text("territory.exclude_from_suggestions.title")
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                    Text("territory.exclude_from_suggestions.hint")
                        .font(.appCaption())
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Color.accent)
    }
}
