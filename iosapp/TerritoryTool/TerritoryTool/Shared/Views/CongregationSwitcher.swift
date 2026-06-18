import SwiftUI

/// Toolbar control to view/switch the active congregation.
/// Shows a menu when the user belongs to more than one congregation.
struct CongregationSwitcher: View {
    @ObservedObject private var store = CongregationStore.shared

    var body: some View {
        if let active = store.active {
            if store.hasMultiple {
                Menu {
                    ForEach(store.congregations) { congregation in
                        Button {
                            switchTo(congregation.id)
                        } label: {
                            if congregation.isActive {
                                Label(congregation.name, systemImage: "checkmark")
                            } else {
                                Text(congregation.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.north.fill")
                        Text(active.name)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.medium))
                }
                .disabled(store.isSwitching)
            } else {
                // Una sola congregación: informativo, no interactivo y sin chevron.
                // .fixedSize evita que la toolbar trunque el nombre a "...".
                HStack(spacing: 4) {
                    Image(systemName: "location.north.fill")
                    Text(active.name)
                }
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .fixedSize()
            }
        }
    }

    private func switchTo(_ id: String) {
        Task {
            let ok = await store.switchTo(id)
            if ok {
                ToastManager.shared.show("congregation.switched", style: .success)
            } else {
                ToastManager.shared.show("congregation.switch_failed", style: .error)
            }
        }
    }
}
