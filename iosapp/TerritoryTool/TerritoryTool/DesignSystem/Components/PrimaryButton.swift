import SwiftUI

/// CTA primario con Liquid Glass prominente nativo. Ver docs/DESIGN_GUIDE.md §5.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var systemImage: String?
    /// Tinte del CTA. Verde por defecto; usar `.accentTertiary` para acciones de
    /// devolución, `.accentDeep` para entregas, etc.
    var tint: Color = .accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .controlSize(.large)
        .disabled(isDisabled || isLoading)
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        PrimaryButton(title: "common.save") {}
        PrimaryButton(title: "common.save", isLoading: true) {}
        PrimaryButton(title: "common.save", isDisabled: true) {}
    }
    .padding()
}
