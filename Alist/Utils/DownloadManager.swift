import Foundation
import SwiftUI
import Combine

// MARK: - 下载状态
enum DownloadState: String, Codable {
    case pending        // 等待中
    case downloading    // 下载中
    case paused         // 已暂停
    case completed      // 已完成
    case failed         // 失败
    case canceled       // 已取消

    var color: Color {
        switch self {
        case .pending: return .gray
        case .downloading: return Theme.primary
        case .paused: return .orange
        case .completed: return Theme.success
        case .failed: return Theme.danger
        case .canceled: return .gray
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle"
        case .canceled: return "slash.circle"
        }
    }
}

// MARK: - 下载记录
struct DownloadRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let fileName: String
    let remoteURL: String
    let localPath: String
    var fileSize: Int64
    var downloadedBytes: Int64
    var state: DownloadState
    var errorMessage: String?
    let createdAt: Date
    var completedAt: Date?
    let sourcePath: String?  // Alist 服务端文件路径

    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(downloadedBytes) / Double(fileSize)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }

    var localURL: URL {
        URL(fileURLWithPath: localPath)
    }

    var downloadSpeed: Double = 0
}

// MARK: - 线程安全的共享状态容器（供 nonisolated delegate 访问）
final class DownloadSharedState: @unchecked Sendable {
    private let lock = NSLock()
    private var _taskIDMap: [Int: UUID] = [:]
    private var _downloadCache: [UUID: DownloadManager.DownloadCacheEntry] = [:]

    func taskIDMap(_ taskIdentifier: Int) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        return _taskIDMap[taskIdentifier]
    }
    func cacheEntry(_ id: UUID) -> DownloadManager.DownloadCacheEntry? {
        lock.lock(); defer { lock.unlock() }
        return _downloadCache[id]
    }
    func setTaskMapping(_ taskIdentifier: Int, _ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        _taskIDMap[taskIdentifier] = id
    }
    func setCacheEntry(_ id: UUID, _ entry: DownloadManager.DownloadCacheEntry) {
        lock.lock(); defer { lock.unlock() }
        _downloadCache[id] = entry
    }
    func removeTaskMapping(_ taskIdentifier: Int) {
        lock.lock(); defer { lock.unlock() }
        _taskIDMap.removeValue(forKey: taskIdentifier)
    }
    func removeCacheEntry(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        _downloadCache.removeValue(forKey: id)
    }
    func removeMappingByRecordID(_ recordID: UUID) {
        lock.lock(); defer { lock.unlock() }
        if let tid = _taskIDMap.first(where: { $0.value == recordID })?.key {
            _taskIDMap.removeValue(forKey: tid)
        }
    }
}

