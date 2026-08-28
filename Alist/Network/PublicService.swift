import Foundation

/// 公共服务（不需要登录）
final class PublicService {
    static let shared = PublicService()
    private init() {}

    // MARK: - 公共设置
    func publicSettings() async throws -> PublicSettings {
        try await APIClient.shared.request(
            path: "/public/settings",
            responseType: PublicSettings.self
        )
    }

    // MARK: - 离线下载工具列表
    func offlineDownloadTools() async throws -> [OfflineDownloadTool] {
        try await APIClient.shared.request(
            path: "/public/offline_download_tools",
            responseType: [OfflineDownloadTool].self
        )
    }

    // MARK: - 支持的归档扩展名
    func archiveExtensions() async throws -> [String] {
        try await APIClient.shared.request(
            path: "/public/archive_extensions",
            responseType: [String].self
        )
    }

    // MARK: - 公共分享信息
    func getPublicShareInfo(shareID: String) async throws -> PublicShareInfo {
        try await APIClient.shared.request(
            path: "/public/share/info",
            query: ["share_id": shareID],
            responseType: PublicShareInfo.self
        )
    }

    // MARK: - 验证公共分享密码
    func authPublicShare(shareID: String, password: String) async throws -> PublicShareAuthResp {
        let req = PublicShareAuthReq(shareID: shareID, password: password)
        return try await APIClient.shared.request(
            path: "/public/share/auth",
            method: .POST,
            body: req,
            responseType: PublicShareAuthResp.self
        )
    }

    // MARK: - 公共分享列表
    func listPublicShare(shareID: String, path: String, password: String? = nil, page: Int = 1, perPage: Int = 200) async throws -> FsListResp {
        struct Req: Encodable {
            let shareID: String
            let path: String
            let password: String
            let page: Int
            let perPage: Int
            enum CodingKeys: String, CodingKey {
                case path, password, page
                case shareID = "share_id"
                case perPage = "per_page"
            }
        }
        let req = Req(shareID: shareID, path: path, password: password ?? "", page: page, perPage: perPage)
        return try await APIClient.shared.request(
            path: "/public/share/list",
            method: .POST,
            body: req,
            responseType: FsListResp.self
        )
    }
}
