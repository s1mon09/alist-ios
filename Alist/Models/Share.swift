import Foundation

// MARK: - 分享
struct Share: Codable, Identifiable {
    var id: Int
    var shareID: String
    var creatorID: Int
    var name: String
    var rootPath: String
    var isDir: Bool
    var burnAfterRead: Bool
    var accessLimit: Int64
    var accessCount: Int64
    var allowPreview: Bool
    var allowDownload: Bool
    var enabled: Bool
    var password: String?
    var viewCount: Int64
    var downloadCount: Int64
    var lastAccessAt: Date?
    var consumedAt: Date?
    var expiresAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, password
        case shareID = "share_id"
        case creatorID = "creator_id"
        case rootPath = "root_path"
        case isDir = "is_dir"
        case burnAfterRead = "burn_after_read"
        case accessLimit = "access_limit"
        case accessCount = "access_count"
        case allowPreview = "allow_preview"
        case allowDownload = "allow_download"
        case viewCount = "view_count"
        case downloadCount = "download_count"
        case lastAccessAt = "last_access_at"
        case consumedAt = "consumed_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var hasPassword: Bool { (password?.isEmpty == false) }
    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return exp < Date()
    }
}

// MARK: - 创建/更新分享请求
struct CreateShareReq: Codable {
    let name: String
    let path: String
    let password: String?
    let isDir: Bool
    let burnAfterRead: Bool
    let accessLimit: Int64
    let allowPreview: Bool
    let allowDownload: Bool
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case name, path, password
        case isDir = "is_dir"
        case burnAfterRead = "burn_after_read"
        case accessLimit = "access_limit"
        case allowPreview = "allow_preview"
        case allowDownload = "allow_download"
        case expiresAt = "expires_at"
    }
}

struct UpdateShareReq: Codable {
    let id: Int
    let name: String?
    let password: String?
    let burnAfterRead: Bool?
    let accessLimit: Int64?
    let allowPreview: Bool?
    let allowDownload: Bool?
    let enabled: Bool?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, password, enabled
        case burnAfterRead = "burn_after_read"
        case accessLimit = "access_limit"
        case allowPreview = "allow_preview"
        case allowDownload = "allow_download"
        case expiresAt = "expires_at"
    }
}

// MARK: - 公共分享
struct PublicShareInfo: Codable {
    let id: Int
    let shareID: String
    let name: String
    let isDir: Bool
    let rootPath: String
    let burnAfterRead: Bool
    let accessLimit: Int64
    let accessCount: Int64
    let allowPreview: Bool
    let allowDownload: Bool
    let hasPassword: Bool
    let expired: Bool
    let consumed: Bool
    let remaining: Int64
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case shareID = "share_id"
        case isDir = "is_dir"
        case rootPath = "root_path"
        case burnAfterRead = "burn_after_read"
        case accessLimit = "access_limit"
        case accessCount = "access_count"
        case allowPreview = "allow_preview"
        case allowDownload = "allow_download"
        case hasPassword = "has_password"
        case expired, consumed, remaining
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct PublicShareAuthReq: Encodable {
    let shareID: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case shareID = "share_id"
        case password
    }
}

struct PublicShareAuthResp: Decodable {
    let token: String
}