// MARK: - 下载管理器
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloads: [DownloadRecord] = []
    @Published var showDownloadsBadge: Bool = false

    private var session: URLSession!
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private var lastBytes: [UUID: Int64] = [:]
    private var lastTime: [UUID: Date] = [:]

    // 线程安全的共享状态容器（nonisolated，可从 delegate 上下文访问）
    private let sharedState = DownloadSharedState()

    struct DownloadCacheEntry {
        let localURL: URL
        let fileName: String
        var fileSize: Int64
    }

    // 从非隔离上下文安全访问
    nonisolated func taskIDMapFor(_ taskIdentifier: Int) -> UUID? {
        sharedState.taskIDMap(taskIdentifier)
    }
    nonisolated func cacheEntryFor(_ id: UUID) -> DownloadCacheEntry? {
        sharedState.cacheEntry(id)
    }
    nonisolated func removeTaskMapping(_ taskIdentifier: Int) {
        sharedState.removeTaskMapping(taskIdentifier)
    }
    nonisolated func removeCacheEntry(_ id: UUID) {
        sharedState.removeCacheEntry(id)
    }
    private func setTaskMapping(_ taskIdentifier: Int, _ id: UUID) {
        sharedState.setTaskMapping(taskIdentifier, id)
    }
    private func setCacheEntry(_ id: UUID, _ entry: DownloadCacheEntry) {
        sharedState.setCacheEntry(id, entry)
    }

    private let archiveURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("downloads.json")
    }()

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.alist.ios.background.download")
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.httpMaximumConnectionsPerHost = 5
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 0  // 不超时
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadRecords()
    }

    // MARK: - 持久化
    private func loadRecords() {
        guard let data = try? Data(contentsOf: archiveURL),
              let records = try? JSONDecoder().decode([DownloadRecord].self, from: data) else { return }
        // 重置未完成状态
        downloads = records.map { record in
            var r = record
            if r.state == .downloading || r.state == .pending {
                r.state = .paused
                r.downloadedBytes = 0
            }
            return r
        }
    }

    private func saveRecords() {
        let copy = downloads.map { record -> DownloadRecord in
            var r = record
            r.downloadSpeed = 0  // 不持久化速度
            return r
        }
        if let data = try? JSONEncoder().encode(copy) {
            try? data.write(to: archiveURL, options: .atomic)
        }
    }

    // MARK: - 公共接口
    func addDownload(file: FileObject, remoteURL: URL) {
        // 避免重复添加
        if downloads.contains(where: { $0.remoteURL == remoteURL.absoluteString && $0.state != .canceled }) {
            ToastManager.shared.show("已在下载列表中", type: .info)
            return
        }

        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        // 处理重名
        var destURL = downloadsDir.appendingPathComponent(file.name)
        if FileManager.default.fileExists(atPath: destURL.path) {
            let name = (file.name as NSString).deletingPathExtension
            let ext = (file.name as NSString).pathExtension
            let suffix = ext.isEmpty ? "" : ".\(ext)"
            destURL = downloadsDir.appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970))\(suffix)")
        }

        let record = DownloadRecord(
            id: UUID(),
            fileName: file.name,
            remoteURL: remoteURL.absoluteString,
            localPath: destURL.path,
            fileSize: file.size,
            downloadedBytes: 0,
            state: .pending,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: nil,
            sourcePath: file.virtualPath
        )
        downloads.insert(record, at: 0)
        saveRecords()
        startDownload(recordID: record.id)
        ToastManager.shared.show("已添加到下载队列", type: .success)
    }

    func addDownload(fileName: String, remoteURL: URL, fileSize: Int64 = 0, sourcePath: String? = nil) {
        if downloads.contains(where: { $0.remoteURL == remoteURL.absoluteString && $0.state != .canceled }) {
            ToastManager.shared.show("已在下载列表中", type: .info)
            return
        }

        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        var destURL = downloadsDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destURL.path) {
            let name = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            let suffix = ext.isEmpty ? "" : ".\(ext)"
            destURL = downloadsDir.appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970))\(suffix)")
        }

        let record = DownloadRecord(
            id: UUID(),
            fileName: fileName,
            remoteURL: remoteURL.absoluteString,
            localPath: destURL.path,
            fileSize: fileSize,
            downloadedBytes: 0,
            state: .pending,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: nil,
            sourcePath: sourcePath
        )
        downloads.insert(record, at: 0)
        saveRecords()
        startDownload(recordID: record.id)
        ToastManager.shared.show("已添加到下载队列", type: .success)
    }

    func startDownload(recordID: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == recordID }) else { return }
        guard downloads[index].state != .downloading else { return }

        guard let url = URL(string: downloads[index].remoteURL) else {
            downloads[index].state = .failed
            downloads[index].errorMessage = "无效的 URL"
            saveRecords()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = ServerConfig.shared.token
        if !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.setValue("Alist-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(generateClientID(), forHTTPHeaderField: "Client-Id")

        let task = session.downloadTask(with: request)
        tasks[recordID] = task
        // 线程安全缓存映射和文件信息
        setTaskMapping(task.taskIdentifier, recordID)
        setCacheEntry(recordID, DownloadCacheEntry(
            localURL: URL(fileURLWithPath: downloads[index].localPath),
            fileName: downloads[index].fileName,
            fileSize: downloads[index].fileSize
        ))
        downloads[index].state = .downloading
        downloads[index].errorMessage = nil
        lastBytes[recordID] = 0
        lastTime[recordID] = Date()
        saveRecords()
        task.resume()
    }

    func pauseDownload(recordID: UUID) {
        guard let task = tasks[recordID] else {
            // 如果没有 task 但状态是 downloading，可能是 app 重启后
            if let idx = downloads.firstIndex(where: { $0.id == recordID }), downloads[idx].state == .downloading {
                downloads[idx].state = .paused
                saveRecords()
            }
            return
        }
        task.cancel { resumeData in
            if let data = resumeData {
                let resumeURL = FileManager.default.temporaryDirectory.appendingPathComponent("resume_\(recordID.uuidString).data")
                try? data.write(to: resumeURL)
            }
            Task { @MainActor in
                if let idx = self.downloads.firstIndex(where: { $0.id == recordID }) {
                    self.downloads[idx].state = .paused
                    self.saveRecords()
                }
            }
        }
        tasks[recordID] = nil
        sharedState.removeMappingByRecordID(recordID)
    }

    func resumeDownload(recordID: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == recordID }) else { return }
        guard downloads[index].state == .paused || downloads[index].state == .failed else { return }

        let resumeURL = FileManager.default.temporaryDirectory.appendingPathComponent("resume_\(recordID.uuidString).data")
        var task: URLSessionDownloadTask?
        if FileManager.default.fileExists(atPath: resumeURL.path),
           let resumeData = try? Data(contentsOf: resumeURL) {
            task = session.downloadTask(withResumeData: resumeData)
            try? FileManager.default.removeItem(at: resumeURL)
        } else {
            guard let url = URL(string: downloads[index].remoteURL) else {
                downloads[index].state = .failed
                downloads[index].errorMessage = "无效的 URL"
                saveRecords()
                return
            }
            var request = URLRequest(url: url)
            let token = ServerConfig.shared.token
            if !token.isEmpty {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            }
            request.setValue("Alist-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue(generateClientID(), forHTTPHeaderField: "Client-Id")
            task = session.downloadTask(with: request)
        }

        guard let downloadTask = task else { return }
        tasks[recordID] = downloadTask
        setTaskMapping(downloadTask.taskIdentifier, recordID)
        setCacheEntry(recordID, DownloadCacheEntry(
            localURL: URL(fileURLWithPath: downloads[index].localPath),
            fileName: downloads[index].fileName,
            fileSize: downloads[index].fileSize
        ))
        downloads[index].state = .downloading
        downloads[index].errorMessage = nil
        lastBytes[recordID] = downloads[index].downloadedBytes
        lastTime[recordID] = Date()
        saveRecords()
        downloadTask.resume()
    }

    func cancelDownload(recordID: UUID) {
        if let task = tasks[recordID] {
            task.cancel()
            tasks[recordID] = nil
            sharedState.removeMappingByRecordID(recordID)
            sharedState.removeCacheEntry(recordID)
        }
        if let idx = downloads.firstIndex(where: { $0.id == recordID }) {
            downloads[idx].state = .canceled
            // 清理已下载的部分文件
            try? FileManager.default.removeItem(atPath: downloads[idx].localPath)
            saveRecords()
        }
        // 清除 resumeData
        let resumeURL = FileManager.default.temporaryDirectory.appendingPathComponent("resume_\(recordID.uuidString).data")
        try? FileManager.default.removeItem(at: resumeURL)
    }

    func removeRecord(recordID: UUID) {
        cancelDownload(recordID: recordID)
        downloads.removeAll { $0.id == recordID }
        saveRecords()
    }

    func clearCompleted() {
        downloads.removeAll { $0.state == .completed || $0.state == .canceled }
        saveRecords()
    }

    /// 清空所有下载记录并取消进行中的任务（用于设置页清理）
    func clearAll() {
        // 取消所有进行中的任务
        let activeIDs = downloads.filter { $0.state == .downloading || $0.state == .pending || $0.state == .paused }.map { $0.id }
        for id in activeIDs {
            cancelDownload(recordID: id)
        }
        downloads.removeAll()
        saveRecords()
    }

    // MARK: - 工具方法
    private func generateClientID() -> String {
        if let id = UserDefaults.standard.string(forKey: "client_id") {
            return id
        }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(id, forKey: "client_id")
        return id
    }

    var activeDownloadsCount: Int {
        downloads.filter { $0.state == .downloading || $0.state == .pending }.count
    }

    var hasActiveDownloads: Bool {
        activeDownloadsCount > 0
    }

    // 处理后台下载完成（从 AppDelegate 调用）
    func handleBackgroundDownloadComplete() {
        // 触发 UI 更新
        objectWillChange.send()
        // 通知 AppDelegate 调用系统完成回调
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.invokeBackgroundCompletionHandler()
        }
    }
}

