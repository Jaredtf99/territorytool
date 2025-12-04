import Foundation
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
    private var currentTask: Task<Void, Never>?
    private var hasInitiallyLoaded = false
    
    init(apiService: APIService) {
        self.apiService = apiService
        
        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .dropFirst() // Drop initial empty value
            .sink { [weak self] _ in
                guard let self = self, self.hasInitiallyLoaded else { return }
                self.triggerLoad()
            }
            .store(in: &cancellables)
            
        // Reload when filter or sort changes
        Publishers.CombineLatest3($filterStatus, $sortOption, $sortAscending)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.hasInitiallyLoaded else { return }
                self.triggerLoad()
            }
            .store(in: &cancellables)
    }
    
    private func triggerLoad() {
        currentTask?.cancel()
        currentTask = Task {
            await loadTerritories()
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
            
            let result: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: term,
                inUse: inUse,
                orderBy: sortOption.rawValue,
                orderByAscending: sortAscending,
                lastGivenDateFrom: nil,
                lastGivenDateTo: nil
            ))
            
            self.territories = result
            self.hasInitiallyLoaded = true
        } catch is CancellationError {
            // Silently ignore cancellation errors
        } catch let error as URLError where error.code == .cancelled {
            // Silently ignore URLSession cancellation errors
        } catch {
            self.errorMessage = error.localizedDescription
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
