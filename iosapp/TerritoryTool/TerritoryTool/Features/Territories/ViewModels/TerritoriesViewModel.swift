import Foundation
import SwiftUI
import Combine

enum TerritoryFilter: String, CaseIterable, Identifiable {
    case all = "territories.filter.all"
    case free = "territories.filter.free"
    case inUse = "territories.filter.in_use"
    
    var id: String { rawValue }
    
    var localizedName: String {
        NSLocalizedString(rawValue, comment: "")
    }
}

@MainActor
class TerritoriesViewModel: ObservableObject {
    @Published var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var filterStatus: TerritoryFilter = .all
    
    @Published var sortOption: TerritorySortOption = .name
    @Published var sortAscending = true
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var didAttemptGeometrySync = false
    /// Carga en curso; se cancela antes de lanzar otra para evitar respuestas
    /// solapadas donde "gana la última en terminar" en vez de la última pedida.
    private var loadTask: Task<Void, Never>?

    init(apiService: APIService) {
        self.apiService = apiService

        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)

        // Reload when filter or sort changes
        Publishers.CombineLatest3($filterStatus, $sortOption, $sortAscending)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
        // Reload when a territory is deleted elsewhere (e.g. detail screen)
        NotificationCenter.default.publisher(for: .territoryDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
        // Reload when the active congregation changes (multi-tenant).
        NotificationCenter.default.publisher(for: .congregationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.territories = []
                self?.didAttemptGeometrySync = false
                self?.reload()
            }
            .store(in: &cancellables)
    }

    /// Lanza una recarga cancelando la anterior si seguía en vuelo.
    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.loadTerritories()
        }
    }

    func loadTerritories() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let term = searchText.isEmpty ? nil : searchText
            let inUse: Bool? = {
                switch filterStatus {
                case .all: return nil
                case .free: return false
                case .inUse: return true
                }
            }()
            
            var result: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: term,
                inUse: inUse,
                orderBy: sortOption.rawValue,
                orderByAscending: sortAscending,
                lastGivenDateFrom: nil,
                lastGivenDateTo: nil
            ))

            if !didAttemptGeometrySync && result.contains(where: { $0.mapGeometry == nil }) {
                didAttemptGeometrySync = true
                do {
                    try await apiService.request(endpoint: TerritoryEndpoint.syncAllTerritoryMaps)
                    result = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                        term: term,
                        inUse: inUse,
                        orderBy: sortOption.rawValue,
                        orderByAscending: sortAscending,
                        lastGivenDateFrom: nil,
                        lastGivenDateTo: nil
                    ))
                } catch {
                    // Keep displaying the legacy images if synchronization is
                    // temporarily unavailable.
                    print("Unable to synchronize territory maps: \(error)")
                }
            }

            // Si la tarea fue cancelada (llegó otra recarga), descartamos este
            // resultado para no pisar el más reciente.
            guard !Task.isCancelled else { return }

            withAnimation {
                self.territories = result
            }
        } catch {
            guard !Task.isCancelled, !error.isCancellation else { return }
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteTerritory(_ territory: Territory) async {
        errorMessage = nil

        do {
            try await apiService.request(endpoint: TerritoryEndpoint.deleteTerritory(id: territory.id))
            // La recarga la dispara el observer de .territoryDeleted (una sola vez).
            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
        } catch {
            self.errorMessage = "Error deleting territory: \(error.localizedDescription)"
        }
    }
}

enum TerritorySortOption: Int, CaseIterable, Identifiable {
    case name = 1
    case code = 2
    case givenDate = 3
    
    var id: Int { rawValue }
    
    var localizedName: String {
        switch self {
        case .name: return NSLocalizedString("territories.sort.name", comment: "")
        case .code: return NSLocalizedString("territories.sort.code", comment: "")
        case .givenDate: return NSLocalizedString("territories.sort.given_date", comment: "")
        }
    }
}
