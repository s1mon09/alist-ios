import Foundation
import SwiftUI
import BackgroundTasks
import StoreKit

/// 后台任务管理器（支持后台音频播放和文件下载）
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alist.refresh", using: nil) { task in
            if let refreshTask = task as? BGAppRefreshTask {
                self.handleAppRefresh(refreshTask)
            } else {
                task.setTaskCompleted(success: false)
            }
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.alist.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleRefresh()
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        Task {
            // 刷新任务列表等
            task.setTaskCompleted(success: true)
        }
    }
}

/// App 评价管理
final class AppReviewManager {
    static let shared = AppReviewManager()
    private let key = "launch_count"
    private let reviewedKey = "has_reviewed"

    func configure() {
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)
        if count >= 10 && !UserDefaults.standard.bool(forKey: reviewedKey) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                UserDefaults.standard.set(true, forKey: reviewedKey)
            }
        }
    }
}

/// 触觉反馈
enum HapticManager {
    static func light() {
        guard UserDefaults.standard.object(forKey: "enable_haptic") as? Bool ?? true else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        guard UserDefaults.standard.object(forKey: "enable_haptic") as? Bool ?? true else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        guard UserDefaults.standard.object(forKey: "enable_haptic") as? Bool ?? true else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        guard UserDefaults.standard.object(forKey: "enable_haptic") as? Bool ?? true else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
