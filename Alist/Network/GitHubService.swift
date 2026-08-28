import Foundation

/// GitHub Release 信息
struct GitHubRelease: Codable {
    let url: String
    let htmlUrl: String
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let createdAt: Date
    let publishedAt: Date?
    let assets: [Asset]?

    enum CodingKeys: String, CodingKey {
        case url, name, body, draft, prerelease, assets
        case htmlUrl = "html_url"
        case tagName = "tag_name"
        case createdAt = "created_at"
        case publishedAt = "published_at"
    }

    struct Asset: Codable {
        let name: String
        let size: Int64
        let downloadCount: Int
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name, size
            case downloadCount = "download_count"
            case browserDownloadURL = "browser_download_url"
        }
    }

    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

/// GitHub 服务（连接外网 GitHub API）
final class GitHubService {
    static let shared = GitHubService()
    private init() {}

    private let repoOwner = "alist-org"
    private let repoName = "alist"

    /// 获取 Alist 服务端最新版本
    func latestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Alist-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    /// 获取所有版本
    func recentReleases(limit: Int = 10) async throws -> [GitHubRelease] {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=\(limit)")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Alist-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GitHubRelease].self, from: data)
    }

    /// 获取 iOS 客户端的最新版本（假设 iOS 仓库存在）
    /// 由于 iOS 客户端是独立仓库，可通过此方法检查
    func latestiOSAppRelease() async throws -> GitHubRelease? {
        // 可替换为实际的 iOS app 仓库
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Alist-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    /// 仓库主页 URL
    var repoURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)")!
    }

    /// Issues URL
    var issuesURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/issues")!
    }

    /// Releases URL
    var releasesURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
    }

    /// 文档 URL
    var docsURL: URL {
        URL(string: "https://alistgo.com/guide/")!
    }

    /// 官方网站 URL
    var officialURL: URL {
        URL(string: "https://alistgo.com")!
    }
}

/// 简化比较版本号
func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
    let parts1 = v1.split(separator: ".").compactMap { Int($0) }
    let parts2 = v2.split(separator: ".").compactMap { Int($0) }
    let maxCount = max(parts1.count, parts2.count)
    for i in 0..<maxCount {
        let p1 = i < parts1.count ? parts1[i] : 0
        let p2 = i < parts2.count ? parts2[i] : 0
        if p1 > p2 { return .orderedDescending }
        if p1 < p2 { return .orderedAscending }
    }
    return .orderedSame
}
