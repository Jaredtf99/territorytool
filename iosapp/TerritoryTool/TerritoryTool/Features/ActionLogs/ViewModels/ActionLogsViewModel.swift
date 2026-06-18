import Foundation
import Combine
import SwiftUI

@MainActor
class ActionLogsViewModel: ObservableObject {
    @Published var logs: [ActionLog] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var canLoadMore = true
    
    private let apiService: APIService
    private var currentPage = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // Sort options
    private let sortField = "DateUtc"
    private let sortOrder = "desc" // Newest first
    
    init(apiService: APIService = NetworkManager.shared) {
        self.apiService = apiService

        // Reload when the active congregation changes (multi-tenant).
        NotificationCenter.default.publisher(for: .congregationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadLogs(reset: true) }
            }
            .store(in: &cancellables)
    }
    
    func loadLogs(reset: Bool = false) async {
        if reset {
            currentPage = 1
            canLoadMore = true
            logs = []
            isLoading = true
        } else {
            // Check if we are already loading info
            guard !isLoadingMore && canLoadMore else { return }
            isLoadingMore = true
        }
        
        errorMessage = nil
        
        do {
            let response: PaginatedResponse<ActionLog> = try await apiService.request(endpoint: TerritoryEndpoint.getActionLogs(
                page: currentPage,
                pageSize: pageSize,
                sortField: sortField,
                sortOrder: sortOrder
            ))
            
            let fetchedLogs = response.data
            
            // Artificial delay for smoother UX if loading very fast
            // try? await Task.sleep(nanoseconds: 500_000_000)
            
            if reset {
                self.logs = fetchedLogs
            } else {
                self.logs.append(contentsOf: fetchedLogs)
            }
            
            // Check if we reached the end
            // If explicit last_page is provided, use it. Otherwise use size check.
            if let lastPage = response.last_page {
                 if currentPage >= lastPage {
                     canLoadMore = false
                 } else {
                     currentPage += 1
                 }
            } else {
                 if fetchedLogs.count < pageSize {
                     canLoadMore = false
                 } else {
                     currentPage += 1
                 }
            }
            
        } catch {
            if !error.isCancellation {
                self.errorMessage = error.localizedDescription
            }
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }
    
    func loadMoreIfNeeded(currentItem: ActionLog) {
        guard let lastItem = logs.last else { return }
        if currentItem.id == lastItem.id {
            Task {
                await loadLogs(reset: false)
            }
        }
    }
}
