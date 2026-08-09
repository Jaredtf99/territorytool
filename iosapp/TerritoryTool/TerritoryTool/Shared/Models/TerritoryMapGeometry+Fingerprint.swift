import Foundation

nonisolated extension TerritoryMapGeometry {
    /// Huella de la geometría para la clave de caché del snapshot.
    ///
    /// Antes esto era `JSONEncoder().encode(self)` + SHA-256 de toda la geometría, y
    /// `snapshotCacheKey` se invoca dentro del `.task(id:)` del `GeometryReader`, es decir
    /// **en cada evaluación de body de cada tarjeta**. Codificar a JSON y hashear miles de
    /// coordenadas por render era el grueso del coste.
    ///
    /// FNV-1a sobre los bit patterns de cada coordenada cumple lo mismo mucho más barato:
    /// - **Cubre todos los vértices**, así que mover uno intermedio cambia la huella. Una
    ///   clave basada sólo en bounds y contadores serviría un snapshot obsoleto para
    ///   siempre; peor aún aquí, porque `version` está fijado a 1 en el backend.
    /// - **Es estable entre lanzamientos**, a diferencia de `Hasher`, que va sembrado por
    ///   proceso: la caché de disco fallaría en cada arranque.
    var snapshotFingerprint: String {
        var hash = Self.fnvOffsetBasis
        hash.combine(version)
        hash.combine(bounds.south)
        hash.combine(bounds.west)
        hash.combine(bounds.north)
        hash.combine(bounds.east)

        for features in [polygons, polylines] {
            hash.combine(features.count)
            for feature in features {
                hash.combine(feature.id)
                hash.combine(feature.coordinates.count)
                for coordinate in feature.coordinates {
                    hash.combine(coordinate.latitude)
                    hash.combine(coordinate.longitude)
                }
            }
        }

        hash.combine(markers.count)
        for marker in markers {
            hash.combine(marker.id)
            hash.combine(marker.latitude)
            hash.combine(marker.longitude)
        }

        return String(hash, radix: 16)
    }

    static var fnvOffsetBasis: UInt64 { 0xcbf2_9ce4_8422_2325 }
}

private extension UInt64 {
    static var fnvPrime: UInt64 { 0x0000_0100_0000_01b3 }

    mutating func combine(_ byte: UInt8) {
        self = (self ^ UInt64(byte)) &* Self.fnvPrime
    }

    mutating func combine(_ value: UInt64) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            for byte in bytes { combine(byte) }
        }
    }

    /// Los `Double` entran por su representación binaria: exacta y sin formateo.
    mutating func combine(_ value: Double) {
        combine(value.bitPattern)
    }

    mutating func combine(_ value: Int) {
        combine(UInt64(bitPattern: Int64(value)))
    }

    mutating func combine(_ value: String) {
        for byte in value.utf8 { combine(byte) }
        // Separador: evita que ("ab","c") y ("a","bc") produzcan la misma huella.
        combine(UInt8(0))
    }
}
