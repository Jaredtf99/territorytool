import Foundation
import Combine
import SwiftUI

/// Filtro operativo de la lista de hermanos. Los grupos son excluyentes:
/// disponible = activo sin territorios, con territorios = activo con ≥1.
enum BrotherFilter: String, CaseIterable, Identifiable {
    case all
    case available
    case withTerritories
    case inactive

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "brothers.filter.all"
        case .available: "brothers.filter.available"
        case .withTerritories: "brothers.filter.with_territories"
        case .inactive: "brothers.filter.inactive"
        }
    }
}

/// Criterio de orden del grupo "Con territorios" (los demás van por nombre).
enum BrotherSortOption: String, CaseIterable, Identifiable {
    case name
    case territories
    case seniority

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .name: "brothers.sort.name"
        case .territories: "brothers.sort.territories"
        case .seniority: "brothers.sort.days"
        }
    }
}

/// Derivados de `brothers`, materializados juntos.
///
/// Antes eran propiedades computadas sobre `@Published`: `filteredBrothers`,
/// `displayBrothers`, `count(for:)` (una por cada uno de los cuatro chips) y
/// `summaryAssignmentDays` sumaban ~9 pasadas completas sobre el array **en cada evaluación
/// de body**, y escribir en el buscador las repetía por pulsación.
struct BrothersDerivedState {
    var display: [Person] = []
    var filterCounts: [BrotherFilter: Int] = [:]
    var holderCount = 0
    var enabledCount = 0
    var assignmentDays: [Int] = []
    /// Clave de animación: comparar contra `[Person]` obliga a recorrer el array entero.
    var revision = 0
}

@MainActor
class BrothersViewModel: ObservableObject {
    @Published var brothers: [Person] = [] { didSet { recompute() } }
    @Published var searchText: String = "" { didSet { recompute() } }
    @Published var filter: BrotherFilter = .all { didSet { recompute() } }
    @Published var sortOption: BrotherSortOption = .name { didSet { recompute() } }
    @Published var sortAscending: Bool = true { didSet { recompute() } }
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var showAddSheet: Bool = false
    @Published var showEditSheet: Bool = false
    @Published var selectedBrother: Person?
    @Published var expandedBrotherIds: Set<Int> = []

    /// Todo lo derivado en una sola propiedad publicada.
    @Published private(set) var derived = BrothersDerivedState()

    // Accesores: las vistas siguen leyendo lo mismo, pero ya no recalculan por render.
    var filteredBrothers: [Person] { searchFiltered() }
    var displayBrothers: [Person] { derived.display }
    var summaryHolderCount: Int { derived.holderCount }
    var enabledCount: Int { derived.enabledCount }
    var summaryAssignmentDays: [Int] { derived.assignmentDays }
    var revision: Int { derived.revision }

    /// Contador del chip de cada filtro (refleja la búsqueda activa).
    func count(for filter: BrotherFilter) -> Int {
        derived.filterCounts[filter] ?? 0
    }

