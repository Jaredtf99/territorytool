import SwiftUI

struct StatusBadge: View {
    let isAssigned: Bool

    var body: some View {
        Text(isAssigned ? "territory.status.assigned" : "territory.status.available")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(isAssigned ? Color.warning : Color.success, in: .capsule)
            .foregroundStyle(.white)
            .accessibilityLabel(Text(isAssigned ? "territory.status.assigned" : "territory.status.available"))
    }
}
