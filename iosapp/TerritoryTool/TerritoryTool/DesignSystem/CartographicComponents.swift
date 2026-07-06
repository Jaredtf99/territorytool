import SwiftUI

// MARK: - Piezas reutilizables del tema "Cartográfico cálido".
// Cabeceras de sección, stat-tiles, números con cuenta animada, estados vacíos
// y modificadores de entrada escalonada. Todo respeta Reduce Motion.

// MARK: Número con cuenta ascendente

/// Texto numérico que "rueda" de 0 al valor al aparecer.
struct CountUpText: View {
    let value: Int
    var font: Font = .system(size: 32, design: .rounded).weight(.heavy)
    var color: Color = .textPrimary

    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(shown)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                guard !reduceMotion else { shown = value; return }
                withAnimation(.easeOut(duration: 0.8)) { shown = value }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.5)) { shown = newValue }
            }
    }
}

// MARK: Entrada escalonada

private struct AppearTransition: ViewModifier {
    let delay: Double
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .onAppear {
                guard !reduceMotion else { visible = true; return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    /// Fundido + desplazamiento de entrada. `index` escalona el retardo.
    func appear(index: Int = 0, base: Double = 0.04) -> some View {
        modifier(AppearTransition(delay: Double(index) * base))
    }
}

// MARK: Cabecera de sección

/// Cabecera de sección cartográfica: icono + título + línea de ruta punteada + contador.
struct CartoSectionHeader: View {
    let title: LocalizedStringKey
    var systemImage: String
    var count: Int? = nil
    var tint: Color = .accent

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            // Línea de ruta punteada
            Line()
                .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            if let count {
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.14), in: Capsule())
            }
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: Stat tile

/// Tarjeta de estadística del "diario de expedición": icono + número animado + etiqueta.
struct StatTile: View {
    let value: Int
    let label: LocalizedStringKey
    let systemImage: String
    var tint: Color = .accent

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(colors: [tint, tint.opacity(0.75)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 3)

            CountUpText(value: value, font: .system(size: 32, design: .rounded).weight(.heavy))
                .padding(.top, 2)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}

// MARK: Estado vacío

/// Estado vacío amable con icono en círculo y mensaje.
struct CartoEmptyState: View {
    let systemImage: String
    let message: LocalizedStringKey
    var tint: Color = .accent

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: Circle())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}

// MARK: Rampa de urgencia por antigüedad

extension Color {
    /// Color según los días que un territorio lleva asignado (verde → ámbar → terracota).
    static func urgency(forDays days: Int) -> Color {
        switch days {
        case ..<150:  return .accentSecondary   // ámbar
        case 150..<240: return .warning
        default:      return .accentTertiary     // terracota
        }
    }
}
