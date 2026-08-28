import Foundation

// MARK: - 会话信息
struct Session: Codable, Identifiable {
    var id: String { deviceID ?? (userAgent ?? "") + (ip ?? "") }
    let deviceID: String?
    let userAgent: String?
    let ip: String?
    let lastActive: Date?
    let active: Bool?

    enum CodingKeys: String, CodingKey {
        case userAgent, ip, active
        case deviceID = "device_id"
        case lastActive = "last_active"
    }
}

// MARK: - SSH 公钥
struct SSHPublicKey: Codable, Identifiable {
    var id: Int
    let name: String
    let publicKey: String
    let fingerprint: String?
    let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, fingerprint
        case publicKey = "public_key"
        case addedAt = "added_at"
    }
}

// MARK: - 搜索请求/响应
struct SearchReq: Encodable {
    let parent: String
    let keywords: String
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case parent, keywords, page
        case perPage = "per_page"
    }
}

struct SearchResp: Decodable {
    let content: [FileObject]
    let total: Int64
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case content, total, page
        case perPage = "per_page"
    }
}

// MARK: - 标签文件绑定
struct LabelFileBinding: Codable, Identifiable {
    var id: Int
    let labelID: Int
    let fileName: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case labelID = "label_id"
        case fileName = "file_name"
        case createdAt = "created_at"
    }
}

struct CreateLabelBindingReq: Encodable {
    let labelID: Int
    let fileName: String

    enum CodingKeys: String, CodingKey {
        case labelID = "label_id"
        case fileName = "file_name"
    }
}

// MARK: - 离线下载工具
struct OfflineDownloadTool: Codable, Identifiable {
    var id: String { name }
    let name: String
    let enabled: Bool
    let download: Bool?
    let transfer: Bool?
}
