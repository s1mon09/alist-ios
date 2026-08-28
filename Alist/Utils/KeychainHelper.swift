import Foundation
import KeychainAccess

/// Keychain 辅助工具（基于 KeychainAccess）
final class KeychainHelper {
    static let shared = KeychainHelper()

    private let keychain: Keychain

    private init() {
        keychain = Keychain(service: "com.alist.ios")
            .accessibility(.whenUnlockedThisDeviceOnly)
    }

    // MARK: - 字符串
    func save(_ string: String, forKey key: String) {
        keychain[key] = string
    }

    func loadString(forKey key: String) -> String? {
        keychain[key]
    }

    func delete(key: String) {
        keychain[key] = nil
    }

    // MARK: - Data
    func save(_ data: Data, forKey key: String) {
        try? keychain.set(data, key: key)
    }

    func loadData(forKey key: String) -> Data? {
        try? keychain.getData(key)
    }

    // MARK: - 便捷键
    enum Key {
        static let token = "auth_token"
        static let serverURL = "server_url"
        static let username = "username"
        static let userID = "user_id"
        static let deviceKey = "device_key"
    }
}
