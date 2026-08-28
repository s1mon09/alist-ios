import SwiftUI

// MARK: - 加载视图
struct LoadingView: View {
    var message: String = "加载中..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - 错误视图
struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.warning)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if let retryAction = retryAction {
                Button("重试", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.secondaryText.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - Toast 提示
struct Toast: View {
    let message: String
    var type: ToastType = .info

    enum ToastType {
        case success, error, info, warning

        var color: Color {
            switch self {
            case .success: return Theme.success
            case .error: return Theme.danger
            case .info: return Theme.info
            case .warning: return Theme.warning
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.octagon.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(type.color)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
}

// MARK: - Toast 管理器（单例，全局显示）
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var toast: Toast?
    @Published var isShowing = false
    private var dismissTask: Task<Void, Never>?

    private init() {}

    @MainActor
    func show(_ message: String, type: Toast.ToastType = .info) {
        toast = Toast(message: message, type: type)
        isShowing = true
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            // 旧任务的 sleep 被取消时会立刻抛错，若已被新 toast 取消则不能隐藏
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isShowing = false
                self.toast = nil
            }
        }
    }
}

// MARK: - 确认对话框修饰器
struct ConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let action: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button("确认", role: .destructive, action: action)
            Button("取消", role: .cancel) {}
        } message: {
            if let message = message {
                Text(message)
            }
        }
    }
}

extension View {
    func confirmation(isPresented: Binding<Bool>, title: String, message: String? = nil, action: @escaping () -> Void) -> some View {
        modifier(ConfirmationDialogModifier(isPresented: isPresented, title: title, message: message, action: action))
    }
}
