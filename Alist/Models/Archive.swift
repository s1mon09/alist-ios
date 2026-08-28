import Foundation

// MARK: - 归档（压缩包）元数据
struct ArchiveMeta: Decodable {
    let comment: String?
    let encoded: Bool?
    let names: [String]?
}

// MARK: - 归档列表响应
struct ArchiveListResp: Decodable {
    let content: [ArchiveEntry]
    let total: Int64

    struct ArchiveEntry: Decodable, Identifiable {
        var id: String { name }
        let name: String
        let size: Int64?
        let isDir: Bool?
        let modified: Date?

        enum CodingKeys: String, CodingKey {
            case name, size, modified
            case isDir = "is_dir"
        }
    }
}

// MARK: - 解压请求
struct ArchiveDecompressReq: Encodable {
    let srcDir: String
    let srcFileName: String
    let dstDir: String
    let cachePath: String

    enum CodingKeys: String, CodingKey {
        case srcDir = "src_dir"
        case srcFileName = "src_file_name"
        case dstDir = "dst_dir"
        case cachePath = "cache_path"
    }
}
