import Combine
import Foundation
import SwiftUI

enum TerritoryFilter: String, CaseIterable, Identifiable {
    case all = "territories.filter.all"
    case free = "territories.filter.free"
    case inUse = "territories.filter.in_use"
    case attention = "territories.filter.attention"

    var id: String { rawValue }
    var localizedName: String { NSLocalizedString(rawValue, comment: "") }

    var backendValue: String {
        switch self {
        case .all: "all"
        case .free: "available"
        case .inUse: "assigned"
        case .attention: "attention"
        }
    }
}

enum TerritorySortOption: Int, CaseIterable, Identifiable {
    case relevance = 0
    case name = 1
    case code = 2
    case givenDate = 3
    case nearest = 4

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .relevance: NSLocalizedString("territories.sort.relevance", comment: "")
        case .name: NSLocalizedString("territories.sort.name", comment: "")
        case .code: NSLocalizedString("territories.sort.code", comment: "")
        case .givenDate: NSLocalizedString("territories.sort.given_date", comment: "")
        case .nearest: NSLocalizedString("territories.sort.nearest", comment: "")
        }
    }
}

enum TerritoryDrawerDetent: CaseIterable {
    case collapsed
    case medium
}

@MainActor
final class TerritoriesViewModel: ObservableObject {
    @Published private(set) var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var filterStatus: TerritoryFilter = .all
    @Published var sortOption: TerritorySortOption = .relevance
    @Published var sortAscending = true
    @Published var attentionDays = 120
    @Published var presentation: TerritoriesPresentation
    @Published var selectedTerritoryID: Int?
    @Published var drawerDetent: TerritoryDrawerDetent = .medium

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    init(apiService: APIService) {
        self.apiService = apiService
        let stored = UserDefaults.standard.string(forKey: "territories.presentation")
        presentation = stored == "list" ? .list : .map

        Publishers.CombineLatest($searchText, $filterStatus)
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates { lhs, rhs in lhs.0 == rhs.0 && lhs.1 == rhs.1 }
            .dropFirst()
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .territoryDeleted)
            .merge(with: NotificationCenter.default.publisher(for: .territoryDataChanged))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .congregationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.territories = []
                self?.selectedTerritoryID = nil
                self?.reload()
            }
            .store(in: &cancellables)
    }

    var selectedTerritory: Territory? {
        territories.first { $0.id == selectedTerritoryID }
    }

    var attentionTerritories: [Territory] {
        sorted(filteredTerritories.filter {
            if case .attention = $0.operationalStatus(attentionDays: attentionDays) { return true }
            return false
        })
    }

    var availableTerritories: [Territory] {
        sorted(filteredTerritories.filter {
            if case .available = $0.operationalStatus(attentionDays: attentionDays) { return true }
            return false
        })
    }

    var assignedTerritories: [Territory] {
        sorted(filteredTerritories.filter {
            if case .assigned = $0.operationalStatus(attentionDays: attentionDays) { return true }
            return false
        })
    }

    private var filteredTerritories: [Territory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCodeQuery(query) else { return territories }
        return territories.filter {
            normalized($0.code).contains(normalized(query))
        }
    }

    var sortedTerritories: [Territory] { sorted(filteredTerritories) }
    var displayedTerritories: [Territory] { sortedTerritories }
    var territoriesWithGeometry: [Territory] { sortedTerritories.filter { $0.mapGeometry != nil } }
    var territoriesWithoutGeometry: [Territory] { sortedTerritories.filter { $0.mapGeometry == nil } }

    func setPresentation(_ value: TerritoriesPresentation, persist: Bool = true) {
        presentation = value
        if persist {
            UserDefaults.standard.set(value == .map ? "map" : "list", forKey: "territories.presentation")
        }
    }

    func select(_ territory: Territory?) {
        selectedTerritoryID = territory?.id
        if territory != nil { drawerDetent = .medium }
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.loadTerritories() }
    }

    func loadTerritories() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let result: [Territory] = try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritoryExplorer(
                    term: term.isEmpty ? nil : term,
                    filter: filterStatus,
                    attentionDays: attentionDays
                )
            )
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                territories = result
                if let selectedTerritoryID, !result.contains(where: { $0.id == selectedTerritoryID }) {
                    self.selectedTerritoryID = nil
                }
            }
        } catch {
            guard !Task.isCancelled, !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func applyLaunchContext(_ context: TerritoriesLaunchContext) {
        attentionDays = context.attentionDays
        filterStatus = context.filter
        setPresentation(context.presentation, persist: false)
        sortOption = context.filter == .attention ? .givenDate : .relevance
        sortAscending = context.filter == .attention
        selectedTerritoryID = nil
    }

    func deleteTerritory(_ territory: Territory) async {
        errorMessage = nil
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.deleteTerritory(id: territory.id))
            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sorted(_ values: [Territory]) -> [Territory] {
        values.sorted { lhs, rhs in
            sortAscending ? comesBefore(lhs, rhs) : comesBefore(rhs, lhs)
        }
    }

    private func isCodeQuery(_ query: String) -> Bool {
        guard !query.isEmpty, !query.contains(where: \.isWhitespace) else { return false }
        return query.contains(where: \.isLetter) && query.contains(where: \.isNumber)
    }

    private func normalized(_ value: String) -> String {
        String(
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .filter { $0.isLetter || $0.isNumber }
        )
    }

    private func comesBefore(_ lhs: Territory, _ rhs: Territory) -> Bool {
        switch sortOption {
        case .relevance:
            let leftRank = relevanceRank(lhs)
            let rightRank = relevanceRank(rhs)
            if leftRank != rightRank { return leftRank < rightRank }
            let leftDate = relevanceDate(lhs)
            let rightDate = relevanceDate(rhs)
            return leftDate == rightDate ? lhs.id < rhs.id : leftDate < rightDate
        case .name:
            let comparison = lhs.name.localizedStandardCompare(rhs.name)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        case .code:
            let comparison = lhs.code.localizedStandardCompare(rhs.code)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        case .givenDate:
            let leftDate = lhs.givenDateUtc ?? .distantFuture
            let rightDate = rhs.givenDateUtc ?? .distantFuture
            return leftDate == rightDate ? lhs.id < rhs.id : leftDate < rightDate
        case .nearest:
            // Location-aware ordering is applied by the view once distances are available.
            let leftRank = relevanceRank(lhs)
            let rightRank = relevanceRank(rhs)
            return leftRank == rightRank ? lhs.id < rhs.id : leftRank < rightRank
        }
    }

    private func relevanceRank(_ territory: Territory) -> Int {
        switch territory.operationalStatus(attentionDays: attentionDays) {
        case .attention: 0
        case .available: 1
        case .assigned: 2
        }
    }

    private func relevanceDate(_ territory: Territory) -> Date {
        territory.givenDateUtc ?? territory.lastPickedDateUtc ?? .distantPast
    }
}
