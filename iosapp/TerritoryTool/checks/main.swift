import Foundation

// Verificación del contrato de decodificación del explorador.
// Compila los archivos de producción reales (Territory.swift, Transaction.swift,
// TerritoryRowDTO.swift, SupabaseJSONDecoder.swift) — no copias.

var failures = 0

func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition {
        print("  ok   \(name)")
    } else {
        failures += 1
        print("  FAIL \(name) \(detail())")
    }
}

let decoder = SupabaseJSONDecoder.make()

// MARK: - Fila completa, con geometría, tal y como la emite territory_current_state
// (snake_case) con el jsonb map_geometry en camelCase (lo escribe refresh-territory-image).

let fullRow = """
[{
  "id": 42,
  "code": "AV012",
  "name": "Barrio del Río",
  "map_url": "https://maps.example/x",
  "image_path": "congregation-1/av012.png",
  "archived": false,
  "active_transaction_id": 900,
  "person_id": 7,
  "person_name": "Andrés Morales",
  "given_at": "2026-06-18T23:00:00+00:00",
  "last_picked_at": "2026-05-01T10:30:00.123456+00:00",
  "congregation_id": "c-1",
  "map_geometry": {
    "version": 1,
    "bounds": { "south": 40.4153, "west": -3.7081, "north": 40.4231, "east": -3.6982 },
    "polygons": [{
      "id": "poly-1",
      "name": "Barrio del Río",
      "coordinates": [
        { "latitude": 40.4231, "longitude": -3.7056 },
        { "latitude": 40.4228, "longitude": -3.7021 },
        { "latitude": 40.4215, "longitude": -3.6995 }
      ]
    }],
    "polylines": [],
    "markers": [{ "id": "m-1", "title": "Entrada", "latitude": 40.42, "longitude": -3.70 }]
  }
}]
""".data(using: .utf8)!

print("\nFila completa con geometría:")
do {
    let rows = try decoder.decode([TerritoryRowDTO].self, from: fullRow)
    check("decodifica 1 fila", rows.count == 1)
    let row = rows[0]
    check("id", row.id == 42)
    check("code", row.code == "AV012")
    check("map_url -> mapUrl", row.mapUrl == "https://maps.example/x")
    check("image_path -> imagePath", row.imagePath == "congregation-1/av012.png")
    check("person_name -> personName", row.personName == "Andrés Morales")
    check("given_at sin fracciones", row.givenAt != nil, "\(String(describing: row.givenAt))")
    check("last_picked_at CON fracciones", row.lastPickedAt != nil, "")
    check("map_geometry anidado", row.mapGeometry != nil)
    check("polígono con 3 coordenadas", row.mapGeometry?.polygons.first?.coordinates.count == 3)
    check("bounds", row.mapGeometry?.bounds.north == 40.4231)
    check("marcador opcional 'description' ausente", row.mapGeometry?.markers.first?.description == nil)

    let territory = row.territory(imageURL: "https://signed/x")
    check("mapea a Territory", territory.id == 42 && territory.imgUrl == "https://signed/x")
    check("Territory conserva geometría", territory.mapGeometry?.polygons.count == 1)
} catch {
    failures += 1
    print("  FAIL excepción: \(error)")
}

// MARK: - Territorio libre, sin geometría, con nulls por todas partes

let sparseRow = """
[{
  "id": 7,
  "code": "AV001",
  "name": "Centro",
  "map_url": null,
  "image_path": null,
  "person_name": null,
  "given_at": null,
  "last_picked_at": null,
  "map_geometry": null
}]
""".data(using: .utf8)!

print("\nFila con nulls y sin geometría:")
do {
    let rows = try decoder.decode([TerritoryRowDTO].self, from: sparseRow)
    let row = rows[0]
    check("decodifica con nulls", row.id == 7)
    check("mapUrl nulo", row.mapUrl == nil)
    check("mapGeometry nulo", row.mapGeometry == nil)
    check("mapUrl nulo -> \"\" en Territory", row.territory(imageURL: nil).mapUrl == "")
    check("imgUrl nulo", row.territory(imageURL: nil).imgUrl == nil)
} catch {
    failures += 1
    print("  FAIL excepción: \(error)")
}

