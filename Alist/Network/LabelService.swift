import Foundation

/// 标签服务
final class LabelService {
    static let shared = LabelService()
    private init() {}

    // 用户可见标签
    func list() async throws -> [FileLabel] {
        try await APIClient.shared.request(path: "/label/list", responseType: [FileLabel].self)
    }

    func get(id: Int) async throws -> FileLabel {
        try await APIClient.shared.request(path: "/label/get", query: ["id": id], responseType: FileLabel.self)
    }

    // 管理员操作
    func create(name: String, description: String, bgColor: String, type: Int = 0) async throws {
        struct Req: Encodable {
            let name: String
            let description: String
            let bgColor: String
            let type: Int
            enum CodingKeys: String, CodingKey {
                case name, description, type
                case bgColor = "bg_color"
            }
        }
        let req = Req(name: name, description: description, bgColor: bgColor, type: type)
        _ = try await APIClient.shared.request(
            path: "/admin/label/create",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    func update(id: Int, name: String, description: String, bgColor: String, type: Int = 0) async throws {
        struct Req: Encodable {
            let id: Int
            let name: String
            let description: String
            let bgColor: String
            let type: Int
            enum CodingKeys: String, CodingKey {
                case id, name, description, type
                case bgColor = "bg_color"
            }
        }
        let req = Req(id: id, name: name, description: description, bgColor: bgColor, type: type)
        _ = try await APIClient.shared.request(
            path: "/admin/label/update",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/label/delete",
            method: .POST,
            body: ["id": id],
            responseType: EmptyData.self
        )
    }
}

/// 标签文件绑定服务
final class LabelFileBindingService {
    static let shared = LabelFileBindingService()
    private init() {}

    func list() async throws -> [LabelFileBinding] {
        try await APIClient.shared.request(
            path: "/admin/label_file_binding/list",
            responseType: [LabelFileBinding].self
        )
    }

    func getLabelByFileName(fileName: String) async throws -> [FileLabel] {
        try await APIClient.shared.request(
            path: "/label_file_binding/get",
            query: ["file_name": fileName],
            responseType: [FileLabel].self
        )
    }

    func getFileByLabel(labelID: Int) async throws -> [String] {
        try await APIClient.shared.request(
            path: "/label_file_binding/get_file_by_label",
            query: ["label_id": labelID],
            responseType: [String].self
        )
    }

    func create(labelID: Int, fileName: String) async throws {
        let req = CreateLabelBindingReq(labelID: labelID, fileName: fileName)
        _ = try await APIClient.shared.request(
            path: "/admin/label_file_binding/create",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    func createBatch(bindings: [CreateLabelBindingReq]) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/label_file_binding/create_batch",
            method: .POST,
            body: bindings,
            responseType: EmptyData.self
        )
    }

    func delete(labelID: Int, fileName: String) async throws {
        let req = CreateLabelBindingReq(labelID: labelID, fileName: fileName)
        _ = try await APIClient.shared.request(
            path: "/admin/label_file_binding/delete",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    func restore(fileName: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/admin/label_file_binding/restore",
            method: .POST,
            body: ["file_name": fileName],
            responseType: EmptyData.self
        )
    }
}
