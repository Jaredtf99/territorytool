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
    
    init(apiService: APIService) {
        self.apiService = apiService
        
        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadTerritories()
                }
            }
            .store(in: &cancellables)
            
        // Reload when filter or sort changes
        Publishers.CombineLatest3($filterStatus, $sortOption, $sortAscending)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadTerritories()
                }
            }
            .store(in: &cancellables)
        // Reload when territory is deleted
        NotificationCenter.default.publisher(for: .territoryDeleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadTerritories()
                }
            }
            .store(in: &cancellables)
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
            
            let result: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: term,
                inUse: inUse,
                orderBy: sortOption.rawValue,
                orderByAscending: sortAscending,
                lastGivenDateFrom: nil,
                lastGivenDateTo: nil
            ))
            
            withAnimation {
                self.territories = result
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func deleteTerritory(_ territory: Territory) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.deleteTerritory(id: territory.id))
            // Refresh list
            await loadTerritories()
            // Notify other parts of the app if needed, though loadTerritories updates the list
            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
        } catch {
            self.errorMessage = "Error deleting territory: \(error.localizedDescription)"
            isLoading = false
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