// MARK: - URLSessionDelegate
extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 临时 URL 仅在 delegate 方法执行期间有效，必须同步移动文件
        guard let recordID = taskIDMapFor(downloadTask.taskIdentifier) else { return }
        guard let cached = cacheEntryFor(recordID) else { return }

        let destURL = cached.localURL
        var fileSize: Int64 = cached.fileSize

        // 同步移动文件（FileManager 线程安全）
        do {
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: location, to: destURL)
            // 实际文件大小
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path),
               let size = attrs[.size] as? Int64 {
                fileSize = size
            }
        } catch {
            // 移动失败 - 尝试复制
            do {
                try FileManager.default.copyItem(at: location, to: destURL)
            } catch {
                Task { @MainActor in
                    if let idx = self.downloads.firstIndex(where: { $0.id == recordID }) {
                        self.downloads[idx].state = .failed
                        self.downloads[idx].errorMessage = "保存文件失败: \(error.localizedDescription)"
                        self.saveRecords()
                    }
                    self.removeTaskMapping(downloadTask.taskIdentifier)
                    self.removeCacheEntry(recordID)
                }
                return
            }
        }

        // 通过 Task 更新 @MainActor 状态
        Task { @MainActor in
            if let idx = self.downloads.firstIndex(where: { $0.id == recordID }) {
                self.downloads[idx].state = .completed
                self.downloads[idx].completedAt = Date()
                self.downloads[idx].downloadedBytes = fileSize > 0 ? fileSize : self.downloads[idx].fileSize
                if fileSize > 0 { self.downloads[idx].fileSize = fileSize }
                self.saveRecords()
                HapticManager.success()
                ToastManager.shared.show("下载完成: \(self.downloads[idx].fileName)", type: .success)
            }
            self.tasks[recordID] = nil
            self.removeTaskMapping(downloadTask.taskIdentifier)
            self.removeCacheEntry(recordID)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let recordID = taskIDMapFor(downloadTask.taskIdentifier) else { return }

        Task { @MainActor in
            guard let index = self.downloads.firstIndex(where: { $0.id == recordID }) else { return }
            self.downloads[index].downloadedBytes = totalBytesWritten
            if totalBytesExpectedToWrite > 0 {
                self.downloads[index].fileSize = totalBytesExpectedToWrite
            }

            // 计算速度
            let now = Date()
            if let lastBytes = self.lastBytes[recordID], let lastTime = self.lastTime[recordID] {
                let timeDiff = now.timeIntervalSince(lastTime)
                if timeDiff > 0.5 {
                    let bytesDiff = Double(totalBytesWritten - lastBytes)
                    let speed = bytesDiff / timeDiff
                    self.downloads[index].downloadSpeed = speed
                    self.lastBytes[recordID] = totalBytesWritten
                    self.lastTime[recordID] = now
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        guard let recordID = taskIDMapFor(downloadTask.taskIdentifier) else { return }

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == recordID }) {
                self.downloads[index].downloadedBytes = fileOffset
                if expectedTotalBytes > 0 {
                    self.downloads[index].fileSize = expectedTotalBytes
                }
                self.lastBytes[recordID] = fileOffset
                self.lastTime[recordID] = Date()
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }  // 无错误时由 download delegate 处理

        guard let recordID = taskIDMapFor(task.taskIdentifier) else { return }

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.id == recordID }) {
                let nsError = error as NSError
                if nsError.code == NSURLErrorCancelled {
                    // 取消可能是用户主动操作，状态已处理
                } else {
                    self.downloads[index].state = .failed
                    self.downloads[index].errorMessage = error.localizedDescription
                    self.saveRecords()
                    ToastManager.shared.show("下载失败: \(self.downloads[index].fileName)", type: .error)
                }
            }
            self.tasks[recordID] = nil
            self.removeTaskMapping(task.taskIdentifier)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.handleBackgroundDownloadComplete()
        }
    }
}
