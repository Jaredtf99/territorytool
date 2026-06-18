import SwiftUI

// MARK: - Tarjetas y botones del tema "Cartográfico cálido".
// Las tarjetas son de papel sólido (superficie cálida + borde fino + sombra suave),
// no cristal translúcido: encajan mejor con el fondo topográfico.
// Se conservan los nombres previos (GlassCard, glassCardStyle, GlassButton) para
// que los puntos de uso existentes adopten el nuevo estilo automáticamente.

/// Tarjeta de papel cálido. Padding `md` y radio `lg` (20pt) por defecto.
struct GlassCard<Content: View>: View {
    private let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(cornerRadius: CGFloat = AppRadius.lg,
         padding: CGFloat = AppSpacing.md,
         @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .paperCard(cornerRadius: cornerRadius)
    }
}

/// Alias semántico.
typealias AppCard = GlassCard

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.lg
    var padding: CGFloat = AppSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .paperCard(cornerRadius: cornerRadius)
    }
}

extension View {
    /// Aplica el estilo de tarjeta (papel cálido) con padding interno.
    func glassCardStyle(cornerRadius: CGFloat = AppRadius.lg, padding: CGFloat = AppSpacing.md) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Solo el fondo de papel (sin padding): superficie + borde fino + sombra cálida.
    func paperCard(cornerRadius: CGFloat = AppRadius.lg, fill: Color = .surface) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
            .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
    }
}

/// Botón de ancho completo, verde sólido con microinteracción de pulsación.
struct GlassButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appBody())
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }
}

/// Estilo de botón principal: cápsula verde, texto blanco, escala al pulsar.
struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accent.opacity(isEnabled ? 1 : 0.4))
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.12 : 0))
            )
            .shadow(color: Color.accent.opacity(isEnabled ? 0.30 : 0), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .interactiveSpring(), value: configuration.isPressed)
    }
}

/// Fondo de pantalla cartográfico (atajo).
struct GlassBackground: View {
    var body: some View {
        LiquidBackgroundView()
    }
}