    private func searchFiltered() -> [Person] {
        guard !searchText.isEmpty else { return brothers }
        return brothers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Recalcula lista visible, contadores y resumen en una sola pasada.
    private func recompute() {
        let searched = searchFiltered()

        let available = searched.filter { $0.enabled && !$0.hasActiveTerritory }
        let withTerritories = searched.filter { $0.enabled && $0.hasActiveTerritory }
        let inactive = searched.filter { !$0.enabled }

        let base: [Person]
        switch filter {
        case .all: base = searched
        case .available: base = available
        case .withTerritories: base = withTerritories
        case .inactive: base = inactive
        }

        let sorted: [Person]
        switch sortOption {
        case .name:
            sorted = base // `brothers` ya viene ordenada por nombre
        case .territories:
            sorted = base.sorted { $0.activeTerritoryCount < $1.activeTerritoryCount }
        case .seniority:
            sorted = base.sorted { ($0.maxDaysHeld ?? -1) < ($1.maxDaysHeld ?? -1) }
        }

        let enabled = brothers.filter(\.enabled)

        derived = BrothersDerivedState(
            display: sortAscending ? sorted : sorted.reversed(),
            filterCounts: [
                .all: searched.count,
                .available: available.count,
                .withTerritories: withTerritories.count,
                .inactive: inactive.count
            ],
            // El resumen es global: no depende de búsqueda ni de filtro.
            holderCount: enabled.filter(\.hasActiveTerritory).count,
            enabledCount: enabled.count,
            assignmentDays: enabled
                .flatMap { $0.territoriesInUse ?? [] }
                .map { $0.daysHeld() }
                .sorted(by: >),
            revision: derived.revision &+ 1
        )
    }

    func isExpanded(_ brotherId: Int) -> Bool {
        expandedBrotherIds.contains(brotherId)
    }

    func toggleExpanded(_ brotherId: Int) {
        if expandedBrotherIds.contains(brotherId) {
            expandedBrotherIds.remove(brotherId)
        } else {
            expandedBrotherIds.insert(brotherId)
            loadTerritoryPreviewsIfNeeded()
        }
    }

    // MARK: Previews de territorio para el panel expandido

    /// Previews de mapa por id de territorio. Se cargan perezosamente (primer
    /// despliegue) con una sola petición al explorador; si falla, los thumbnails
    /// muestran el placeholder y no se interrumpe nada.
    @Published private(set) var territoryGeometries: [Int: TerritoryMapGeometry] = [:]
    @Published private(set) var territoryImageURLs: [Int: String] = [:]
    private var previewsTask: Task<Void, Never>?

    func loadTerritoryPreviewsIfNeeded() {
        guard territoryGeometries.isEmpty, territoryImageURLs.isEmpty, previewsTask == nil else { return }
        previewsTask = Task { [weak self] in
            defer { self?.previewsTask = nil }
            guard let self else { return }
            do {
                let result: [Territory] = try await self.networkManager.request(
                    endpoint: TerritoryEndpoint.getTerritoryExplorer(term: nil, filter: .all, attentionDays: 90)
                )
                var geometries: [Int: TerritoryMapGeometry] = [:]
                var imageURLs: [Int: String] = [:]
                for territory in result {
                    if let geometry = territory.mapGeometry {
                        geometries[territory.id] = geometry
                    }
                    if let imgUrl = territory.imgUrl {
                        imageURLs[territory.id] = imgUrl
                    }
                }
                self.territoryGeometries = geometries
                self.territoryImageURLs = imageURLs
            } catch {
                // Silencioso a propósito: el preview es un extra visual.
            }
        }
    }

    private let networkManager: APIService
    private var cancellables = Set<AnyCancellable>()

    init(networkManager: APIService = NetworkManager.shared) {
        self.networkManager = networkManager

        // Reload when the active congregation changes (multi-tenant).
        NotificationCenter.default.publisher(for: .congregationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.brothers = []
                self?.territoryGeometries = [:]
                self?.territoryImageURLs = [:]
                Task { [weak self] in await self?.fetchBrothers() }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .territoryDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.fetchBrothers() }
            }
            .store(in: &cancellables)
    }

    func fetchBrothers() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched: [Person] = try await networkManager.request(endpoint: TerritoryEndpoint.getPersonsWithAssignments(search: nil))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.brothers = fetched.sorted { $0.name < $1.name }
            }
        } catch {
            if !error.isCancellation {
                self.errorMessage = error.localizedDescription
            }
        }
        self.isLoading = false
    }

    func addBrother(name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let undoResponse: UndoableMutationResponse = try await networkManager.request(endpoint: TerritoryEndpoint.addPersonUndoable(name: name))
            let undoHandle = undoResponse.handle(kind: .domain)
            ToastManager.shared.show(
                "brothers.add_success",
                style: .success,
                undoHandle: undoHandle,
                duration: undoHandle.toastDuration
            )
            await fetchBrothers()
            return true
        } catch {
            var message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("ALREADY_EXISTS") {
                message = NSLocalizedString("brothers.error.exists", comment: "")
            }
            self.errorMessage = message
            ToastManager.shared.show(message, style: .error)
            self.isLoading = false
            return false
        }
    }
    
    func updateBrother(person: Person, newName: String, enabled: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let undoResponse: UndoableMutationResponse = try await networkManager.request(endpoint: TerritoryEndpoint.updatePersonUndoable(id: person.id, name: newName, enabled: enabled))
            let undoHandle = undoResponse.handle(kind: .domain)
            ToastManager.shared.show(
                "brothers.update_success",
                style: .success,
                undoHandle: undoHandle,
                duration: undoHandle.toastDuration
            )
            await fetchBrothers()
            return true
        } catch {
            var message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("already exists") || message.localizedCaseInsensitiveContains("ya existe") {
                message = NSLocalizedString("brothers.error.exists", comment: "")
            } else if message.localizedCaseInsensitiveContains("not found") || message.localizedCaseInsensitiveContains("no encontrada") {
                message = NSLocalizedString("brothers.error.not_found", comment: "")
            }
            self.errorMessage = message
            ToastManager.shared.show(message, style: .error)
            self.isLoading = false
            return false
        }
    }
    
    func deleteBrother(person: Person) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let undoResponse: UndoableMutationResponse = try await networkManager.request(endpoint: TerritoryEndpoint.deletePersonUndoable(name: person.name))
            let undoHandle = undoResponse.handle(kind: .domain)
            ToastManager.shared.show(
                "brothers.delete_success",
                style: .success,
                undoHandle: undoHandle,
                duration: undoHandle.toastDuration
            )
            await fetchBrothers()
        } catch {
            self.errorMessage = error.localizedDescription
            ToastManager.shared.show(error.localizedDescription, style: .error)
            self.isLoading = false
        }
    }
}
