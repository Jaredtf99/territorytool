import SwiftUI

struct GlassToggle: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(label, isOn: $isOn)
            .tint(.brandPrimary)
            .glassCardStyle(cornerRadius: 12, padding: 16)
    }
}

