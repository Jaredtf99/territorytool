import Foundation
import Combine
import SwiftUI

@MainActor
class BrothersViewModel: ObservableObject {
    @Published var brothers: [Person] = []
    @Published var searchText: String = ""
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

    func isExpanded(_ brotherId: Int) -> Bool {
        expandedBrotherIds.contains(brotherId)
    }

    func toggleExpanded(_ brotherId: Int) {
        if expandedBrotherIds.contains(brotherId) {
            expandedBrotherIds.remove(brotherId)
        } else {
            expandedBrotherIds.insert(brotherId)
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
            try await networkManager.request(endpoint: TerritoryEndpoint.addPerson(name: name))
            ToastManager.shared.show("brothers.add_success", style: .success)
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
            try await networkManager.request(endpoint: TerritoryEndpoint.updatePerson(id: person.id, name: newName, enabled: enabled))
            ToastManager.shared.show("brothers.update_success", style: .success)
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
            try await networkManager.request(endpoint: TerritoryEndpoint.deletePerson(name: person.name))
            ToastManager.shared.show("brothers.delete_success", style: .success)
            await fetchBrothers()
        } catch {
            self.errorMessage = error.localizedDescription
            ToastManager.shared.show(error.localizedDescription, style: .error)
            self.isLoading = false
        }
    }
}
