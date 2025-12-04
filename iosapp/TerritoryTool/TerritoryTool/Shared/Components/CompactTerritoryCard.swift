import SwiftUI

struct CompactTerritoryCard: View {
    let territory: Territory
    
    var body: some View {
        HStack(spacing: 8) {
            Text(territory.code)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
            
            Text(territory.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(20) // Capsule-like
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
