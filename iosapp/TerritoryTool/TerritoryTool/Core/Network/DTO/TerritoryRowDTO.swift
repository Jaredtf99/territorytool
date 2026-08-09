import Foundation

/// Fila cruda de `territory_current_state` tal y como la devuelven PostgREST y las RPC que
/// se apoyan en esa vista (`search_territory_explorer`).
///
/// Se decodifica **dentro del actor de transporte**, así que tiene que ser `Sendable`.
/// Sustituye al viaje `JSON → [String: Any] → Data → Decodable` que hacía el camino
/// heredado, que además ocurría entero en el hilo principal.
///
/// Claves explícitas y sin `.convertFromSnakeCase`: la vista devuelve snake_case, pero
/// `map_geometry` es un jsonb cuyo contenido ya viene en camelCase con la forma exacta de
/// `TerritoryMapGeometry` (lo escribe así la edge function `refresh-territory-image`), así
/// que una estrategia global de conversión rompería el anidado.
nonisolated struct TerritoryRowDTO: Decodable, Sendable {
    let id: Int
    let code: String
    let name: String
    let mapUrl: String?
    let imagePath: String?
    let personName: String?
    let givenAt: Date?
    let lastPickedAt: Date?
    let mapGeometry: TerritoryMapGeometry?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case mapUrl = "map_url"
        case imagePath = "image_path"
        case personName = "person_name"
        case givenAt = "given_at"
        case lastPickedAt = "last_picked_at"
        case mapGeometry = "map_geometry"
    }

    /// `imgUrl` se rellena aparte: sólo se firma para los territorios sin geometría, que
    /// son los únicos donde la UI llega a mirarlo.
    func territory(imageURL: String?) -> Territory {
        Territory(
            id: id,
            code: code,
            name: name,
            mapUrl: mapUrl ?? "",
            imgUrl: imageURL,
            personName: personName,
            givenDateUtc: givenAt,
            lastPickedDateUtc: lastPickedAt,
            mapGeometry: mapGeometry
        )
    }
}
