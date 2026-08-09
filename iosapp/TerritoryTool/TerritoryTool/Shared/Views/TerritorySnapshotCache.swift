import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Imagen ya decodificada, lista para dibujar.
///
/// `CGImage` es inmutable y seguro de compartir una vez creada, pero no está marcada
/// `Sendable` en el SDK; la caja lo hace explícito para poder devolverla desde el worker de
/// disco sin salpicar `@preconcurrency` por todas partes.
struct DecodedSnapshot: @unchecked Sendable {
    let cgImage: CGImage
    let scale: CGFloat

    var uiImage: UIImage {
        UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    /// Coste real en memoria, para limitar la caché por bytes y no por unidades.
    var byteCost: Int {
        cgImage.bytesPerRow * cgImage.height
    }
}

/// Caché de snapshots de mapa.
///
/// Antes esta clase entera era `@MainActor`, así que en el hilo principal ocurría, **una vez
/// por cada tarjeta que aparecía al hacer scroll**: `Data(contentsOf:)` + `UIImage(data:)` al
/// leer, y al escribir la codificación HEIC completa (que además redibuja el bitmap entero en
/// un `CGContext` nuevo), la escritura a disco y una poda que enumeraba todo el directorio.
///
/// Ahora se reparte en dos:
/// - Esta clase (`@MainActor`) guarda sólo la caché de memoria, que es donde se consume.
/// - `TerritorySnapshotDiskStore` (actor) hace lectura, decodificación, codificación,
///   escritura y poda fuera de main.
@MainActor
final class TerritorySnapshotCache {
    static let shared = TerritorySnapshotCache()

    /// `NSCache` con límite **por bytes**, no por unidades. El límite anterior eran 80
    /// imágenes: a @3x eso puede pasar de 100 MB. Además `NSCache` se vacía sola ante
    /// presión de memoria.
    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    private let disk = TerritorySnapshotDiskStore()

    /// Trabajos de lectura en vuelo, para que dos tarjetas que piden la misma clave
    /// (por ejemplo el mismo territorio en el drawer y en la lista) no lean dos veces.
    private var inFlightReads: [String: Task<UIImage?, Never>] = [:]

    private init() {}

    func image(for key: String) async -> UIImage? {
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }

        if let existing = inFlightReads[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [disk] in
            guard let decoded = await disk.read(key: key) else { return nil }
            return decoded.uiImage
        }
        inFlightReads[key] = task

        let image = await task.value
        inFlightReads[key] = nil

        if let image {
            store(image, for: key)
        }
        return image
    }

    /// Guarda en memoria de inmediato y delega al worker la codificación y la escritura.
    func insert(_ image: UIImage, for key: String) {
        store(image, for: key)

        guard let cgImage = image.cgImage else { return }
        let snapshot = DecodedSnapshot(cgImage: cgImage, scale: image.scale)
        Task { [disk] in
            await disk.write(snapshot, key: key)
        }
    }

    func diskSizeBytes() async -> Int64 {
        await disk.totalSizeBytes()
    }

    func clear() async {
        memory.removeAllObjects()
        await disk.clear()
    }

    private func store(_ image: UIImage, for key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memory.setObject(image, forKey: key as NSString, cost: cost)
    }
}

/// Lectura, codificación, escritura y poda del caché en disco. Todo fuera del actor
/// principal.
actor TerritorySnapshotDiskStore {
    private let fileManager = FileManager.default
    private let directory: URL
    private let capacityBytes = 50 * 1024 * 1024
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60

    /// La poda enumera el directorio entero, así que no se hace en cada escritura.
    private var writesSinceLastPrune = 0
    private let writesBetweenPrunes = 25
    private var hasPrunedThisLaunch = false

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = caches.appendingPathComponent("TerritorySnapshotCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Devuelve la imagen **ya descomprimida**.
    ///
    /// `UIImage(data:)` difiere parte de la descompresión al primer dibujo, así que devolver
    /// sólo `Data` habría trasladado ese coste de vuelta a main justo al aparecer la tarjeta.
    /// `kCGImageSourceShouldCacheImmediately` fuerza el decode aquí dentro.
    func read(key: String) -> DecodedSnapshot? {
        for url in fileURLs(for: key) {
            guard fileManager.fileExists(atPath: url.path) else { continue }

            if isExpired(url) {
                try? fileManager.removeItem(at: url)
                continue
            }

            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [
                      kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else {
                continue
            }

            // Marca de uso reciente para la poda LRU.
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            return DecodedSnapshot(cgImage: cgImage, scale: UIScreen.main.scale)
        }
        return nil
    }

    func write(_ snapshot: DecodedSnapshot, key: String) {
        guard let encoded = encode(snapshot.cgImage) else { return }

        try? encoded.data.write(to: fileURL(for: key, extension: encoded.fileExtension), options: [.atomic])
        removeAlternativeFormats(for: key, keeping: encoded.fileExtension)

        writesSinceLastPrune += 1
        if !hasPrunedThisLaunch || writesSinceLastPrune >= writesBetweenPrunes {
            hasPrunedThisLaunch = true
            writesSinceLastPrune = 0
            prune()
        }
    }

    func totalSizeBytes() -> Int64 {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return urls.reduce(into: Int64(0)) { total, url in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]) else { return }
            total += Int64(values.fileSize ?? 0)
        }
    }

    func clear() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Codificación

    private func encode(_ cgImage: CGImage) -> (data: Data, fileExtension: String)? {
        // Los snapshots son opacos; quitar el canal alfa mejora la compresión y evita que
        // HEIC rechace formatos de píxel poco habituales.
        let source = opaqueCopy(of: cgImage) ?? cgImage

        if let heic = encode(source, as: UTType.heic.identifier as CFString, quality: 0.38) {
            return (heic, "heic")
        }
        if let jpeg = encode(source, as: UTType.jpeg.identifier as CFString, quality: 0.88) {
            return (jpeg, "jpg")
        }
        if let png = encode(source, as: UTType.png.identifier as CFString, quality: 1) {
            return (png, "png")
        }
        return nil
    }

    private func encode(_ cgImage: CGImage, as type: CFString, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func opaqueCopy(of cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    // MARK: - Ficheros

    private func fileURLs(for key: String) -> [URL] {
        ["heic", "jpg", "png"].map { fileURL(for: key, extension: $0) }
    }

    private func fileURL(for key: String, extension fileExtension: String) -> URL {
        directory
            .appendingPathComponent(Self.digest(key))
            .appendingPathExtension(fileExtension)
    }

    private func removeAlternativeFormats(for key: String, keeping fileExtension: String) {
        for url in fileURLs(for: key) where url.pathExtension != fileExtension {
            try? fileManager.removeItem(at: url)
        }
    }

    private func isExpired(_ url: URL, now: Date = Date()) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else {
            return false
        }
        return now.timeIntervalSince(modified) > maxAge
    }

    private func prune() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var entries: [(url: URL, modified: Date, size: Int)] = []
        var totalSize = 0
        let now = Date()

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                continue
            }
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > maxAge {
                try? fileManager.removeItem(at: url)
                continue
            }
            let size = values.fileSize ?? 0
            totalSize += size
            entries.append((url, modified, size))
        }

        guard totalSize > capacityBytes else { return }

        for entry in entries.sorted(by: { $0.modified < $1.modified }) {
            try? fileManager.removeItem(at: entry.url)
            totalSize -= entry.size
            if totalSize <= capacityBytes { break }
        }
    }

    private static func digest(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
