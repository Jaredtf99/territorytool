import Foundation

/// Decoder para las respuestas de Supabase.
///
/// Vive aparte para poder verificarlo contra fixtures sin arrastrar el transporte, la
/// sesión ni la configuración.
///
/// **Sin `.convertFromSnakeCase` a propósito.** Las respuestas están mezcladas: las vistas
/// REST devuelven snake_case (`given_at`, `map_geometry`), pero varias RPC construyen el
/// JSON en camelCase (`get_dashboard_snapshot` emite `territoryId`, `givenAt`…). Además esa
/// estrategia transforma la clave recibida *antes* de emparejarla, así que chocaría con los
/// `CodingKeys` explícitos y rompería el jsonb anidado de `map_geometry`, que ya viene en
/// camelCase. Cada DTO declara sus propias claves.
nonisolated enum SupabaseJSONDecoder {
    static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        // `.iso8601` basta: se verificó que acepta las cinco variantes que emite PostgREST
        // —`Z` y offset explícito, con y sin fracciones de segundo—. Ojo con la confusión
        // fácil: un `ISO8601DateFormatter` con `.withInternetDateTime` suelto SÍ falla con
        // fracciones, pero la estrategia del decoder es más permisiva que él.
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
