import SwiftUI
import Combine
import SystemNotification

enum ToastStyle {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

struct ToastMessage: Equatable {
    let message: String
    let style: ToastStyle
}

// Environment key for the notification context
private struct NotificationContextKey: EnvironmentKey {
    static let defaultValue: SystemNotificationContext? = nil
}

extension EnvironmentValues {
    var notificationContext: SystemNotificationContext? {
        get { self[NotificationContextKey.self] }
        set { self[NotificationContextKey.self] = newValue }
    }
}

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var pendingMessage: ToastMessage?
    
    private init() {}
    
    func show(_ message: String, style: ToastStyle = .success) {
        pendingMessage = ToastMessage(message: message, style: style)
    }
    
    func clearPending() {
        pendingMessage = nil
    }
}
