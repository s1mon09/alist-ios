import Foundation
import CryptoKit

/// 认证服务
final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - 密码登录（sha256 hash）
    func login(username: String, password: String, otpCode: String = "") async throws -> LoginResp {
        let hashed = AuthService.staticHash(password)
        let req = LoginReq(username: username, password: hashed, otpCode: otpCode.isEmpty ? nil : otpCode)
        return try await APIClient.shared.request(
            path: "/auth/login/hash",
            method: .POST,
            body: req,
            responseType: LoginResp.self
        )
    }

    // MARK: - LDAP 登录
    func loginLDAP(username: String, password: String, otpCode: String = "") async throws -> LoginResp {
        let req = LoginReq(username: username, password: password, otpCode: otpCode.isEmpty ? nil : otpCode)
        return try await APIClient.shared.request(
            path: "/auth/login/ldap",
            method: .POST,
            body: req,
            responseType: LoginResp.self
        )
    }

    // MARK: - 注册
    func register(username: String, password: String) async throws {
        let req = RegisterReq(username: username, password: password)
        _ = try await APIClient.shared.request(
            path: "/auth/register",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 当前用户信息
    func currentUser() async throws -> UserResp {
        try await APIClient.shared.request(path: "/me", responseType: UserResp.self)
    }

    // MARK: - 更新当前用户
    func updateCurrent(user: User) async throws {
        _ = try await APIClient.shared.request(
            path: "/me/update",
            method: .POST,
            body: user,
            responseType: EmptyData.self
        )
    }

    // MARK: - 登出
    func logout() async throws {
        _ = try await APIClient.shared.request(path: "/auth/logout", responseType: EmptyData.self)
    }

    // MARK: - 生成 2FA
    func generate2FA() async throws -> Generate2FAResp {
        try await APIClient.shared.request(
            path: "/auth/2fa/generate",
            method: .POST,
            body: EmptyBody(),
            responseType: Generate2FAResp.self
        )
    }

    // MARK: - 验证 2FA
    func verify2FA(code: String, secret: String) async throws {
        let req = Verify2FAReq(code: code, secret: secret)
        _ = try await APIClient.shared.request(
            path: "/auth/2fa/verify",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - SSO 登录跳转
    func ssoRedirectURL() -> URL? {
        ServerConfig.shared.apiURL("/auth/sso")
    }

    // MARK: - SSO 获取 token
    func ssoGetToken(state: String) async throws -> LoginResp {
        try await APIClient.shared.request(
            path: "/auth/sso_get_token",
            query: ["state": state],
            responseType: LoginResp.self
        )
    }

    // MARK: - 密码静态哈希（与 Alist 后端一致）
    /// SHA256(password-https://github.com/alist-org/alist)
    static func staticHash(_ password: String) -> String {
        let salt = "https://github.com/alist-org/alist"
        let data = Data("\(password)-\(salt)".utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct EmptyBody: Encodable {}
