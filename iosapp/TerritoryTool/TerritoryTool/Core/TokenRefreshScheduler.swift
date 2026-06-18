import Foundation
import BackgroundTasks

/// Keeps the Supabase session alive while the app is not in use by asking iOS to
/// run a token refresh roughly every 5 days. This is best-effort: the system
/// decides the actual run time based on the user's habits and device state, so
/// it is a backstop, not a guarantee. The reactive 401 → refresh path in
/// `NetworkManager` is what fixes the session on the next request either way.
enum TokenRefreshScheduler {
    /// Must match the value listed under `BGTaskSchedulerPermittedIdentifiers`
    /// in the (generated) Info.plist.
    static let taskIdentifier = "com.jared.TerritoryTool.tokenrefresh"

    private static let interval: TimeInterval = 5 * 24 * 60 * 60 // 5 days

    /// Schedules the next background refresh. No-op when there is no session to
    /// keep alive. Safe to call repeatedly (replaces the pending request).
    static func scheduleNext() {
        guard TokenManager.shared.getRefreshToken() != nil else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule token refresh: \(error)")
        }
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    /// Performs the refresh and chains the next run. Invoked from the
    /// `.backgroundTask` handler in the app entry point.
    static func runRefresh() async {
        scheduleNext()
        guard TokenManager.shared.getRefreshToken() != nil else { return }
        _ = try? await SessionRefresher.shared.refresh()
    }
}
