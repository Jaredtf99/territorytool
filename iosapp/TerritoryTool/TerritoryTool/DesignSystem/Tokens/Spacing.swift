import CoreGraphics

/// Escala de espaciado base 8pt. Única fuente de verdad para paddings y separaciones.
/// Ver `docs/DESIGN_GUIDE.md` §4.
enum AppSpacing {
    /// 4
    static let xxs: CGFloat = 4
    /// 8
    static let xs: CGFloat = 8
    /// 12
    static let sm: CGFloat = 12
    /// 16 — padding interno por defecto de tarjetas/filas y márgenes de pantalla
    static let md: CGFloat = 16
    /// 24 — separación entre secciones
    static let lg: CGFloat = 24
    /// 32
    static let xl: CGFloat = 32
}
