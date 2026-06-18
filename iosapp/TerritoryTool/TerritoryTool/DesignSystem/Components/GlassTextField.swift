import SwiftUI

/// Campo de texto con Liquid Glass nativo y label opcional. Ver docs/DESIGN_GUIDE.md §5.
struct GlassTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var label: LocalizedStringKey? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let label = label {
                Text(label)
                    .font(.appCaption())
                    .foregroundStyle(.secondary)
                    .padding(.leading, AppSpacing.xxs)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(AppSpacing.md)
                .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.md))
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
        }
    }
}
