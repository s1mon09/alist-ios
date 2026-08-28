import Foundation

// MARK: - 文件类型枚举
enum FileType: Int, Codable {
    case unknown = 0
    case folder = 1
    case image = 2
    case video = 3
    case audio = 4
    case text = 5
    case code = 6
    case archive = 7
    case pdf = 8
    case document = 9
    case excel = 10
    case word = 11
    case ppt = 12
    case apk = 13
    case exe = 14

    var isPreviewable: Bool {
        switch self {
        case .image, .video, .audio, .text, .code, .pdf, .document, .excel, .word, .ppt:
            return true
        default:
            return false
        }
    }

    var isMedia: Bool {
        self == .image || self == .video || self == .audio
    }
}

// MARK: - 文件标签
struct FileLabel: Codable, Identifiable, Hashable {
    var id: Int
    var type: Int?
    var name: String
    var description: String?
    var bgColor: String?
    var createTime: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, name, description
        case bgColor = "bg_color"
        case createTime = "create_time"
    }
}

// MARK: - 文件对象（列表项）
struct FileObject: Codable, Identifiable, Hashable {
    let id: String?
    let path: String?
    let parent: String?   // 搜索结果中返回的父目录
    let virtualPath: String?
    let name: String
    let size: Int64
    let isDir: Bool
    let modified: Date?
    let created: Date?
    let sign: String?
    let thumb: String?
    let type: Int
    let hashInfoStr: String?
    let storageClass: String?
    let labelList: [FileLabel]?

    enum CodingKeys: String, CodingKey {
        case id, path, parent, name, size, sign, thumb, type
        case virtualPath = "virtual_path"
        case isDir = "is_dir"
        case modified, created
        case hashInfoStr = "hashinfo"
        case storageClass = "storage_class"
        case labelList = "label_list"
    }

    var fileType: FileType {
        FileType(rawValue: type) ?? (isDir ? .folder : .unknown)
    }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    var sizeFormatted: String {
        isDir ? "—" : size.fileSizeFormatted
    }

    /// 用于显示的所在目录路径（兼容 list 和 search 结果）
    var displayParent: String {
        if let p = parent, !p.isEmpty { return p }
        if let p = path, !p.isEmpty { return p }
        if let vp = virtualPath { return (vp as NSString).deletingLastPathComponent }
        return "/"
    }

    /// 父目录路径（用于文件操作）
    var parentPath: String {
        if let p = parent, !p.isEmpty { return p }
        if let p = path, !p.isEmpty { return p }
        if let vp = virtualPath { return (vp as NSString).deletingLastPathComponent }
        return "/"
    }

    var downloadURL: String? {
        guard let vpath = virtualPath else { return nil }
        let baseURL = ServerConfig.shared.baseURL
        var url = "\(baseURL)/d\(vpath.encodedPath)"
        if let sign = sign, !sign.isEmpty {
            url += "?sign=\(sign)"
        }
        return url
    }

    var proxyURL: String? {
        guard let vpath = virtualPath else { return nil }
        let baseURL = ServerConfig.shared.baseURL
        var url = "\(baseURL)/p\(vpath.encodedPath)"
        if let sign = sign, !sign.isEmpty {
            url += "?sign=\(sign)"
        }
        return url
    }

    var thumbURL: URL? {
        guard let thumb = thumb, !thumb.isEmpty else { return nil }
        if thumb.hasPrefix("http") {
            return URL(string: thumb)
        }
        return URL(string: ServerConfig.shared.baseURL + thumb)
    }
}

// MARK: - 文件列表响应
struct FsListResp: Decodable {
    let content: [FileObject]
    let total: Int64
    let filteredTotal: Int64?
    let page: Int
    let perPage: Int
    let hasMore: Bool
    let pagesTotal: Int?
    let readme: String?
    let header: String?
    let write: Bool
    let provider: String?

    enum CodingKeys: String, CodingKey {
        case content, total, page, write, provider, readme, header
        case filteredTotal = "filtered_total"
        case perPage = "per_page"
        case hasMore = "has_more"
        case pagesTotal = "pages_total"
    }
}

// MARK: - 文件详情响应
struct FsGetResp: Decodable {
    let id: String?
    let path: String?
    let virtualPath: String?
    let name: String
    let size: Int64
    let isDir: Bool
    let modified: Date?
    let created: Date?
    let sign: String?
    let thumb: String?
    let type: Int
    let hashInfoStr: String?
    let storageClass: String?
    let rawURL: String?
    let readme: String?
    let header: String?
    let provider: String?
    let webProxy: Bool?
    let related: [FileObject]?

    enum CodingKeys: String, CodingKey {
        case id, path, name, size, sign, thumb, type, readme, header, provider, related
        case virtualPath = "virtual_path"
        case isDir = "is_dir"
        case modified, created
        case hashInfoStr = "hashinfo"
        case storageClass = "storage_class"
        case rawURL = "raw_url"
        case webProxy = "web_proxy"
    }
}

// MARK: - 目录响应
struct DirResp: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let modified: Date?

    enum CodingKeys: String, CodingKey { case name, modified }
}

// MARK: - 文件操作请求
struct FsListReq: Encodable {
    let path: String
    let password: String?
    let page: Int
    let perPage: Int
    let refresh: Bool

    enum CodingKeys: String, CodingKey {
        case path, password, page, refresh
        case perPage = "per_page"
    }
}

struct FsPathReq: Encodable {
    let path: String
    let password: String?
}

struct FsMkdirReq: Encodable {
    let path: String
}

struct FsRenameReq: Encodable {
    let path: String
    let name: String
}

struct FsBatchRenameReq: Encodable {
    let srcDir: String
    let renameObjects: [RenameObject]

    enum CodingKeys: String, CodingKey {
        case srcDir = "src_dir"
        case renameObjects = "rename_objects"
    }
}

struct RenameObject: Encodable {
    let srcName: String
    let newName: String

    enum CodingKeys: String, CodingKey {
        case srcName = "src_name"
        case newName = "new_name"
    }
}

struct FsRegexRenameReq: Encodable {
    let srcDir: String
    let srcNameRegex: String
    let newNameRegex: String

    enum CodingKeys: String, CodingKey {
        case srcDir = "src_dir"
        case srcNameRegex = "src_name_regex"
        case newNameRegex = "new_name_regex"
    }
}

struct FsMoveCopyReq: Encodable {
    let srcDir: String
    let dstDir: String
    let names: [String]
}

struct FsRecursiveMoveReq: Encodable {
    let srcDir: String
    let dstDir: String
}

struct FsRemoveReq: Encodable {
    let dir: String
    let names: [String]
}

struct FsRemoveEmptyDirReq: Encodable {
    let path: String
}

struct FsLinkReq: Encodable {
    let path: String
    let password: String?
}

// MARK: - 文件直链响应（/fs/link）
struct FsLinkResp: Decodable {
    let name: String?
    let url: String
    let provider: String?
    let related: [FileObject]?
}
