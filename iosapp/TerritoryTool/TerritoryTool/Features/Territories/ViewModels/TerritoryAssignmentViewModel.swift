import Foundation
import Combine
import SwiftUI

@MainActor
class TerritoryAssignmentViewModel: ObservableObject {
    @Published var availableTerritories: [Territory] = []
    @Published var persons: [Person] = []
    @Published var suggestedTerritories: [Territory] = []
    
    @Published var selectedTerritory: Territory?
    @Published var selectedPerson: Person?
    @Published var useCustomDate: Bool = false
    @Published var customDate: Date = Date()
    
    @Published var isLoadingTerritories = false
    @Published var isLoadingPersons = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    
    @Published var territorySearchText = ""
    @Published var personSearchText = ""
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService) {
        self.apiService = apiService
        
        // Debounce territory search
        $territorySearchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadTerritories()
                }
            }
            .store(in: &cancellables)
            
        // Debounce person search
        $personSearchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadPersons()
                }
            }
            .store(in: &cancellables)
            
        // Initial load
        Task {
            await loadTerritories()
            await loadSuggestions()
            await loadPersons()
        }
    }
    
    func loadTerritories() async {
        isLoadingTerritories = true
        errorMessage = nil
        
        do {
            let term = territorySearchText.isEmpty ? nil : territorySearchText
            let result: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: term,
                inUse: false, // Only free territories
                orderBy: TerritorySortOption.name.rawValue,
                orderByAscending: true,
                lastGivenDateFrom: nil,
                lastGivenDateTo: nil
            ))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.availableTerritories = result
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoadingTerritories = false
    }
    
    func loadPersons() async {
        isLoadingPersons = true
        
        do {
            let term = personSearchText.isEmpty ? nil : personSearchText
            let result: [Person] = try await apiService.request(endpoint: TerritoryEndpoint.getPersons(search: term))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.persons = result
            }
        } catch {
            print("Error loading persons: \(error)")
        }
        
        isLoadingPersons = false
    }
    
    func loadSuggestions() async {
        // Suggestions are oldest free territories
        // We fetch all free territories and sort by lastPickedDateUtc ascending (oldest returned first)
        
        do {
            let result: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: nil,
                inUse: false,
                orderBy: nil,
                orderByAscending: nil,
                lastGivenDateFrom: nil,
                lastGivenDateTo: nil
            ))
            
            // Sort client side: nil dates (never picked) come first or last? 
            // Usually we want those that have been returned longest ago.
            // If lastPickedDateUtc is nil, it might mean it was never returned (new?).
            // Let's assume we want oldest dates first.
            let sorted = result.sorted { t1, t2 in
                guard let d1 = t1.lastPickedDateUtc else { return true } // Treat nil as very old
                guard let d2 = t2.lastPickedDateUtc else { return false }
                return d1 < d2
            }
            
            self.suggestedTerritories = Array(sorted.prefix(3))
        } catch {
            print("Error loading suggestions: \(error)")
        }
    }
    
    func assignTerritory() async -> Bool {
        guard let territory = selectedTerritory, let person = selectedPerson else {
            errorMessage = NSLocalizedString("assignment.error.missing_fields", value: "Please select a territory and a publisher", comment: "")
            return false
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            let date = useCustomDate ? customDate : nil
            try await apiService.request(endpoint: TerritoryEndpoint.giveTerritory(
                code: territory.code,
                personName: person.name,
                date: date
            ))
            
            ToastManager.shared.show(
                NSLocalizedString("assignment.success", comment: ""),
                style: .success
            )
            NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
            
            // Reset form
            selectedTerritory = nil
            selectedPerson = nil
            useCustomDate = false
            customDate = Date()
            territorySearchText = ""
            personSearchText = ""
            
            // Reload data
            await loadTerritories()
            await loadSuggestions()
            
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
    
    func selectSuggestion(_ territory: Territory) {
        selectedTerritory = territory
    }
    
    func selectTerritory(by mapUrl: String) {
        let sanitizedScannedUrl = mapUrl.replacingOccurrences(of: "&usp=sharing", with: "")
        
        if let territory = availableTerritories.first(where: { 
            $0.mapUrl.replacingOccurrences(of: "&usp=sharing", with: "") == sanitizedScannedUrl 
        }) {
            selectedTerritory = territory
        } else {
            ToastManager.shared.show(
                String.localized("assignment.error.territory_not_found"),
                style: .error
            )
        }
    }
}
