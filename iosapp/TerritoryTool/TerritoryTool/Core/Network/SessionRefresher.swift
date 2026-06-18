import Foundation

/// Coordinates access-token refreshes so that several concurrent 401s (or the
/// background refresh firing at the same time as a request) trigger a single
/// call to the GoTrue refresh endpoint instead of a stampede.
actor SessionRefresher {
    static let shared = SessionRefresher()

    private var inFlight: Task<String, Error>?

    /// Returns a fresh access token. Concurrent callers share the same refresh.
    /// Throws if there is no refresh token or the refresh is rejected.
    func refresh() async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task<String, Error> {
            try await SupabaseAuthService.shared.refreshSession()
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
