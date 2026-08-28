import Foundation

// MARK: - Meta 元数据
struct Meta: Codable, Identifiable {
    var id: Int
    var path: String
    var password: String?
    var pSub: Bool
    var write: Bool
    var wSub: Bool
    var hide: String?
    var hSub: Bool
    var readme: String?
    var rSub: Bool
    var header: String?
    var headerSub: Bool

    enum CodingKeys: String, CodingKey {
        case id, path, password, write, hide, readme, header
        case pSub = "p_sub"
        case wSub = "w_sub"
        case hSub = "h_sub"
        case rSub = "r_sub"
        case headerSub = "header_sub"
    }
}

// MARK: - 角色
struct Role: Codable, Identifiable {
    var id: Int
    var name: String
    var description: String?
    var `default`: Bool?
    var permissionScopes: [PermissionEntry]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case `default` = "default"
        case permissionScopes = "permission_scopes"
    }
}

// MARK: - 设置项
struct SettingItem: Codable, Identifiable {
    var id: String { key }
    let key: String
    var value: String
    let help: String?
    let type: String?
    let options: String?
    let group: Int?
    let flag: Int?
    let index: Int?
}

// MARK: - 设置分组
enum SettingGroup: Int, CaseIterable {
    case single = 0
    case site = 1
    case style = 2
    case preview = 3
    case global = 4
    case offlineDownload = 5
    case index = 6
    case sso = 7
    case ldap = 8
    case s3 = 9
    case ftp = 10
    case traffic = 11
    case frp = 12

    var name: String {
        switch self {
        case .single: return "单点"
        case .site: return "站点"
        case .style: return "样式"
        case .preview: return "预览"
        case .global: return "全局"
        case .offlineDownload: return "离线下载"
        case .index: return "索引"
        case .sso: return "SSO"
        case .ldap: return "LDAP"
        case .s3: return "S3"
        case .ftp: return "FTP"
        case .traffic: return "流量"
        case .frp: return "FRP"
        }
    }
}

// MARK: - 公共设置
struct PublicSettings: Codable {
    let title: String?
    let logo: String?
    let favicon: String?
    let cdn: String?
    let apiURL: String?
    let baseURL: String?
    let allowIndex: Bool?
    let allowRegister: Bool?
    let allowDelete: Bool?
    let allowCreate: Bool?
    let allowModify: Bool?
    let allowMove: Bool?
    let allowRename: Bool?
    let allowCopy: Bool?
    let allowUpload: Bool?
    let allowDownload: Bool?
    let allowSearch: Bool?
    let allowArchive: Bool?
    let allowDecompress: Bool?
    let allowOfflineDownload: Bool?
    let allowShare: Bool?
    let ssoLoginEnabled: Bool?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case title, logo, favicon, cdn, version
        case apiURL = "api_url"
        case baseURL = "base_url"
        case allowIndex = "allow_index"
        case allowRegister = "allow_register"
        case allowDelete = "allow_delete"
        case allowCreate = "allow_create"
        case allowModify = "allow_modify"
        case allowMove = "allow_move"
        case allowRename = "allow_rename"
        case allowCopy = "allow_copy"
        case allowUpload = "allow_upload"
        case allowDownload = "allow_download"
        case allowSearch = "allow_search"
        case allowArchive = "allow_archive"
        case allowDecompress = "allow_decompress"
        case allowOfflineDownload = "allow_offline_download"
        case allowShare = "allow_share"
        case ssoLoginEnabled = "sso_login_enabled"
    }
}
