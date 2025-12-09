import Foundation
import Combine

@MainActor
class BrothersViewModel: ObservableObject {
    @Published var brothers: [Person] = []
    @Published var filteredBrothers: [Person] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showAddSheet: Bool = false
    @Published var showEditSheet: Bool = false
    @Published var selectedBrother: Person?
    @Published var expandedBrotherIds: Set<Int> = []
    
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
        
        $searchText
            .combineLatest($brothers)
            .map { searchText, brothers in
                if searchText.isEmpty {
                    return brothers
                } else {
                    return brothers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                }
            }
            .assign(to: &$filteredBrothers)
    }
    
    func fetchBrothers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let brothers: [Person] = try await networkManager.request(endpoint: TerritoryEndpoint.getPersons(search: nil))
                self.brothers = brothers.sorted { $0.name < $1.name }
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func addBrother(name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await networkManager.request(endpoint: TerritoryEndpoint.addPerson(name: name))
            ToastManager.shared.show("brothers.add_success", style: .success)
            fetchBrothers()
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
            fetchBrothers()
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
            fetchBrothers()
        } catch {
            self.errorMessage = error.localizedDescription
            ToastManager.shared.show(error.localizedDescription, style: .error)
            self.isLoading = false
        }
    }
}
