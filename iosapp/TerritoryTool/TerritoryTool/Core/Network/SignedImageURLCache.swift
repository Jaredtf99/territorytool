import Combine
import Foundation

/// Caché en memoria de las URLs firmadas de Supabase Storage.
///
/// Sin ella, cada recarga del explorador (cambiar de filtro, tirar para refrescar, teclear
/// en el buscador) vuelve a firmar las mismas rutas. Las firmas viven 3600 s, así que
/// reutilizarlas durante ~50 min es seguro y elimina la mayoría de las peticiones.
///
/// Se vacía al cambiar de sesión o de congregación: una URL firmada con el token anterior
/// no debe sobrevivir a un cambio de contexto.
@MainActor
final class SignedImageURLCache {
    static let shared = SignedImageURLCache()

    private struct Entry {
        let url: String
        let expiresAt: Date
    }

    /// Margen sobre la vida real de la firma (3600 s), para no entregar una URL que
    /// caduque mientras la imagen se está descargando.
    private let lifetime: TimeInterval = 50 * 60

    private var entries: [String: Entry] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: .authChanged)
            .merge(with: NotificationCenter.default.publisher(for: .congregationChanged))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.removeAll() }
            .store(in: &cancellables)
    }

    func url(forPath path: String, bucket: String, now: Date = Date()) -> String? {
        guard let entry = entries[Self.key(bucket: bucket, path: path)] else { return nil }
        guard entry.expiresAt > now else {
            entries.removeValue(forKey: Self.key(bucket: bucket, path: path))
            return nil
        }
        return entry.url
    }

    func store(_ url: String, forPath path: String, bucket: String, now: Date = Date()) {
        entries[Self.key(bucket: bucket, path: path)] = Entry(
            url: url,
            expiresAt: now.addingTimeInterval(lifetime)
        )
    }

    func removeAll() {
        entries.removeAll()
    }

    private static func key(bucket: String, path: String) -> String {
        "\(bucket)/\(path)"
    }
}
