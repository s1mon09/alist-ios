import Foundation

/// 文件系统服务
final class FsService {
    static let shared = FsService()
    private init() {}

    // MARK: - 列表
    func list(path: String, password: String? = nil, page: Int = 1, perPage: Int = 200, refresh: Bool = false) async throws -> FsListResp {
        let req = FsListReq(path: path, password: password, page: page, perPage: perPage, refresh: refresh)
        return try await APIClient.shared.request(
            path: "/fs/list",
            method: .POST,
            body: req,
            responseType: FsListResp.self
        )
    }

    // MARK: - 详情
    func get(path: String, password: String? = nil) async throws -> FsGetResp {
        let req = FsPathReq(path: path, password: password)
        return try await APIClient.shared.request(
            path: "/fs/get",
            method: .POST,
            body: req,
            responseType: FsGetResp.self
        )
    }

    // MARK: - 目录列表（仅文件夹）
    func dirs(path: String, password: String? = nil, forceRoot: Bool = false) async throws -> [DirResp] {
        struct DirReq: Encodable {
            let path: String
            let password: String?
            let forceRoot: Bool
            enum CodingKeys: String, CodingKey {
                case path, password
                case forceRoot = "force_root"
            }
        }
        let req = DirReq(path: path, password: password, forceRoot: forceRoot)
        // dirs 接口同时支持 GET/POST，使用 POST 传 body 以支持密码
        return try await APIClient.shared.request(
            path: "/fs/dirs",
            method: .POST,
            body: req,
            responseType: [DirResp].self
        )
    }

    // MARK: - 搜索
    func search(parent: String, keywords: String, page: Int = 1, perPage: Int = 200) async throws -> SearchResp {
        let req = SearchReq(parent: parent, keywords: keywords, page: page, perPage: perPage)
        return try await APIClient.shared.request(
            path: "/fs/search",
            method: .POST,
            body: req,
            responseType: SearchResp.self
        )
    }

    // MARK: - 创建目录
    func mkdir(path: String) async throws {
        let req = FsMkdirReq(path: path)
        _ = try await APIClient.shared.request(
            path: "/fs/mkdir",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 重命名
    func rename(path: String, name: String) async throws {
        let req = FsRenameReq(path: path, name: name)
        _ = try await APIClient.shared.request(
            path: "/fs/rename",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 批量重命名
    func batchRename(srcDir: String, items: [RenameObject]) async throws {
        let req = FsBatchRenameReq(srcDir: srcDir, renameObjects: items)
        _ = try await APIClient.shared.request(
            path: "/fs/batch_rename",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 正则重命名
    func regexRename(srcDir: String, srcRegex: String, newRegex: String) async throws {
        let req = FsRegexRenameReq(srcDir: srcDir, srcNameRegex: srcRegex, newNameRegex: newRegex)
        _ = try await APIClient.shared.request(
            path: "/fs/regex_rename",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 移动
    func move(srcDir: String, dstDir: String, names: [String]) async throws {
        let req = FsMoveCopyReq(srcDir: srcDir, dstDir: dstDir, names: names)
        _ = try await APIClient.shared.request(
            path: "/fs/move",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 递归移动
    func recursiveMove(srcDir: String, dstDir: String) async throws {
        let req = FsRecursiveMoveReq(srcDir: srcDir, dstDir: dstDir)
        _ = try await APIClient.shared.request(
            path: "/fs/recursive_move",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 复制
    func copy(srcDir: String, dstDir: String, names: [String]) async throws {
        let req = FsMoveCopyReq(srcDir: srcDir, dstDir: dstDir, names: names)
        _ = try await APIClient.shared.request(
            path: "/fs/copy",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 删除
    func remove(dir: String, names: [String]) async throws {
        let req = FsRemoveReq(dir: dir, names: names)
        _ = try await APIClient.shared.request(
            path: "/fs/remove",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 删除空目录
    func removeEmptyDirectory(path: String) async throws {
        let req = FsRemoveEmptyDirReq(path: path)
        _ = try await APIClient.shared.request(
            path: "/fs/remove_empty_directory",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 获取直链（管理员）
    func link(path: String, password: String? = nil) async throws -> FsLinkResp {
        let req = FsLinkReq(path: path, password: password)
        return try await APIClient.shared.request(
            path: "/fs/link",
            method: .POST,
            body: req,
            responseType: FsLinkResp.self
        )
    }

    // MARK: - 上传（流式）
    func uploadStream(path: String, fileURL: URL, asTask: Bool = true, overwrite: Bool = true, progress: ((Double) -> Void)? = nil) async throws -> UploadResult {
        try await APIClient.shared.uploadStream(path: path, fileURL: fileURL, asTask: asTask, overwrite: overwrite, progress: progress)
    }

    // MARK: - 上传（表单）
    func uploadForm(path: String, fileURL: URL, asTask: Bool = true, overwrite: Bool = true, progress: ((Double) -> Void)? = nil) async throws -> UploadResult {
        try await APIClient.shared.uploadForm(path: path, fileURL: fileURL, asTask: asTask, overwrite: overwrite, progress: progress)
    }

    // MARK: - 归档元数据
    func archiveMeta(path: String, password: String? = nil) async throws -> ArchiveMeta {
        let req = FsPathReq(path: path, password: password)
        return try await APIClient.shared.request(
            path: "/fs/archive/meta",
            method: .POST,
            body: req,
            responseType: ArchiveMeta.self
        )
    }

    // MARK: - 归档列表
    func archiveList(path: String, password: String? = nil, page: Int = 1, perPage: Int = 200) async throws -> ArchiveListResp {
        let req = FsListReq(path: path, password: password, page: page, perPage: perPage, refresh: false)
        return try await APIClient.shared.request(
            path: "/fs/archive/list",
            method: .POST,
            body: req,
            responseType: ArchiveListResp.self
        )
    }

    // MARK: - 解压
    func decompress(srcDir: String, srcFileName: String, dstDir: String, cachePath: String = "") async throws {
        let req = ArchiveDecompressReq(srcDir: srcDir, srcFileName: srcFileName, dstDir: dstDir, cachePath: cachePath)
        _ = try await APIClient.shared.request(
            path: "/fs/archive/decompress",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }

    // MARK: - 离线下载
    func addOfflineDownload(urls: [String], path: String, tool: String, deleteFiles: Bool = false) async throws {
        let req = AddOfflineDownloadReq(urls: urls, path: path, tool: tool, deleteFiles: deleteFiles)
        _ = try await APIClient.shared.request(
            path: "/fs/add_offline_download",
            method: .POST,
            body: req,
            responseType: EmptyData.self
        )
    }
}
