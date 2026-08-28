import SwiftUI
import Combine

/// 全局应用状态
final class AppState: ObservableObject {
    // 服务器配置（token 存 Keychain，URL 存 UserDefaults 因为不敏感且需在启动时读取）
    @AppStorage("server_url") var serverURL: String = "" {
        didSet { ServerConfig.shared.update(baseURL: serverURL) }
    }

    // Token 存储于 Keychain，仅通过内存变量反映状态
    @Published var token: String = "" {
        didSet {
            ServerConfig.shared.update(token: token)
            if token.isEmpty {
                KeychainHelper.shared.delete(key: KeychainHelper.Key.token)
            } else {
                KeychainHelper.shared.save(token, forKey: KeychainHelper.Key.token)
            }
            isLoggedIn = !token.isEmpty
        }
    }

    // 外观设置
    @AppStorage("appearance_mode") var appearanceMode: String = "system" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("preview_on_tap") var previewOnTap: Bool = true
    @AppStorage("show_hidden_files") var showHiddenFiles: Bool = false
    @AppStorage("list_page_size") var listPageSize: Int = 200
    @AppStorage("default_sort_field") var defaultSortField: String = "name"
    @AppStorage("default_sort_order") var defaultSortOrder: String = "asc"
    @AppStorage("enable_haptic") var enableHaptic: Bool = true
    @AppStorage("wifi_only_upload") var wifiOnlyUpload: Bool = false
    @AppStorage("wifi_only_download") var wifiOnlyDownload: Bool = false
    @AppStorage("recent_servers") var recentServersRaw: String = ""

    // 当前用户信息
    @Published var currentUser: UserResp?
    @Published var publicSettings: PublicSettings?
    @Published var isLoggedIn: Bool = false

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var locale: Locale { Locale(identifier: "zh_CN") }

    // 最近服务器列表（保留插入顺序，去重）
    var recentServers: [String] {
        get {
            recentServersRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        }
        set {
            // 去重但保留顺序（最后出现的优先）
            var seen = Set<String>()
            let unique = newValue.reversed().filter { seen.insert($0).inserted }.reversed()
            recentServersRaw = unique.joined(separator: "\n")
        }
    }

    init() {
        // 从 Keychain 恢复 token
        let savedToken = KeychainHelper.shared.loadString(forKey: KeychainHelper.Key.token) ?? ""
        self.token = savedToken
        ServerConfig.shared.update(baseURL: serverURL)
        ServerConfig.shared.update(token: savedToken)
        isLoggedIn = !savedToken.isEmpty
    }

    func logout() {
        token = ""
        isLoggedIn = false
        currentUser = nil
        KeychainHelper.shared.delete(key: KeychainHelper.Key.userID)
        ServerConfig.shared.update(token: "")
    }

    /// 添加到最近服务器
    func addRecentServer(_ url: String) {
        var list = recentServers
        list.removeAll { $0 == url }
        list.insert(url, at: 0)
        if list.count > 5 { list = Array(list.prefix(5)) }
        recentServers = list
    }
}
