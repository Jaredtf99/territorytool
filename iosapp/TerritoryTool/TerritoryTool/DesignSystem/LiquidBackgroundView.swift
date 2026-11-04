import SwiftUI
import UIKit

/// Fondo "cartográfico cálido": papel con líneas de contorno topográfico tenues
/// y una veladura cálida. Estático (respeta Reduce Motion).
///
/// Rendimiento: el fondo aparece en casi todas las pantallas. Antes cada instancia
/// re-trazaba ~1.700 segmentos + dos degradados radiales a pantalla completa (también
/// en cada push de navegación, donde conviven dos). Ahora se rasteriza **una vez** por
/// tamaño y esquema de color y todas las pantallas comparten el mismo bitmap.
struct LiquidBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            if let image = LiquidBackgroundRaster.image(
                size: proxy.size,
                colorScheme: colorScheme,
                scale: displayScale
            ) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                LiquidBackgroundLayers()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Caché compartida del fondo rasterizado.
@MainActor
private enum LiquidBackgroundRaster {
    private struct Key: Hashable {
        let width: Int
        let height: Int
        let dark: Bool
        let scale: Int
    }

    private static var cache: [Key: UIImage] = [:]
    private static var order: [Key] = []
    private static let capacity = 4

    static func image(size: CGSize, colorScheme: ColorScheme, scale: CGFloat) -> UIImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let key = Key(
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            dark: colorScheme == .dark,
            scale: Int((scale * 10).rounded())
        )
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(
            content: LiquidBackgroundLayers()
                .frame(width: CGFloat(key.width), height: CGFloat(key.height))
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = scale
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return nil }

        cache[key] = image
        order.append(key)
        if order.count > capacity {
            cache[order.removeFirst()] = nil
        }
        return image
    }
}

/// Capas vectoriales del fondo (fuente del raster).
private struct LiquidBackgroundLayers: View {
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
