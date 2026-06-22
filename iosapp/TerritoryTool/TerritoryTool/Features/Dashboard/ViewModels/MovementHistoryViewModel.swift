import Combine
import Foundation

@MainActor
final class MovementHistoryViewModel: ObservableObject {
    @Published private(set) var movements: [DashboardMovement] = []
    @Published var searchText = ""
    @Published var filter: MovementHistoryFilter = .all
    @Published var sort: MovementHistorySort = .newest
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    @Published var errorMessage: String?

    private let apiService: APIService
    private let pageSize = 25
    private var currentPage = 1
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService) {
        self.apiService = apiService

        Publishers.CombineLatest3($searchText, $filter, $sort)
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates { lhs, rhs in
                lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2
            }
            .dropFirst()
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .congregationChanged)
            .merge(with: NotificationCenter.default.publisher(for: .territoryDataChanged))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.load(reset: true)
        }
    }

    func load(reset: Bool) async {
        if reset {
            currentPage = 1
            canLoadMore = true
            isLoading = true
        } else {
            guard canLoadMore, !isLoadingMore else { return }
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        errorMessage = nil
        do {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let response: PaginatedResponse<DashboardMovement> = try await apiService.request(
                endpoint: TerritoryEndpoint.getMovementHistory(
                    page: currentPage,
                    pageSize: pageSize,
                    search: query.isEmpty ? nil : query,
                    filter: filter,
                    sort: sort
                )
            )
            guard !Task.isCancelled else { return }

            if reset {
                movements = response.data
            } else {
                movements.append(contentsOf: response.data)
            }

            let lastPage = response.last_page ?? currentPage
            canLoadMore = currentPage < lastPage
            if canLoadMore { currentPage += 1 }
        } catch {
            guard !Task.isCancelled, !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current movement: DashboardMovement) {
        guard movement.id == movements.last?.id else { return }
        Task { await load(reset: false) }
    }
}
