import SwiftUI

struct TimelineItemRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line and dot
            VStack(spacing: 0) {
                Circle()
                    .fill(transaction.pickedDateUtc == nil ? Color.green : Color.blue)
                    .frame(width: 12, height: 12)
                    .background(
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                    )
                
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(transaction.personName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(transaction.givenDateUtc))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let pickedDate = transaction.pickedDateUtc {
                    Text("\(String(localized: "territory.history.returned")) \(formatDate(pickedDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("territory.history.currently_assigned")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
