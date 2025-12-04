import SwiftUI

struct PersonBadge: View {
    let personName: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
                .font(.caption2)
            Text(personName)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue)
        .clipShape(Capsule())
        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
