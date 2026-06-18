import Foundation
import Combine

/// Holds the congregations the signed-in user can operate in and the active one,
/// and handles switching (which refreshes the JWT so RLS/role claims update).
@MainActor
final class CongregationStore: ObservableObject {
    static let shared = CongregationStore()

    @Published var congregations: [CongregationSummary] = []
    @Published var isSwitching = false

    private init() {
        load()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAuthChanged), name: .authChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var active: CongregationSummary? {
        congregations.first(where: { $0.isActive })
    }

    var hasMultiple: Bool {
        congregations.count > 1
    }

    @objc private func handleAuthChanged() {
        Task { @MainActor in self.load() }
    }

    func load() {
        guard let data = TokenManager.shared.getCongregationsData() else {
            congregations = []
            return
        }
        congregations = (try? JSONDecoder().decode([CongregationSummary].self, from: data)) ?? []
    }

    /// Reloads the list from the backend.
    func refresh() async {
        do {
            let list = try await SupabaseAuthService.shared.getMyCongregations()
            persist(list)
        } catch {
            // keep current state on failure
        }
    }

    /// Switches the active congregation and refreshes the token.
    func switchTo(_ congregationId: String) async -> Bool {
        guard active?.id != congregationId else { return true }
        isSwitching = true
        defer { isSwitching = false }
        do {
            _ = try await SupabaseAuthService.shared.setActiveCongregation(congregationId)
            TokenManager.shared.saveActiveCongregationId(congregationId)
            let updated = congregations.map { c in
                CongregationSummary(id: c.id, name: c.name, role: c.role, isActive: c.id == congregationId)
            }
            persist(updated)
            // Let screens know they should reload their data.
            NotificationCenter.default.post(name: .congregationChanged, object: nil)
            return true
        } catch {
            return false
        }
    }

    private func persist(_ list: [CongregationSummary]) {
        congregations = list
        TokenManager.shared.saveCongregations(try? JSONEncoder().encode(list))
    }
}

extension Notification.Name {
    static let congregationChanged = Notification.Name("congregationChanged")
}
