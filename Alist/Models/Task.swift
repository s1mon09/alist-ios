import Foundation

// MARK: - 任务状态
enum TaskState: String, Codable {
    case pending = "PENDING"
    case running = "RUNNING"
    case canceling = "CANCELING"
    case canceled = "CANCELED"
    case errored = "ERRORED"
    case failing = "FAILING"
    case waitingRetry = "WAITING_RETRY"
    case beforeRetry = "BEFORE_RETRY"
    case failed = "FAILED"
    case succeeded = "SUCCEEDED"

    var color: String {
        switch self {
        case .pending, .waitingRetry, .beforeRetry: return "orange"
        case .running: return "blue"
        case .canceling: return "orange"
        case .canceled: return "gray"
        case .errored, .failing, .failed: return "red"
        case .succeeded: return "green"
        }
    }

    var isDone: Bool {
        self == .canceled || self == .failed || self == .succeeded
    }
}

// MARK: - 任务类型
enum TaskType: String, CaseIterable, Identifiable {
    case upload = "upload"
    case copy = "copy"
    case offlineDownload = "offline_download"
    case offlineDownloadTransfer = "offline_download_transfer"
    case s3Transition = "s3_transition"
    case decompress = "decompress"
    case decompressUpload = "decompress_upload"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upload: return "上传"
        case .copy: return "复制"
        case .offlineDownload: return "离线下载"
        case .offlineDownloadTransfer: return "离线下载转存"
        case .s3Transition: return "S3 转换"
        case .decompress: return "解压"
        case .decompressUpload: return "解压上传"
        }
    }

    var icon: String {
        switch self {
        case .upload: return "arrow.up.circle"
        case .copy: return "doc.on.doc"
        case .offlineDownload, .offlineDownloadTransfer: return "arrow.down.circle"
        case .s3Transition: return "externaldrive"
        case .decompress, .decompressUpload: return "archivebox"
        }
    }
}

// MARK: - 任务信息
struct TaskInfo: Codable, Identifiable {
    let id: String
    let name: String
    let creator: String
    let creatorRole: Roles?
    let state: String
    let status: String
    let progress: Double
    let startTime: Date?
    let endTime: Date?
    let totalBytes: Int64?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, creator, state, status, progress, error
        case creatorRole = "creator_role"
        case startTime = "start_time"
        case endTime = "end_time"
        case totalBytes = "total_bytes"
    }

    var taskState: TaskState {
        TaskState(rawValue: state) ?? .pending
    }

    var progressPercent: Int {
        Int(progress)
    }
}

// MARK: - 离线下载请求
struct AddOfflineDownloadReq: Encodable {
    let urls: [String]
    let path: String
    let tool: String
    let deleteFiles: Bool

    enum CodingKeys: String, CodingKey {
        case urls, path, tool
        case deleteFiles = "delete_files"
    }
}
