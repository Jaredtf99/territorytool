import SwiftUI

struct GlassTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var label: LocalizedStringKey? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .glassCardStyle(cornerRadius: 12, padding: 16)
                .submitLabel(submitLabel)
                .onSubmit {
                    onSubmit?()
                }
        }
    }
}

