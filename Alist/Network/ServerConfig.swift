import Foundation

/// 服务器配置单例
final class ServerConfig {
    static let shared = ServerConfig()

    private var _baseURL: String = ""
    private var _token: String = ""

    private let lock = NSLock()

    private init() {}

    var baseURL: String {
        lock.lock(); defer { lock.unlock() }
        return _baseURL
    }

    var token: String {
        lock.lock(); defer { lock.unlock() }
        return _token
    }

    func update(baseURL: String) {
        lock.lock()
        defer { lock.unlock() }
        _baseURL = baseURL.trimmedURL
        // 同步到 App Group，供分享扩展与小组件读取
        AppGroup.sync(baseURL: _baseURL, token: _token)
    }

    func update(token: String) {
        lock.lock()
        defer { lock.unlock() }
        _token = token
        // 同步到 App Group，供分享扩展与小组件读取
        AppGroup.sync(baseURL: _baseURL, token: _token)
    }

    /// 完整 API URL
    func apiURL(_ path: String) -> URL? {
        let base = baseURL
        guard !base.isEmpty else { return nil }
        let full = "\(base)/api\(path)"
        return URL(string: full)
    }

    /// 任意完整 URL
    func fullURL(_ path: String) -> URL? {
        let base = baseURL
        guard !base.isEmpty else { return nil }
        return URL(string: base + path)
    }
}
