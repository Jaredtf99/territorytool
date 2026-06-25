import SwiftUI
import Combine

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
        case .success: return .success
        case .error: return .danger
        case .info: return .info
        case .warning: return .warning
        }
    }
}

struct ToastMessage: Equatable {
    let message: String
    let style: ToastStyle
    let undoHandle: UndoHandle?
    let duration: TimeInterval

    init(
        message: String,
        style: ToastStyle,
        undoHandle: UndoHandle? = nil,
        duration: TimeInterval = 3
    ) {
        self.message = message
        self.style = style
        self.undoHandle = undoHandle
        self.duration = duration
    }

    var transitionKey: String {
        "\(message)-\(style)-\(undoHandle?.id ?? "plain")"
    }
}

struct ToastGlassMessageView: View {
    let message: ToastMessage
    let isUndoing: Bool
    let onUndo: (() -> Void)?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
    }

    var body: some View {
        GlassEffectContainer {
            ViewThatFits(in: .horizontal) {
                toastContent
                    .fixedSize(horizontal: true, vertical: false)

                toastContent
                    .frame(maxWidth: 360, alignment: .leading)
            }
        }
    }

    private var toastContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: message.style.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(message.style.color)
                .frame(width: 30, height: 30)

            Text(LocalizedStringKey(message.message))
                .font(.appSubheadline().weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(0)

            if let undoHandle = message.undoHandle, let onUndo {
                Button(role: .destructive, action: onUndo) {
                    ZStack {
                        HStack(spacing: 6) {
                            Text("common.undo")
                                .font(.appSubheadline().weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                                .fixedSize(horizontal: true, vertical: false)
                            UndoCountdownRing(expiresAt: undoHandle.expiresAt)
                        }
                        .opacity(isUndoing ? 0 : 1)
                        .scaleEffect(isUndoing ? 0.92 : 1)

                        ProgressView()
                            .controlSize(.small)
                            .opacity(isUndoing ? 1 : 0)
                            .scaleEffect(isUndoing ? 1 : 0.82)
                    }
                    .frame(minWidth: 86)
                    .animation(.snappy(duration: 0.18), value: isUndoing)
                }
                .buttonStyle(.glass)
                .tint(.danger)
                .disabled(isUndoing)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.xl))
        .overlay(
            shape.strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
        )
        .overlay {
            if isUndoing {
                shape.strokeBorder(Color.danger.opacity(0.38), lineWidth: 1.5)
                    .transition(.opacity)
            }
        }
        .scaleEffect(isUndoing ? 0.985 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isUndoing)
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct UndoCountdownRing: View {
    let expiresAt: Date

    var body: some View {
        TimelineView(.animation) { context in
            let remaining = max(expiresAt.timeIntervalSince(context.date), 0)
            let progress = min(max(remaining / 5, 0), 1)

            ZStack {
                Circle()
                    .stroke(Color.danger.opacity(0.22), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.danger, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)
        }
        .accessibilityHidden(true)
    }
}

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var pendingMessage: ToastMessage?
    
    private init() {}
    
    func show(
        _ message: String,
        style: ToastStyle = .success,
        undoHandle: UndoHandle? = nil,
        duration: TimeInterval = 3
    ) {
        pendingMessage = ToastMessage(
            message: message,
            style: style,
            undoHandle: undoHandle,
            duration: duration
        )
    }
    
    func clearPending() {
        pendingMessage = nil
    }
}
