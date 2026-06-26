import Combine
import Foundation
import SwiftUI

/// ViewModel de la pantalla principal de Acción rápida (centro de escaneo).
/// Responsable del buscador universal, la resolución de escaneos y las sugerencias.
/// La selección/confirmación de entregar/recoger vive en las vistas empujadas
/// (`QuickActionPickPersonView`, `QuickActionPersonView`, `QuickActionConfirmView`).
@MainActor
final class QuickActionViewModel: ObservableObject {
    // Buscador universal: lista única (territorios + personas) rankeada por el backend.
    @Published var searchTerm = ""
    @Published var searchHits: [QuickSearchHit] = []
    @Published var isSearching = false

    // Sugerencias (estado ocioso, sin búsqueda)
    @Published var attentionTerritories: [Territory] = []
    @Published var oldestFreeTerritories: [Territory] = []
    @Published var isLoadingSuggestions = false

    // Escaneo
    @Published var isResolvingScan = false

    @Published var errorMessage: String?

    private let apiService: APIService
    private let attentionDays = 90
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService) {
        self.apiService = apiService

        $searchTerm
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            // Marca "buscando" de inmediato (antes del debounce) para que no aparezca
            // el mensaje de "sin resultados" en el hueco mientras se espera a teclear.
            .handleEvents(receiveOutput: { [weak self] term in
                guard let self else { return }
                if term.isEmpty {
                    // Con el buscador enfocado y vacío se navegan todos los territorios.
                    if self.isBrowsing {
                        self.isSearching = true
                    } else {
                        self.searchHits = []
                        self.isSearching = false
                    }
                } else {
                    self.isSearching = true
                }
            })
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] term in
                Task { [weak self] in await self?.search(term: term) }
            }
            .store(in: &cancellables)
    }

    var hasSearch: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAnyResults: Bool {
        !searchHits.isEmpty
    }

    // MARK: - Buscador universal

    /// Activo cuando el buscador está enfocado: con texto vacío se navegan todos los
    /// territorios (en vez de no mostrar nada).
    private var isBrowsing = false

    /// Lo llama el hub al enfocar/desenfocar el buscador.
    func setBrowsing(_ focused: Bool) async {
        isBrowsing = focused
        await search(term: searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func search(term: String) async {
        guard !term.isEmpty else {
            if isBrowsing {
                await loadBrowse()
            } else {
                searchHits = []
            }
            isSearching = false
            return
        }
        isSearching = true
        do {
            let hits: [QuickSearchHit] = try await apiService.request(
                endpoint: TerritoryEndpoint.searchQuickAction(term: term)
            )
            searchHits = hits
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
            searchHits = []
        }
        isSearching = false
    }

    /// Todos los territorios ordenados por código (navegación con buscador vacío).
    private func loadBrowse() async {
        let all = await fetchTerritories(term: nil, inUse: nil)
        searchHits = all
            .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
            .map { QuickSearchHit(kind: .territory, territory: $0) }
    }

    // MARK: - Sugerencias

    func loadSuggestions() async {
        isLoadingSuggestions = true
        async let assigned = fetchTerritories(term: nil, inUse: true)
        async let free = fetchTerritories(term: nil, inUse: false)
        let (assignedList, freeList) = await (assigned, free)

        // Atención: solo los que superan el umbral (90 días), el más antiguo primero.
        // Si ninguno lo supera, la sección no aparece.
        attentionTerritories = assignedList
            .filter { ($0.daysAssigned() ?? 0) >= attentionDays }
            .sorted { ($0.givenDateUtc ?? .distantFuture) < ($1.givenDateUtc ?? .distantFuture) }
            .prefix(3)
            .map { $0 }

        // Disponibles desde hace tiempo: nil (nunca cogidos) primero, luego más antiguos.
        oldestFreeTerritories = freeList
            .sorted { lhs, rhs in
                guard let l = lhs.lastPickedDateUtc else { return true }
                guard let r = rhs.lastPickedDateUtc else { return false }
                return l < r
            }
            .prefix(3)
            .map { $0 }

        isLoadingSuggestions = false
    }

    // MARK: - Escaneo

    func resolve(scannedValue: String) async -> Territory? {
        isResolvingScan = true
        defer { isResolvingScan = false }
        do {
            let territory: Territory = try await apiService.request(
                endpoint: TerritoryEndpoint.resolveTerritorySelector(value: scannedValue)
            )
            return territory
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
            return nil
        }
    }

    // MARK: - Carga de datos

    private func fetchTerritories(term: String?, inUse: Bool?) async -> [Territory] {
        do {
            return try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritories(
                    term: term,
                    inUse: inUse,
                    orderBy: TerritorySortOption.name.rawValue,
                    orderByAscending: true,
                    lastGivenDateFrom: nil,
                    lastGivenDateTo: nil
                )
            )
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
            return []
        }
    }

}
