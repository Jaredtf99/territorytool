import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var oldTerritories: [Territory] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var recentEvents: [TransactionEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIService
    
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    func loadOldTerritories() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate date 4 months ago
            let fourMonthsAgo = Calendar.current.date(byAdding: .month, value: -4, to: Date())
            
            // Fetch territories: inUse=true, orderBy=3 (Oldest), lastGivenDateTo=4 months ago
            let territories: [Territory] = try await apiService.request(endpoint: TerritoryEndpoint.getTerritories(
                term: nil,
                inUse: true,
                orderBy: 3,
                orderByAscending: true,
                lastGivenDateFrom: nil,
                lastGivenDateTo: fourMonthsAgo
            ))
            
            // Store all fetched territories, logic for display limit moved to View
            self.oldTerritories = territories
            
            // Fetch recent transactions (last 3 days)
            let transactions: [Transaction] = try await apiService.request(endpoint: TerritoryEndpoint.getRecentTransactions(days: 3))
            self.recentTransactions = transactions
            self.processRecentEvents(transactions: transactions)
            
        } catch {
            errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func processRecentEvents(transactions: [Transaction]) {
        var events: [TransactionEvent] = []
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        
        for tx in transactions {
            // 1. Given Event
            // Check if givenDateUtc is within last 3 days
            if tx.givenDateUtc >= threeDaysAgo {
                events.append(TransactionEvent(txnId: tx.id, type: .given, date: tx.givenDateUtc, transaction: tx))
            }
            
            // 2. Returned Event (if exists)
            if let pickedDate = tx.pickedDateUtc, pickedDate >= threeDaysAgo {
                events.append(TransactionEvent(txnId: tx.id, type: .returned, date: pickedDate, transaction: tx))
            }
        }
        
        // Sort by date descending
        self.recentEvents = events.sorted { $0.date > $1.date }
    }
    
    // MARK: - Permissions
    
    var currentUserRole: UserRole? {
        guard let token = TokenManager.shared.getToken() else { return nil }
        return JWTHelper.getUserRole(from: token)
    }
    
    var canEditTransactions: Bool {
        guard let role = currentUserRole else { return false }
        return role == .superAdmin || role == .admin
    }
    
    // MARK: - Actions
    
    func deleteTransaction(event: TransactionEvent) async {
        guard canEditTransactions else { return }
        
        // Optimistically remove from UI
        let originalEvents = self.recentEvents
        self.recentEvents.removeAll { $0.transaction.id == event.transaction.id }
        
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.deleteTransaction(id: event.transaction.id))
            // Reload data to ensure sync
            await loadOldTerritories()
        } catch {
            self.errorMessage = "Error deleting transaction: \(error.localizedDescription)"
            // Revert on error
            self.recentEvents = originalEvents
        }
    }
    
    func updateTransaction(event: TransactionEvent, newDate: Date) async {
        guard canEditTransactions else { return }
        
        let tx = event.transaction
        
        // Determine which date to update based on event type
        var givenDate = tx.givenDateUtc
        var pickedDate = tx.pickedDateUtc
        
        if event.type == .given {
            givenDate = newDate
        } else {
            pickedDate = newDate
        }
           
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.updateTransaction(
                id: tx.id,
                territoryId: tx.territoryId,
                personId: tx.personId, // Assuming personId is available in Transaction model
                date: givenDate,
                pickedDate: pickedDate
            ))
            await loadOldTerritories()
        } catch {
            self.errorMessage = "Error updating transaction: \(error.localizedDescription)"
        }
    }
    
    func updateFullTransaction(originalTransactionId: Int, territoryId: Int, personId: Int, givenDate: Date, pickedDate: Date?) async {
        guard canEditTransactions else { return }
        
        do {
            try await apiService.request(endpoint: TerritoryEndpoint.updateTransaction(
                id: originalTransactionId,
                territoryId: territoryId,
                personId: personId,
                date: givenDate,
                pickedDate: pickedDate
            ))
            await loadOldTerritories()
        } catch {
            self.errorMessage = "Error updating transaction: \(error.localizedDescription)"
        }
    }
    
    func logout() {
        TokenManager.shared.clearToken()
    }
    
    // MARK: - Edit Helpers
    
    func fetchDataForEdit() async throws -> (persons: [Person], territories: [Territory]) {
        async let personsTask = apiService.request(endpoint: TerritoryEndpoint.getPersons(search: nil)) as [Person]
        async let territoriesTask = apiService.request(endpoint: TerritoryEndpoint.getTerritories(
            term: nil, inUse: nil, orderBy: 1, orderByAscending: true, lastGivenDateFrom: nil, lastGivenDateTo: nil
        )) as [Territory]
        
        return try await (personsTask, territoriesTask)
    }
}

struct TransactionEvent: Identifiable {
    enum EventType {
        case given
        case returned
    }
    
    let id: String
    let type: EventType
    let date: Date
    let transaction: Transaction
    
    init(txnId: Int, type: EventType, date: Date, transaction: Transaction) {
        self.type = type
        self.date = date
        self.transaction = transaction
        // Create unique ID for the event
        self.id = "\(txnId)_\(type)"
    }
}
