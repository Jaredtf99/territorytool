import SwiftUI

/// Toggle con Liquid Glass nativo y tinte de acento. Ver docs/DESIGN_GUIDE.md §5.
struct GlassToggle: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .tint(.accent)
            .padding(AppSpacing.md)
            .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.md))
    }
}
