import SwiftUI

/// Estado unificado de carga / vacío / error con reintento.
/// Evita repetir la lógica `if isLoading … else if error …` en cada pantalla.
/// Ver docs/DESIGN_GUIDE.md §5 y CONTRIBUTING_UI.md.
struct LoadingErrorStateView<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool
    var emptyText: LocalizedStringKey = "common.empty"
    var emptyIcon: String = "tray"
    var retry: (() async -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isLoading {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityLabel(Text("common.loading"))
        } else if let error = error {
            ContentUnavailableView {
                Label("common.error", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(error)
            } actions: {
                if let retry = retry {
                    Button {
                        Task { await retry() }
                    } label: {
                        Text("common.retry")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accent)
                }
            }
        } else if isEmpty {
            ContentUnavailableView {
                Label(emptyText, systemImage: emptyIcon)
            }
        } else {
            content()
        }
    }
}
