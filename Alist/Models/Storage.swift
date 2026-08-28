import Foundation

// MARK: - 存储驱动
struct Storage: Codable, Identifiable {
    var id: Int
    var mountPath: String
    var order: Int
    var driver: String
    var cacheExpiration: Int
    var status: String
    var addition: String
    var remark: String
    var modified: Date?
    var disabled: Bool
    var disableIndex: Bool
    var enableSign: Bool
    var orderBy: String?
    var orderDirection: String?
    var extractFolder: String?
    var webProxy: Bool
    var webdavPolicy: String
    var proxyRange: Bool
    var downProxyUrl: String?
    var downProxySign: Bool?

    enum CodingKeys: String, CodingKey {
        case id, driver, status, addition, remark, modified, disabled, order
        case mountPath = "mount_path"
        case cacheExpiration = "cache_expiration"
        case disableIndex = "disable_index"
        case enableSign = "enable_sign"
        case orderBy = "order_by"
        case orderDirection = "order_direction"
        case extractFolder = "extract_folder"
        case webProxy = "web_proxy"
        case webdavPolicy = "webdav_policy"
        case proxyRange = "proxy_range"
        case downProxyUrl = "down_proxy_url"
        case downProxySign = "down_proxy_sign"
    }
}

// MARK: - 驱动信息
struct DriverInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let addition: [DriverAddition]
    let config: DriverConfig
    let onlyProxy: Bool?
    let onlyLocal: Bool?

    enum CodingKeys: String, CodingKey {
        case name, addition, config
        case onlyProxy = "only_proxy"
        case onlyLocal = "only_local"
    }
}

struct DriverAddition: Codable, Identifiable {
    var id: String { name }
    let name: String
    let type: String
    let `default`: String?
    let options: String?
    let required: Bool?
    let help: String?
}

struct DriverConfig: Codable {
    let name: String
    let localSort: Bool?
    let onlyLocal: Bool?
    let onlyProxy: Bool?
    let noCache: Bool?
    let noUpload: Bool?
    let needMs: Bool?
    let defaultRoot: String?
    let alert: String?

    enum CodingKeys: String, CodingKey {
        case name, alert
        case localSort = "local_sort"
        case onlyLocal = "only_local"
        case onlyProxy = "only_proxy"
        case noCache = "no_cache"
        case noUpload = "no_upload"
        case needMs = "need_ms"
        case defaultRoot = "default_root"
    }
}

// MARK: - 简单驱动名称列表
typealias DriverNames = [String]
