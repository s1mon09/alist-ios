import Foundation

// MARK: - 用户角色常量
enum UserRole: Int, Codable {
    case general = 0
    case guest = 1
    case admin = 2
    case newGeneral = 3
}

typealias Roles = [Int]

// MARK: - 用户模型
struct User: Codable, Identifiable {
    var id: Int
    var username: String
    var password: String?
    var basePath: String?
    var role: Roles?
    var disabled: Bool?
    var permission: Int32?
    var ssoID: String?
    var otpSecret: String?

    enum CodingKeys: String, CodingKey {
        case id, username, password, role, disabled, permission
        case basePath = "base_path"
        case ssoID = "sso_id"
        case otpSecret = "otp_secret"
    }

    var isAdmin: Bool { role?.contains(UserRole.admin.rawValue) ?? false }
    var isGuest: Bool { role?.contains(UserRole.guest.rawValue) ?? false }
}

// MARK: - 权限条目
struct PermissionEntry: Codable, Identifiable {
    var id: String { path }
    var path: String
    var permission: Int32

    enum CodingKeys: String, CodingKey { case path, permission }
}

// MARK: - 当前用户响应（带角色名和权限）
struct UserResp: Codable, Identifiable {
    var id: Int
    var username: String
    var basePath: String?
    var role: Roles?
    var disabled: Bool?
    var permission: Int32?
    var ssoID: String?
    var otp: Bool?
    var roleNames: [String]?
    var permissions: [PermissionEntry]?

    enum CodingKeys: String, CodingKey {
        case id, username, role, disabled, permission, otp
        case basePath = "base_path"
        case ssoID = "sso_id"
        case roleNames = "role_names"
        case permissions
    }

    var isAdmin: Bool { role?.contains(UserRole.admin.rawValue) ?? false }
    var isGuest: Bool { role?.contains(UserRole.guest.rawValue) ?? false }

    // 权限位
    var canSeeHides: Bool { ((permission ?? 0) >> 0) & 1 != 0 }
    var canAccessWithoutPassword: Bool { ((permission ?? 0) >> 1) & 1 != 0 }
    var canAddOfflineDownload: Bool { ((permission ?? 0) >> 2) & 1 != 0 }
    var canWrite: Bool { ((permission ?? 0) >> 3) & 1 != 0 }
    var canRename: Bool { ((permission ?? 0) >> 4) & 1 != 0 }
    var canMove: Bool { ((permission ?? 0) >> 5) & 1 != 0 }
    var canCopy: Bool { ((permission ?? 0) >> 6) & 1 != 0 }
    var canRemove: Bool { ((permission ?? 0) >> 7) & 1 != 0 }
}

// MARK: - 登录请求/响应
struct LoginReq: Encodable {
    let username: String
    let password: String
    let otpCode: String?

    enum CodingKeys: String, CodingKey {
        case username, password
        case otpCode = "otp_code"
    }
}

struct LoginResp: Decodable {
    let token: String
    let deviceKey: String?

    enum CodingKeys: String, CodingKey {
        case token
        case deviceKey = "device_key"
    }
}

// MARK: - 注册请求
struct RegisterReq: Encodable {
    let username: String
    let password: String
}

// MARK: - 2FA
struct Generate2FAResp: Decodable {
    let qr: String
    let secret: String
}

struct Verify2FAReq: Encodable {
    let code: String
    let secret: String
}
