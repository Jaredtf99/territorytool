import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    static let attentionDays = 90

    @Published var snapshot: DashboardSnapshot?
    @Published var oldTerritories: [Territory] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var recentEvents: [TransactionEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService) {
        self.apiService = apiService

        // Reload when the active congregation changes (multi-tenant).
        NotificationCenter.default.publisher(for: .congregationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.oldTerritories = []
                self?.recentEvents = []
                self?.snapshot = nil
                Task { [weak self] in await self?.loadDashboard() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .territoryDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadDashboard() }
            }
            .store(in: &cancellables)
    }

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot: DashboardSnapshot = try await apiService.request(
                endpoint: TerritoryEndpoint.getDashboardSnapshot(
                    weekStart: Self.startOfCurrentWeek(),
                    timeZone: TimeZone.current.identifier,
                    attentionDays: Self.attentionDays
                )
            )
            guard !Task.isCancelled else { return }
            self.snapshot = snapshot
            recentTransactions = snapshot.weeklyEvents.map(\.transaction)
            recentEvents = snapshot.weeklyEvents.map { movement in
                TransactionEvent(
                    txnId: movement.transactionId,
                    type: movement.eventType == .given ? .given : .returned,
                    date: movement.eventDate,
                    transaction: movement.transaction
                )
            }

        } catch {
            // Una cancelación (refresh interrumpido) no es un fallo: conservamos
            // los datos actuales sin pintar un mensaje de error.
            if !error.isCancellation {
                errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    /// Compatibility entry point used by existing transaction-edit sheets.
    func loadOldTerritories() async {
        await loadDashboard()
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

    var userName: String {
        guard let token = TokenManager.shared.getToken() else { return "" }
        return JWTHelper.getUserName(from: token) ?? ""
    }

    var greetingKey: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<13: return "dashboard.greeting.morning"
        case 13..<20: return "dashboard.greeting.afternoon"
        default: return "dashboard.greeting.evening"
        }
    }

    var priorityDays: Int {
        guard let date = snapshot?.priority?.givenAt else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    var totalGivenThisWeek: Int {
        snapshot?.activity.reduce(0) { $0 + $1.givenCount } ?? 0
    }

    var totalReturnedThisWeek: Int {
        snapshot?.activity.reduce(0) { $0 + $1.returnedCount } ?? 0
    }

    private static func startOfCurrentWeek() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? calendar.startOfDay(for: Date())
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
            NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
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
            NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
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
            NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
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
