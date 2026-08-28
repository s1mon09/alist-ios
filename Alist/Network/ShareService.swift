import Foundation

/// 分享服务
final class ShareService {
    static let shared = ShareService()
    private init() {}

    func list() async throws -> [Share] {
        try await APIClient.shared.request(path: "/share/list", responseType: [Share].self)
    }

    func create(req: CreateShareReq) async throws {
        _ = try await APIClient.shared.request(
            path: "/share/create",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    func update(req: UpdateShareReq) async throws {
        _ = try await APIClient.shared.request(
            path: "/share/update",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    func disable(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/share/disable",
            method: .POST,
            body: ["id": id],
            responseType: EmptyData.self
        )
    }

    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/share/delete",
            method: .POST,
            body: ["id": id],
            responseType: EmptyData.self
        )
    }
}
