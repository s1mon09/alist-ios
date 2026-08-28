import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @AppStorage("appearance_mode") var appearanceMode = "system"
    @AppStorage("preview_on_tap") var previewOnTap = true
    @AppStorage("show_hidden_files") var showHiddenFiles = false
    @AppStorage("list_page_size") var listPageSize = 200
    @AppStorage("enable_haptic") var enableHaptic = true
    @AppStorage("wifi_only_upload") var wifiOnlyUpload = false
    @AppStorage("wifi_only_download") var wifiOnlyDownload = false

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("主题模式", selection: $appearanceMode) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                }

                Section("文件浏览") {
                    Toggle("点击预览文件", isOn: $previewOnTap)
                    Toggle("显示隐藏文件", isOn: $showHiddenFiles)
                    Picker("每页加载数量", selection: $listPageSize) {
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text("500").tag(500)
                    }
                }

                Section("网络") {
                    Toggle("仅 WiFi 上传", isOn: $wifiOnlyUpload)
                    Toggle("仅 WiFi 下载", isOn: $wifiOnlyDownload)
                }

                Section("交互") {
                    Toggle("触觉反馈", isOn: $enableHaptic)
                }

                Section("服务器") {
                    LabeledContent("服务器地址", value: appState.serverURL.isEmpty ? "未设置" : appState.serverURL)
                    Button {
                        appState.logout()
                    } label: {
                        Label("清除登录信息", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                Section("存储") {
                    Button {
                        clearCache()
                    } label: {
                        Label("清除缓存", systemImage: "trash.circle")
                    }
                    Button {
                        clearDownloads()
                    } label: {
                        Label("清理下载文件", systemImage: "arrow.down.circle.dotted")
                    }
                }

                Section("关于与更新") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于应用", systemImage: "info.circle")
                    }
                    Button {
                        Task { await checkServerVersion() }
                    } label: {
                        Label("检查服务器版本更新", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink {
                        GitHubReleasesView()
                    } label: {
                        Label("GitHub Releases", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        ToastManager.shared.show("缓存已清除", type: .success)
    }

    private func clearDownloads() {
        // 先取消所有进行中的下载，再清理文件，避免与 DownloadManager 冲突
        DownloadManager.shared.clearAll()
        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloadsDir.path) {
            try? FileManager.default.removeItem(at: downloadsDir)
            try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        }
        ToastManager.shared.show("下载文件已清理", type: .success)
    }

    private func checkServerVersion() async {
        do {
            let release = try await GitHubService.shared.latestRelease()
            let currentVersion = appState.publicSettings?.version ?? "未知"
            let result = compareVersions(release.version, currentVersion)
            await MainActor.run {
                switch result {
                case .orderedDescending:
                    ToastManager.shared.show("发现新版本: \(release.tagName)（当前 \(currentVersion)）", type: .warning)
                case .orderedSame:
                    ToastManager.shared.show("已是最新版本 \(currentVersion)", type: .success)
                case .orderedAscending:
                    ToastManager.shared.show("当前版本 \(currentVersion) 较新", type: .info)
                }
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.show("检查更新失败: \(error.localizedDescription)", type: .error)
            }
        }
    }
}

// MARK: - GitHub Releases 列表
struct GitHubReleasesView: View {
    @State private var releases: [GitHubRelease] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && releases.isEmpty {
                LoadingView(message: "加载 GitHub Releases...")
            } else if let error = errorMessage {
                ErrorStateView(message: error) {
                    Task { await loadReleases() }
                }
            } else {
                List(releases, id: \.tagName) { release in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(release.tagName)
                                .font(.headline)
                            if release.prerelease {
                                Text("预发布")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text(release.publishedAt?.formatted ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let name = release.name, !name.isEmpty, name != release.tagName {
                            Text(name).font(.subheadline)
                        }
                        if let body = release.body, !body.isEmpty {
                            Text(body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }
                        if let assets = release.assets, !assets.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(assets, id: \.name) { asset in
                                    Link(destination: URL(string: asset.browserDownloadURL)!) {
                                        HStack {
                                            Image(systemName: "arrow.down.doc")
                                                .font(.caption)
                                            Text(asset.name)
                                                .font(.caption)
                                            Spacer()
                                            Text(asset.size.fileSizeFormatted)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        Link(destination: URL(string: release.htmlUrl)!) {
                            Label("在 GitHub 中查看", systemImage: "safari")
                                .font(.caption)
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Releases")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadReleases() }
        .task { await loadReleases() }
    }

    private func loadReleases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            releases = try await GitHubService.shared.recentReleases(limit: 15)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 会话管理
struct SessionListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var sessions: [Session] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: session.active == true ? "iphone" : "iphone.slash")
                                .foregroundStyle(session.active == true ? .green : .gray)
                            Text(session.userAgent ?? "未知设备").font(.subheadline).lineLimit(1)
                            Spacer()
                            if session.active == true {
                                Text("当前").font(.caption).foregroundStyle(.green)
                            }
                        }
                        if let ip = session.ip {
                            Text("IP: \(ip)").font(.caption).foregroundStyle(.secondary)
                        }
                        if let lastActive = session.lastActive {
                            Text("最后活跃: \(lastActive.formatted)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        if session.active != true {
                            Button(role: .destructive) {
                                Task {
                                    if let id = session.deviceID {
                                        try? await SessionService.shared.evictMySession(deviceKey: id)
                                        await loadSessions()
                                    }
                                }
                            } label: { Label("注销", systemImage: "trash") }
                        }
                    }
                }
            }
            .navigationTitle("会话管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .task { await loadSessions() }
    }

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await SessionService.shared.mySessions()
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }
}

// MARK: - SSH 公钥管理
struct SSHKeyListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var keys: [SSHPublicKey] = []
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(keys) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key.name).font(.subheadline)
                        Text(key.publicKey).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        if let fp = key.fingerprint {
                            Text("指纹: \(fp)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task {
                                try? await SSHKeyService.shared.deleteMyKey(id: key.id)
                                await loadKeys()
                            }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("SSH 公钥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .overlay {
                if keys.isEmpty {
                    EmptyStateView(icon: "key", title: "暂无 SSH 公钥", message: "点击右上角添加")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSSHKeyView { await loadKeys() }
            }
        }
        .task { await loadKeys() }
    }

    private func loadKeys() async {
        do {
            keys = try await SSHKeyService.shared.listMyKeys()
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }
}

struct AddSSHKeyView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var publicKey = ""
    @State private var isLoading = false
    let onAdded: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("公钥名称", text: $name)
                }
                Section("公钥") {
                    TextEditor(text: $publicKey)
                        .frame(height: 120)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle("添加 SSH 公钥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                try await SSHKeyService.shared.addMyKey(name: name, publicKey: publicKey)
                                await onAdded()
                                await MainActor.run {
                                    ToastManager.shared.show("已添加", type: .success)
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    ToastManager.shared.show(error.localizedDescription, type: .error)
                                }
                            }
                        }
                    }
                    .disabled(name.isEmpty || publicKey.isEmpty || isLoading)
                }
            }
        }
    }
}
