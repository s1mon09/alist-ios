import Foundation

/// 管理员 - 用户服务
final class AdminUserService {
    static let shared = AdminUserService()
    private init() {}

    func list(page: Int = 1, perPage: Int = 200) async throws -> PageResp<User> {
        try await APIClient.shared.request(
            path: "/admin/user/list",
            query: ["page": page, "per_page": perPage],
            responseType: PageResp<User>.self
        )
    }

    func get(id: Int) async throws -> User {
        try await APIClient.shared.request(path: "/admin/user/get", query: ["id": id], responseType: User.self)
    }

    func create(user: User) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/user/create",
            method: .POST,
            body: user,
            responseType: EmptyData.self
        )
    }

    func update(user: User) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/user/update",
            method: .POST,
            body: user,
            responseType: EmptyData.self
        )
    }

    func cancel2FA(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/user/cancel_2fa",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }

    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/user/delete",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }

    func delCache(username: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/user/del_cache",
            method: .POST,
            query: ["username": username],
            responseType: EmptyData.self
        )
    }
}

/// 管理员 - 存储服务
final class AdminStorageService {
    static let shared = AdminStorageService()
    private init() {}

    func list() async throws -> [Storage] {
        try await APIClient.shared.request(path: "/admin/storage/list", responseType: [Storage].self)
    }

    func get(id: Int) async throws -> Storage {
        try await APIClient.shared.request(path: "/admin/storage/get", query: ["id": id], responseType: Storage.self)
    }

    func create(storage: Storage) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/storage/create",
            method: .POST,
            body: storage,
            responseType: EmptyData.self
        )
    }

    func update(storage: Storage) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/storage/update",
            method: .POST,
            body: storage,
            responseType: EmptyData.self
        )
    }

    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/storage/delete",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }

    func enable(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/storage/enable",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }

    func disable(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/storage/disable",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }

    func loadAll() async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/storage/load_all",
            method: .POST,
            responseType: EmptyData.self
        )
    }
}

/// 驱动信息服务
final class DriverService {
    static let shared = DriverService()
    private init() {}

    func list() async throws -> [DriverInfo] {
        try await APIClient.shared.request(path: "/admin/driver/list", responseType: [DriverInfo].self)
    }

    func names() async throws -> DriverNames {
        try await APIClient.shared.request(path: "/admin/driver/names", responseType: DriverNames.self)
    }

    func info(name: String) async throws -> DriverInfo {
        try await APIClient.shared.request(path: "/admin/driver/info", query: ["driver": name], responseType: DriverInfo.self)
    }
}

/// 管理员 - 角色服务
final class AdminRoleService {
    static let shared = AdminRoleService()
    private init() {}

    func list() async throws -> [Role] {
        try await APIClient.shared.request(path: "/admin/role/list", responseType: [Role].self)
    }

    func get(id: Int) async throws -> Role {
        try await APIClient.shared.request(path: "/admin/role/get", query: ["id": id], responseType: Role.self)
    }

    func create(role: Role) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/role/create",
            method: .POST,
            body: role,
            responseType: EmptyData.self
        )
    }

    func update(role: Role) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/role/update",
            method: .POST,
            body: role,
            responseType: EmptyData.self
        )
    }

    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/role/delete",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }
}

/// 管理员 - Meta 服务
final class AdminMetaService {
    static let shared = AdminMetaService()
    private init() {}

    func list() async throws -> [Meta] {
        try await APIClient.shared.request(path: "/admin/meta/list", responseType: [Meta].self)
    }

    func get(id: Int) async throws -> Meta {
        try await APIClient.shared.request(path: "/admin/meta/get", query: ["id": id], responseType: Meta.self)
    }

    func create(meta: Meta) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/meta/create",
            method: .POST,
            body: meta,
            responseType: EmptyData.self
        )
    }

    func update(meta: Meta) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/meta/update",
            method: .POST,
            body: meta,
            responseType: EmptyData.self
        )
    }

    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/meta/delete",
            method: .POST,
            query: ["id": id],
            responseType: EmptyData.self
        )
    }
}

/// 管理员 - 设置服务
final class AdminSettingService {
    static let shared = AdminSettingService()
    private init() {}

    func list() async throws -> [SettingItem] {
        try await APIClient.shared.request(path: "/admin/setting/list", responseType: [SettingItem].self)
    }

    func get(key: String) async throws -> SettingItem {
        try await APIClient.shared.request(path: "/admin/setting/get", query: ["key": key], responseType: SettingItem.self)
    }

    func save(items: [SettingItem]) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/setting/save",
            method: .POST,
            body: items,
            responseType: EmptyData.self
        )
    }

    func delete(key: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/setting/delete",
            method: .POST,
            query: ["key": key],
            responseType: EmptyData.self
        )
    }

    func resetToken() async throws -> String {
        struct TokenResp: Decodable { let token: String }
        return try await APIClient.shared.request(
            path: "/admin/setting/reset_token",
            method: .POST,
            responseType: TokenResp.self
        ).token
    }

    func setAria2(url: String, secret: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/setting/set_aria2",
            method: .POST,
            body: ["aria2_address": url, "aria2_secret": secret],
            responseType: EmptyData.self
        )
    }

    func setQbit(url: String, username: String, password: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/setting/set_qbit",
            method: .POST,
            body: ["qbit_address": url, "qbit_username": username, "qbit_password": password],
            responseType: EmptyData.self
        )
    }
}

/// 管理员 - 索引服务
final class AdminIndexService {
    static let shared = AdminIndexService()
    private init() {}

    func build() async throws {
        _ = try await APIClient.shared.request(path: "/admin/index/build", method: .POST, responseType: EmptyData.self)
    }

    func update() async throws {
        _ = try await APIClient.shared.request(path: "/admin/index/update", method: .POST, responseType: EmptyData.self)
    }

    func stop() async throws {
        _ = try await APIClient.shared.request(path: "/admin/index/stop", method: .POST, responseType: EmptyData.self)
    }

    func clear() async throws {
        _ = try await APIClient.shared.request(path: "/admin/index/clear", method: .POST, responseType: EmptyData.self)
    }

    func progress() async throws -> IndexProgress {
        try await APIClient.shared.request(path: "/admin/index/progress", responseType: IndexProgress.self)
    }
}

struct IndexProgress: Decodable {
    let current: Int64?
    let total: Int64?
    let done: Bool?
}
