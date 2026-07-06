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

@MainActor
class BrothersViewModel: ObservableObject {
    @Published var brothers: [Person] = []
    @Published var searchText: String = ""
    @Published var filter: BrotherFilter = .all
    @Published var sortOption: BrotherSortOption = .name
    @Published var sortAscending: Bool = true
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var showAddSheet: Bool = false
    @Published var showEditSheet: Bool = false
    @Published var selectedBrother: Person?
    @Published var expandedBrotherIds: Set<Int> = []

    /// Lista filtrada derivada de `brothers` + `searchText`. Al ser una propiedad
    /// computada sobre @Published, SwiftUI la reevalúa sola sin estado duplicado.
    var filteredBrothers: [Person] {
        guard !searchText.isEmpty else { return brothers }
        return brothers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: Lista visible (filtro + búsqueda + orden, sin agrupar)

    /// Lista plana que pinta la pantalla: chip de filtro y búsqueda aplicados,
    /// ordenada por `sortOption`/`sortAscending` con todos los estados mezclados.
    var displayBrothers: [Person] {
        let base: [Person]
        switch filter {
        case .all: base = filteredBrothers
        case .available: base = filteredBrothers.filter { $0.enabled && !$0.hasActiveTerritory }
        case .withTerritories: base = filteredBrothers.filter { $0.enabled && $0.hasActiveTerritory }
        case .inactive: base = filteredBrothers.filter { !$0.enabled }
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
        return sortAscending ? sorted : sorted.reversed()
    }

    /// Contador del chip de cada filtro (refleja la búsqueda activa).
    func count(for filter: BrotherFilter) -> Int {
        switch filter {
        case .all: filteredBrothers.count
        case .available: filteredBrothers.filter { $0.enabled && !$0.hasActiveTerritory }.count
        case .withTerritories: filteredBrothers.filter { $0.enabled && $0.hasActiveTerritory }.count
        case .inactive: filteredBrothers.filter { !$0.enabled }.count
        }
    }

    // MARK: Resumen global (independiente de búsqueda y filtro)

    var summaryHolderCount: Int {
        brothers.filter { $0.enabled && $0.hasActiveTerritory }.count
    }

    var enabledCount: Int {
        brothers.filter(\.enabled).count
    }

    /// Días de cada asignación activa, de más antigua a más reciente.
    /// Alimenta el número y la rejilla de puntos del resumen.
    var summaryAssignmentDays: [Int] {
        brothers.filter(\.enabled)
            .flatMap { $0.territoriesInUse ?? [] }
            .map { $0.daysHeld() }
            .sorted(by: >)
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
