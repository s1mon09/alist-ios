import SwiftUI

// MARK: - AppDelegate（用于处理后台 URLSession 完成回调）
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 后台下载完成时的回调句柄，必须保存并在所有任务结束后调用
    private var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        // 仅处理我们注册的后台下载会话
        if identifier == "com.alist.ios.background.download" {
            backgroundCompletionHandler = completionHandler
        } else {
            // 非我们的会话，立即调用以避免阻塞系统
            completionHandler()
        }
    }

    /// 由 DownloadManager 在 urlSessionDidFinishEvents 中调用
    func invokeBackgroundCompletionHandler() {
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}

@main
struct AlistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authVM)
                .environmentObject(downloadManager)
                .preferredColorScheme(appState.colorScheme)
                .environment(\.locale, appState.locale)
                .onAppear {
                    AppReviewManager.shared.configure()
                    BackgroundTaskManager.shared.register()
                }
        }
    }
}