// MARK: - Claves ausentes por completo (PostgREST omite columnas no seleccionadas)

let minimalRow = """
[{ "id": 3, "code": "AV003", "name": "Norte" }]
""".data(using: .utf8)!

print("\nFila mínima (claves ausentes):")
do {
    let rows = try decoder.decode([TerritoryRowDTO].self, from: minimalRow)
    check("decodifica fila mínima", rows[0].id == 3 && rows[0].personName == nil)
} catch {
    failures += 1
    print("  FAIL excepción: \(error)")
}

// MARK: - Variantes de fecha

print("\nVariantes de fecha:")
for (label, value) in [
    ("Z sin fracciones", "2026-06-18T23:00:00Z"),
    ("Z con fracciones", "2026-06-18T23:00:00.123Z"),
    ("offset sin fracciones", "2026-06-18T23:00:00+00:00"),
    ("offset con fracciones", "2026-06-18T23:00:00.123456+02:00")
] {
    let json = "[{\"id\":1,\"code\":\"A\",\"name\":\"N\",\"given_at\":\"\(value)\"}]".data(using: .utf8)!
    do {
        let rows = try decoder.decode([TerritoryRowDTO].self, from: json)
        check(label, rows[0].givenAt != nil, value)
    } catch {
        failures += 1
        print("  FAIL \(label) (\(value)): \(error)")
    }
}


// MARK: - Huella de geometría (clave de caché de snapshots)
//
// El punto crítico: una clave basada sólo en bounds/contadores serviría un snapshot
// obsoleto para siempre al mover un vértice intermedio.

func geometry(_ coords: [(Double, Double)], version: Int = 1, markerLat: Double = 40.42) -> TerritoryMapGeometry {
    TerritoryMapGeometry(
        version: version,
        bounds: TerritoryMapBounds(south: 40.41, west: -3.71, north: 40.43, east: -3.69),
        polygons: [TerritoryMapFeature(
            id: "poly-1", name: "P", description: nil,
            coordinates: coords.map { TerritoryMapCoordinate(latitude: $0.0, longitude: $0.1) }
        )],
        polylines: [],
        markers: [TerritoryMapMarker(id: "m-1", title: "T", description: nil, latitude: markerLat, longitude: -3.70)]
    )
}

let base = [(40.4231, -3.7056), (40.4228, -3.7021), (40.4215, -3.6995), (40.4194, -3.6982)]

print("\nHuella de geometría:")
let baseline = geometry(base).snapshotFingerprint
check("determinista", geometry(base).snapshotFingerprint == baseline)

// Vértice INTERMEDIO movido: mismos bounds, mismo número de puntos, mismo primero y último.
var moved = base
moved[1] = (40.4229, -3.7020)
check("mover un vértice intermedio cambia la huella", geometry(moved).snapshotFingerprint != baseline)

// Dos coordenadas intercambiadas: mismo conjunto, distinto orden.
var swapped = base
swapped.swapAt(1, 2)
check("reordenar vértices cambia la huella", geometry(swapped).snapshotFingerprint != baseline)

check("quitar un vértice cambia la huella", geometry(Array(base.dropLast())).snapshotFingerprint != baseline)
check("mover un marcador cambia la huella", geometry(base, markerLat: 40.4201).snapshotFingerprint != baseline)
check("cambiar version cambia la huella", geometry(base, version: 2).snapshotFingerprint != baseline)
check("no vacía", !baseline.isEmpty, baseline)
if ProcessInfo.processInfo.environment["PRINT_FINGERPRINT"] != nil { print("FINGERPRINT=\(baseline)") }

print("\nPolylabel (heap nuevo vs. escaneo original):")
runPolylabelGolden { name, ok, detail in check(name, ok, detail) }

print("\n\(failures == 0 ? "TODO OK" : "\(failures) FALLOS")")
exit(failures == 0 ? 0 : 1)
