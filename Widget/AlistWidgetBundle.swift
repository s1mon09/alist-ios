import WidgetKit
import SwiftUI

// MARK: - 轻量下载模型（与主 App DownloadRecord 的 JSON 字段兼容）
struct WidgetDownload: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let downloadedBytes: Int64
    let state: String

    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(downloadedBytes) / Double(fileSize)
    }

    var progressPercent: Int { Int(progress * 100) }
}

// MARK: - 共享数据读取
enum SharedStore {
    static let groupID = "group.com.s1mon09.alist"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    static var baseURL: String {
        defaults?.string(forKey: "shared_server_url") ?? ""
    }

    static var token: String {
        defaults?.string(forKey: "shared_token") ?? ""
    }

    static func loadDownloads() -> [WidgetDownload] {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("downloads.json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WidgetDownload].self, from: data)) ?? []
    }
}

// MARK: - 下载进度小组件
struct DownloadsEntry: TimelineEntry {
    let date: Date
    let baseURL: String
    let active: [WidgetDownload]   // 进行中/等待/暂停
    let recentDone: Int            // 最近完成的数量
}

struct DownloadsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DownloadsEntry {
        DownloadsEntry(date: Date(), baseURL: "", active: [], recentDone: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (DownloadsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadsEntry>) -> Void) {
        // 每 5 分钟刷新一次
        let next = Date(timeIntervalSinceNow: 300)
        completion(Timeline(entries: [loadEntry()], policy: .after(next)))
    }

    private func loadEntry() -> DownloadsEntry {
        let all = SharedStore.loadDownloads()
        let active = all
            .filter { $0.state == "downloading" || $0.state == "pending" || $0.state == "paused" }
            .prefix(4)
        let done = all.filter { $0.state == "completed" }.count
        return DownloadsEntry(
            date: Date(),
            baseURL: SharedStore.baseURL,
            active: Array(active),
            recentDone: done
        )
    }
}

struct DownloadsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DownloadsEntry

    private var appURL: URL {
        URL(string: "alistios://downloads") ?? URL(string: "https://github.com/s1mon09/alist-ios")!
    }

    var body: some View {
        content
            .widgetURL(appURL)
            .containerBackgroundCompat()
    }

    @ViewBuilder
    private var content: some View {
        if entry.baseURL.isEmpty {
            emptyState(text: "请先在 Alist App 中登录服务器")
        } else if entry.active.isEmpty {
            emptyState(text: "暂无进行中的下载\n共 \(entry.recentDone) 个已完成")
        } else if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                Label("下载中", systemImage: "arrow.down.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer(minLength: 0)
                if let first = entry.active.first {
                    Text(first.fileName)
                        .font(.caption2.weight(.medium))
                        .lineLimit(2)
                    ProgressView(value: first.progress)
                        .tint(.blue)
                    Text("\(first.progressPercent)% · 共 \(entry.active.count) 个任务")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("下载中", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("\(entry.active.count) 个任务")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(entry.active.prefix(3)) { item in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.fileName)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                            ProgressView(value: item.progress)
                                .tint(stateColor(item.state))
                        }
                        Text("\(item.progressPercent)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 32, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "downloading": return .blue
        case "paused": return .orange
        case "pending": return .gray
        default: return .blue
        }
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlistDownloadsWidget", provider: DownloadsProvider()) { entry in
            DownloadsWidgetView(entry: entry)
        }
        .configurationDisplayName("下载进度")
        .description("查看 Alist 后台下载任务的实时进度。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 服务器状态小组件
struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let baseURL: String
    let online: Bool?
    let version: String?
    let siteTitle: String?
}

struct ServerStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(date: Date(), baseURL: "", online: nil, version: nil, siteTitle: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        loadEntry { completion($0) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        loadEntry { entry in
            completion(Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 900))))
        }
    }

    private func loadEntry(_ completion: @escaping (ServerStatusEntry) -> Void) {
        let base = SharedStore.baseURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/public/settings") else {
            completion(ServerStatusEntry(date: Date(), baseURL: base, online: nil, version: nil, siteTitle: nil))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, _, error in
            var online: Bool?
            var version: String?
            var title: String?
            if error == nil, let data = data,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = obj["code"] as? Int, code == 200,
               let d = obj["data"] as? [String: Any] {
                online = true
                version = d["version"] as? String
                title = d["site_title"] as? String
            } else if error != nil {
                online = false
            }
            completion(ServerStatusEntry(date: Date(), baseURL: base, online: online, version: version, siteTitle: title))
        }.resume()
    }
}

struct ServerStatusWidgetView: View {
    let entry: ServerStatusEntry

    private var appURL: URL {
        URL(string: "alistios://open") ?? URL(string: "https://github.com/s1mon09/alist-ios")!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(entry.siteTitle ?? "Alist 服务器")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(entry.baseURL.isEmpty ? "未配置服务器" : hostOf(entry.baseURL))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let version = entry.version {
                Text("版本 \(version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(appURL)
        .containerBackgroundCompat()
    }

    private var statusColor: Color {
        switch entry.online {
        case .some(true): return .green
        case .some(false): return .red
        case nil: return .gray
        }
    }

    private func hostOf(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}

struct ServerStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlistServerStatusWidget", provider: ServerStatusProvider()) { entry in
            ServerStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("服务器状态")
        .description("快速查看 Alist 服务器是否在线。")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - iOS 17 containerBackground 兼容（iOS 16 直接使用背景色）
extension View {
    @ViewBuilder
    func containerBackgroundCompat() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        } else {
            background(Color(uiColor: .systemBackground))
        }
    }
}

// MARK: - WidgetBundle 入口
@main
struct AlistWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadsWidget()
        ServerStatusWidget()
    }
}
