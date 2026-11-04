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
    /// La sombra va en la forma del fondo, no tras `overlay`: aplicada al final se
    /// propagaría a cada subvista (un blur por texto/icono) y hunde los FPS en listas.
    func paperCard(cornerRadius: CGFloat = AppRadius.lg, fill: Color = .surface) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    // Sombra más contenida (antes radio 14 / y 8): el coste del blur
                    // crece con el radio y hay una por tarjeta visible.
                    .shadow(color: Color.glassShadow, radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
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
                // Sin glow de color bajo la cápsula (blur extra en cada render).
                Capsule(style: .continuous)
                    .fill(Color.accent.opacity(isEnabled ? 1 : 0.4))
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.12 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7),
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

// MARK: - Fundido sin máscara

/// Degradado que "funde" un contenido hacia un color de fondo **sólido**.
///
/// Es el equivalente visual de `.mask(LinearGradient(alpha…))` cuando lo que hay detrás
/// es una superficie opaca (p. ej. el papel de una tarjeta): en vez de enmascarar
/// (pase offscreen por vista y por frame durante el scroll) se pinta encima el color de
/// la superficie con la opacidad inversa. Resultado idéntico, sin offscreen.
struct SurfaceFade: View {
    /// Pares (opacidad del contenido visible, posición) tal y como se pasarían a la máscara.
    let stops: [(opacity: Double, location: CGFloat)]
    var base: Color = .surface
    var startPoint: UnitPoint = .leading
    var endPoint: UnitPoint = .trailing

    var body: some View {
        LinearGradient(
            stops: stops.map { .init(color: base.opacity(1 - $0.opacity), location: $0.location) },
            startPoint: startPoint,
            endPoint: endPoint
        )
        .allowsHitTesting(false)
    }
}
