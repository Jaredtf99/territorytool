import SwiftUI

struct StatusBadge: View {
    let isAssigned: Bool
    
    var body: some View {
        Text(isAssigned ? "territory.status.assigned" : "territory.status.available")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isAssigned ? Color.orange : Color.green)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: (isAssigned ? Color.orange : Color.green).opacity(0.3), radius: 4, x: 0, y: 2)
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}
