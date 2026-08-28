import Foundation

/// App Group 共享配置（供主 App、分享扩展、小组件之间共享数据）
enum AppGroup {
    static let id = "group.com.s1mon09.alist"

    /// App Group 共享的 UserDefaults（未启用 App Group 时为 nil，自动降级）
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: id)
    }

    // MARK: - 共享键
    enum Key {
        static let baseURL = "shared_server_url"
        static let token = "shared_token"
        static let offlinePath = "shared_offline_path"
        static let offlineTool = "shared_offline_tool"
        static let downloadsFile = "downloads.json"
    }

    /// 读取共享的服务器地址
    static var sharedBaseURL: String {
        defaults?.string(forKey: Key.baseURL) ?? ""
    }

    /// 读取共享的 Token
    static var sharedToken: String {
        defaults?.string(forKey: Key.token) ?? ""
    }

    /// 写入共享配置（主 App 在 ServerConfig 更新时调用）
    static func sync(baseURL: String, token: String) {
        guard let defaults = defaults else { return }
        defaults.set(baseURL, forKey: Key.baseURL)
        defaults.set(token, forKey: Key.token)
    }

    /// 共享容器中的下载记录文件（小组件读取）
    static var downloadsURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
            .appendingPathComponent(Key.downloadsFile)
    }
}
