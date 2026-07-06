import SwiftUI

/// Avatar de iniciales unificado de la app: círculo relleno con degradado del tinte e
/// iniciales en blanco (mismo estilo que el icono de estado / `StatTile`).
struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 40
    var tint: Color = .accent

    private var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                // Sombra en el círculo, no en la vista compuesta: si va después
                // del background también sombrea las iniciales (un blur extra por fila).
                Circle()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.78)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: tint.opacity(0.35), radius: 5, x: 0, y: 2)
            )
            .accessibilityHidden(true)
    }
}
