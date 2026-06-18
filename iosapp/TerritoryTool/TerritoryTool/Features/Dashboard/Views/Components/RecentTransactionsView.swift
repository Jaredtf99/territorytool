import SwiftUI

// RecentTransactionsView struct removed as logic is inlined in DashboardView to support List swipe actions.

/// Fila de "movimiento" (entrega o devolución de un territorio) — tema cartográfico.
struct TransactionRow: View {
    let event: TransactionEvent

    private var isReturn: Bool { event.type == .returned }
    private var tint: Color { isReturn ? .accent : .accentSecondary }
    private var icon: String { isReturn ? "arrow.down.left" : "arrow.up.right" }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Icono direccional
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: Circle())
                .overlay(Circle().strokeBorder(tint.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.transaction.territoryName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text(event.transaction.personName)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: AppSpacing.xs)

            VStack(alignment: .trailing, spacing: 3) {
                Text(isReturn ? "dashboard.returned" : "dashboard.given")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                Text(event.date.formatted(.dateTime.day().month()))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .glassCardStyle(cornerRadius: AppRadius.lg, padding: AppSpacing.sm)
    }
}
