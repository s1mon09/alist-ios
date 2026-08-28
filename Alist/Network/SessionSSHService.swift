import Foundation

/// 会话服务
final class SessionService {
    static let shared = SessionService()
    private init() {}

    // 我的会话
    func mySessions() async throws -> [Session] {
        try await APIClient.shared.request(path: "/me/sessions", responseType: [Session].self)
    }

    func evictMySession(deviceKey: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/me/sessions/evict",
            method: .POST,
            body: ["device_key": deviceKey],
            responseType: EmptyData.self
        )
    }

    // 管理员 - 所有会话
    func adminList() async throws -> [Session] {
        try await APIClient.shared.request(path: "/admin/session/list", responseType: [Session].self)
    }

    func adminEvict(deviceKey: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/session/evict",
            method: .POST,
            body: ["device_key": deviceKey],
            responseType: EmptyData.self
        )
    }
}

/// SSH 公钥服务
final class SSHKeyService {
    static let shared = SSHKeyService()
    private init() {}

    // 我的 SSH 公钥
    func listMyKeys() async throws -> [SSHPublicKey] {
        try await APIClient.shared.request(path: "/me/sshkey/list", responseType: [SSHPublicKey].self)
    }

    func addMyKey(name: String, publicKey: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/me/sshkey/add",
            method: .POST,
            body: ["name": name, "public_key": publicKey],
            responseType: EmptyData.self
        )
    }

    func deleteMyKey(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/me/sshkey/delete",
            method: .POST,
            body: ["id": id],
            responseType: EmptyData.self
        )
    }

    // 管理员
    func adminList() async throws -> [SSHPublicKey] {
        try await APIClient.shared.request(path: "/admin/user/sshkey/list", responseType: [SSHPublicKey].self)
    }

    func adminDelete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/user/sshkey/delete",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }
}
