import SwiftUI
import QuickLook

// MARK: - 公共分享浏览器
struct PublicShareBrowserView: View {
    @Environment(\.dismiss) var dismiss
    @State private var shareIDInput = ""
    @State private var passwordInput = ""
    @State private var isLoading = false
    @State private var shareInfo: PublicShareInfo?
    @State private var authedShareID: String?
    @State private var authedPassword: String?
    @State private var currentPath = ""
    @State private var pathHistory: [String] = [""]
    @State private var files: [FileObject] = []
    @State private var isLoadingFiles = false
    @State private var errorMessage: String?
    @State private var previewURL: URL?
    @State private var downloadingFile: FileObject?

    var body: some View {
        NavigationStack {
            Group {
                if let info = shareInfo, authedShareID != nil {
                    shareContentView(info: info)
                } else if let info = shareInfo, info.expired {
                    // 过期分享：显示信息头 + 错误
                    expiredShareView(info: info)
                } else {
                    enterShareIDView
                }
            }
            .navigationTitle("公共分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                if shareInfo != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            resetState()
                        } label: {
                            Image(systemName: "arrow.uturn.left")
                        }
                    }
                }
            }
            .quickLookPreview($previewURL)
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
    }

    // MARK: - 过期分享视图
    private func expiredShareView(info: PublicShareInfo) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("分享已过期")
                .font(.headline)
            Text(info.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("返回") { resetState() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 输入分享ID视图
    private var enterShareIDView: some View {
        Form {
            Section {
                TextField("分享ID", text: $shareIDInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("访问密码（如需）", text: $passwordInput)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("访问分享")
            } footer: {
                Text("输入分享链接末尾的分享ID，例如：https://example.com/s/abc123 中的 abc123")
            }

            Section {
                Button {
                    Task { await loadShareInfo() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Text("访问")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .disabled(shareIDInput.isEmpty || isLoading)

                Link(destination: URL(string: "https://alistgo.com/guide/")!) {
                    Label("了解分享功能", systemImage: "questionmark.circle")
                }
            }
        }
        .overlay {
            if isLoading {
                LoadingView(message: "正在加载分享...")
            }
        }
    }

    // MARK: - 分享内容视图
    private func shareContentView(info: PublicShareInfo) -> some View {
        VStack(spacing: 0) {
            // 分享信息头
            HStack(spacing: 12) {
                Image(systemName: info.isDir ? "folder.fill" : "doc.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name).font(.subheadline.bold())
                    HStack(spacing: 6) {
                        if info.burnAfterRead {
                            Label("阅后即焚", systemImage: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if info.hasPassword {
                            Label("受密码保护", systemImage: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if info.expired {
                            Label("已过期", systemImage: "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        Label("剩余 \(info.remaining) 次", systemImage: "eye")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let exp = info.expiresAt {
                        Text("过期时间: \(exp.formatted)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Theme.secondaryBackground.opacity(0.5))

            // 面包屑
            BreadcrumbView(currentPath: currentPath.isEmpty ? "/" : currentPath) { target in
                HapticManager.light()
                if target == "/" {
                    currentPath = ""
                    pathHistory = [""]
                } else {
                    let targetRel = target.removingPrefix("/")
                    currentPath = targetRel
                    while pathHistory.last != targetRel && !pathHistory.isEmpty {
                        pathHistory.removeLast()
                    }
                    if pathHistory.last != targetRel {
                        pathHistory.append(targetRel)
                    }
                }
                Task { await loadFiles() }
            }
            .padding(.horizontal)

            // 文件列表
            if isLoadingFiles {
                LoadingView(message: "加载文件中...")
            } else if let error = errorMessage {
                ErrorStateView(message: error) {
                    Task { await loadFiles() }
                }
            } else if files.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "空文件夹",
                    message: "此目录无可见文件"
                )
            } else {
                List {
                    ForEach(files) { file in
                        Button {
                            handleFileTap(file)
                        } label: {
                            shareFileRow(file)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func shareFileRow(_ file: FileObject) -> some View {
        HStack(spacing: 12) {
            if file.isDir {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.fileColor(for: .folder))
            } else if let thumbURL = file.thumbURL, file.fileType == .image {
                AsyncImage(url: thumbURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.secondaryBackground)
                        .overlay { Image(systemName: "photo") }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: Theme.fileIcon(for: file.fileType))
                    .font(.title2)
                    .foregroundStyle(Theme.fileColor(for: file.fileType))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(file.sizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let modified = file.modified {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(modified.relativeFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if !file.isDir && info_allowDownload {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var info_allowDownload: Bool {
        shareInfo?.allowDownload ?? false
    }

    // MARK: - 操作
    private func handleOpenURL(_ url: URL) {
        // 处理 alist://share/{id} 或 https://.../s/{id}
        if url.pathComponents.count >= 2 {
            shareIDInput = url.pathComponents.last ?? ""
            Task { await loadShareInfo() }
        }
    }

    private func loadShareInfo() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await PublicService.shared.getPublicShareInfo(shareID: shareIDInput)
            shareInfo = info
            if info.expired {
                errorMessage = "分享已过期"
                return
            }
            if !info.hasPassword {
                authedShareID = shareIDInput
                authedPassword = ""
                currentPath = ""
                pathHistory = [""]
                await loadFiles()
            } else if !passwordInput.isEmpty {
                await authAndLoad()
            } else {
                // 需要密码，停留在输入界面
                ToastManager.shared.show("请输入访问密码", type: .warning)
            }
        } catch {
            ToastManager.shared.show("获取分享失败: \(error.localizedDescription)", type: .error)
        }
    }

    private func authAndLoad() async {
        do {
            let resp = try await PublicService.shared.authPublicShare(shareID: shareIDInput, password: passwordInput)
            // resp.token 用于后续访问；公共 API 在 query 中传 share_id 即可
            authedShareID = shareIDInput
            authedPassword = passwordInput
            currentPath = ""
            pathHistory = [""]
            await loadFiles()
        } catch {
            ToastManager.shared.show("密码错误或验证失败", type: .error)
            shareInfo = nil
        }
    }

    private func loadFiles() async {
        guard let sid = authedShareID else { return }
        isLoadingFiles = true
        defer { isLoadingFiles = false }
        do {
            let resp = try await PublicService.shared.listPublicShare(
                shareID: sid,
                path: currentPath,
                password: authedPassword
            )
            files = resp.content
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            files = []
        }
    }

    private func handleFileTap(_ file: FileObject) {
        HapticManager.light()
        if file.isDir {
            let newPath = currentPath.appendingPathComponent(file.name)
            pathHistory.append(newPath)
            currentPath = newPath
            Task { await loadFiles() }
        } else if info_allowDownload {
            // 下载到本地
            downloadSharedFile(file)
        } else {
            ToastManager.shared.show("此分享不允许下载", type: .info)
        }
    }

    private func downloadSharedFile(_ file: FileObject) {
        guard let raw = file.downloadURL, let url = URL(string: raw) else {
            ToastManager.shared.show("无法获取下载链接", type: .error)
            return
        }
        DownloadManager.shared.addDownload(
            fileName: file.name,
            remoteURL: url,
            fileSize: file.size,
            sourcePath: file.virtualPath
        )
    }

    private func resetState() {
        shareInfo = nil
        authedShareID = nil
        authedPassword = nil
        shareIDInput = ""
        passwordInput = ""
        currentPath = ""
        pathHistory = [""]
        files = []
        errorMessage = nil
    }
}
