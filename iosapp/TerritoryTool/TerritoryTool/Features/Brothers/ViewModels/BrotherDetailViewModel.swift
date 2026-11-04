import Foundation
import Combine
import SwiftUI

/// Filtro del histórico de la ficha de hermano.
enum BrotherHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case ongoing
    case returned
    case virtual

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "brother.detail.history.filter.all"
        case .ongoing: "brother.detail.history.filter.ongoing"
        case .returned: "brother.detail.history.filter.returned"
        case .virtual: "brother.detail.history.filter.virtual"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.stack.3d.up.fill"
        case .ongoing: "figure.walk"
        case .returned: "checkmark"
        case .virtual: DeliveryFormat.virtual.systemImage
        }
    }

    func matches(_ item: PersonAssignment) -> Bool {
        switch self {
        case .all: true
        case .ongoing: item.isOngoing
        case .returned: !item.isOngoing
        case .virtual: item.deliveryFormat == .virtual
        }
    }
}

/// Grupo del histórico por año de entrega.
struct BrotherHistoryYear: Identifiable, Equatable {
    let year: Int
    let items: [PersonAssignment]
    var id: Int { year }
}

@MainActor
final class BrotherDetailViewModel: ObservableObject {
    @Published private(set) var detail: PersonDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var historyFilter: BrotherHistoryFilter = .all
    @Published var historySearch = ""
    @Published var historyLimit = BrotherDetailViewModel.historyPage

    static let historyPage = 20

    let personId: Int
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()

    init(personId: Int, apiService: APIService = NetworkManager.shared) {
        self.personId = personId
        self.apiService = apiService

        // Entregar/devolver desde la Acción rápida o editar al hermano refresca la ficha.
        NotificationCenter.default.publisher(for: .territoryDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.load() }
            }
            .store(in: &cancellables)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: PersonDetail = try await apiService.request(
                endpoint: TerritoryEndpoint.getPersonDetail(id: personId)
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                detail = result
            }
        } catch {
            if !error.isCancellation {
                let message = error.localizedDescription
                errorMessage = message.localizedCaseInsensitiveContains("PERSON_NOT_FOUND")
                    ? String.localized("brothers.error.not_found")
                    : message
            }
        }
        isLoading = false
    }

    // MARK: Histórico

    var filteredHistory: [PersonAssignment] {
        let term = historySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return (detail?.history ?? []).filter { item in
            guard historyFilter.matches(item) else { return false }
            guard !term.isEmpty else { return true }
            return item.territoryCode.localizedStandardContains(term)
                || item.territoryName.localizedStandardContains(term)
        }
    }

    var historyGroups: [BrotherHistoryYear] {
        let calendar = Calendar.current
        var groups: [BrotherHistoryYear] = []
        var currentYear: Int?
        var bucket: [PersonAssignment] = []
        for item in filteredHistory.prefix(historyLimit) {
            let year = calendar.component(.year, from: item.givenAt)
            if year != currentYear, let currentYear {
                groups.append(BrotherHistoryYear(year: currentYear, items: bucket))
                bucket = []
            }
            currentYear = year
            bucket.append(item)
        }
        if let currentYear, !bucket.isEmpty {
            groups.append(BrotherHistoryYear(year: currentYear, items: bucket))
        }
        return groups
    }

    var remainingHistoryCount: Int {
        max(filteredHistory.count - historyLimit, 0)
    }

    func count(for filter: BrotherHistoryFilter) -> Int {
        (detail?.history ?? []).filter(filter.matches).count
    }

    func setFilter(_ filter: BrotherHistoryFilter) {
        historyFilter = filter
        historyLimit = Self.historyPage
    }

    func showMoreHistory() {
        historyLimit += Self.historyPage
    }
}
