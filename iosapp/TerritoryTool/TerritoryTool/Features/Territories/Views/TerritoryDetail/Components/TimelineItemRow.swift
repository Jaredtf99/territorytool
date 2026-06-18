import SwiftUI

struct TimelineItemRow: View {
    let transaction: Transaction
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line and dot
            VStack(spacing: 0) {
                Circle()
                    .fill(transaction.pickedDateUtc == nil ? Color.accent : Color.accentSecondary)
                    .frame(width: 12, height: 12)
                    .background(
                        Circle()
                            .stroke(Color.hairline, lineWidth: 4)
                    )

                Rectangle()
                    .fill(Color.hairline)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.personName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(formatDate(transaction.givenDateUtc))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if onEdit != nil || onDelete != nil {
                        Menu {
                            if let onEdit = onEdit {
                                Button(action: onEdit) {
                                    Label("common.edit", systemImage: "pencil")
                                }
                            }
                            
                            if let onDelete = onDelete {
                                Button(role: .destructive, action: onDelete) {
                                    Label("common.delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20)) // Larger touch target
                                .foregroundColor(.secondary)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                    }
                }
                
                if let pickedDate = transaction.pickedDateUtc {
                    Text("\(String(localized: "territory.history.returned")) \(formatDate(pickedDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("territory.history.currently_assigned")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accent)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 3)
                        .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: AppRadius.sm))
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
