import SwiftUI

// RecentTransactionsView struct removed as logic is inlined in DashboardView to support List swipe actions.

struct TransactionRow: View {
    let event: TransactionEvent
    
    var body: some View {
        HStack(spacing: 16) {

            // Icon
            ZStack {
                Circle()
                    .fill(event.type == .returned ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: event.type == .returned ? "arrow.uturn.left" : "arrow.right")
                    .foregroundColor(event.type == .returned ? .green : .blue)
                    .font(.system(size: 14, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Territory Name
                Text(event.transaction.territoryName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                
                // Person Name
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text(event.transaction.personName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Date
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.date.formatted(.dateTime.day().month()))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                Text(event.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
        .glassCardStyle(cornerRadius: 16, padding: 12)
    }
}
