import SwiftUI

/// Fondo "cartográfico cálido": papel con líneas de contorno topográfico tenues
/// y una veladura cálida. Estático (respeta Reduce Motion) y barato de dibujar.
struct LiquidBackgroundView: View {
    var body: some View {
        ZStack {
            // Base de papel
            Color.appBackground

            // Viñeta cálida hacia los bordes
            RadialGradient(
                colors: [.clear, Color.appBackgroundDeep.opacity(0.7)],
                center: .center,
                startRadius: 160,
                endRadius: 620
            )

            // Halo de acento suave arriba a la derecha
            RadialGradient(
                colors: [Color.accent.opacity(0.10), .clear],
                center: UnitPoint(x: 0.92, y: 0.06),
                startRadius: 0,
                endRadius: 360
            )

            // Curvas de nivel (dos "elevaciones")
            ContourField()
                .stroke(Color.cartoLine.opacity(0.14), lineWidth: 1)
        }
        .ignoresSafeArea()
    }
}

/// Conjunto de curvas de nivel concéntricas alrededor de varios centros,
/// como un mapa topográfico.
private struct ContourField: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let peaks: [(center: CGPoint, rings: Int, base: CGFloat, gap: CGFloat, phase: CGFloat)] = [
            (CGPoint(x: rect.width * 0.86, y: rect.height * 0.10), 9, 30, 34, 0.0),
            (CGPoint(x: rect.width * 0.08, y: rect.height * 0.74), 8, 26, 38, 1.7),
            (CGPoint(x: rect.width * 0.62, y: rect.height * 0.96), 6, 40, 42, 3.1)
        ]
        for peak in peaks {
            for i in 1...peak.rings {
                let radius = peak.base + CGFloat(i) * peak.gap
                path.addPath(contour(center: peak.center,
                                      radius: radius,
                                      wobble: 6 + CGFloat(i) * 1.4,
                                      phase: peak.phase + CGFloat(i) * 0.35))
            }
        }
        return path
    }

    /// Círculo perturbado con senos para dar el aspecto orgánico de una curva de nivel.
    private func contour(center: CGPoint, radius: CGFloat, wobble: CGFloat, phase: CGFloat) -> Path {
        var path = Path()
        let steps = 72
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps) * .pi * 2
            let r = radius
                + sin(t * 3 + phase) * wobble
                + cos(t * 5 + phase * 1.3) * wobble * 0.45
            let point = CGPoint(x: center.x + cos(t) * r,
                                y: center.y + sin(t) * r)
            if s == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    LiquidBackgroundView()
}
