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
                    Label(active.name, systemImage: "building.2.fill")
                        .font(.subheadline)
                }
                .disabled(store.isSwitching)
            } else {
                Label(active.name, systemImage: "building.2.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
