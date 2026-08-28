import SwiftUI

struct ShareListView: View {
    @State private var shares: [Share] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var showPublicBrowser = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && shares.isEmpty {
                    LoadingView()
                } else if shares.isEmpty {
                    EmptyStateView(
                        icon: "square.and.arrow.up",
                        title: "暂无分享",
                        message: "点击右上角创建文件分享",
                        actionTitle: "创建分享",
                        action: { showCreate = true }
                    )
                } else {
                    List {
                        Section {
                            ForEach(shares) { share in
                                ShareRowView(share: share)
                            }
                            .onDelete { indexSet in
                                Task {
                                    for index in indexSet {
                                        let share = shares[index]
                                        try? await ShareService.shared.delete(id: share.id)
                                    }
                                    await loadShares()
                                }
                            }
                        }
                        Section {
                            Button {
                                showPublicBrowser = true
                            } label: {
                                HStack {
                                    Image(systemName: "globe.asia.australia")
                                        .foregroundStyle(Theme.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("访问公共分享")
                                            .font(.subheadline)
                                        Text("通过分享ID访问他人分享的文件")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("分享")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await loadShares() }
                    } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateShareView(filePath: "/", isDir: true, fileName: nil)
            }
            .sheet(isPresented: $showPublicBrowser) {
                PublicShareBrowserView()
            }
        }
        .task { await loadShares() }
        .onReceive(NotificationCenter.default.publisher(for: .openPublicShareBrowser)) { note in
            showPublicBrowser = true
        }
    }

    private func loadShares() async {
        isLoading = true
        defer { isLoading = false }
        do {
            shares = try await ShareService.shared.list()
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }
}

struct ShareRowView: View {
    let share: Share
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                Image(systemName: share.isDir ? "folder.fill" : "doc.fill")
                    .foregroundStyle(Theme.primary)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(share.name).font(.subheadline)
                    HStack(spacing: 6) {
                        Image(systemName: "eye").font(.caption2)
                        Text("\(share.viewCount)").font(.caption2)
                        Image(systemName: "arrow.down.circle").font(.caption2)
                        Text("\(share.downloadCount)").font(.caption2)
                        if share.hasPassword {
                            Image(systemName: "lock.fill").font(.caption2)
                        }
                        if share.burnAfterRead {
                            Image(systemName: "flame.fill").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                    Text("创建于 \(share.createdAt.formatted)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if share.isExpired {
                        Text("已过期").font(.caption).foregroundStyle(.red)
                    } else if share.enabled {
                        Text("有效").font(.caption).foregroundStyle(.green)
                    } else {
                        Text("已禁用").font(.caption).foregroundStyle(.gray)
                    }
                }
            }
        }
        .foregroundStyle(.primary)
        .sheet(isPresented: $showDetail) {
            ShareDetailView(share: share)
        }
    }
}

struct ShareDetailView: View {
    let share: Share
    @Environment(\.dismiss) var dismiss
    @State private var showEdit = false

    var shareURL: String { "\(ServerConfig.shared.baseURL)/s/\(share.shareID)" }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("名称", value: share.name)
                    LabeledContent("路径", value: share.rootPath)
                    LabeledContent("类型", value: share.isDir ? "文件夹" : "文件")
                    LabeledContent("创建时间", value: share.createdAt.formatted)
                    if let exp = share.expiresAt {
                        LabeledContent("过期时间", value: exp.formatted)
                    }
                }
                Section("统计") {
                    LabeledContent("访问次数", value: "\(share.viewCount)")
                    LabeledContent("下载次数", value: "\(share.downloadCount)")
                    LabeledContent("访问限制", value: share.accessLimit > 0 ? "\(share.accessCount)/\(share.accessLimit)" : "无限")
                }
                Section("选项") {
                    LabeledContent("允许预览", value: share.allowPreview ? "是" : "否")
                    LabeledContent("允许下载", value: share.allowDownload ? "是" : "否")
                    LabeledContent("阅后即焚", value: share.burnAfterRead ? "是" : "否")
                    LabeledContent("密码保护", value: share.hasPassword ? "是" : "否")
                    LabeledContent("状态", value: share.enabled ? "启用" : "禁用")
                }
                Section("分享链接") {
                    Text(shareURL)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = shareURL
                        HapticManager.light()
                        ToastManager.shared.show("分享链接已复制", type: .success)
                    } label: { Label("复制链接", systemImage: "doc.on.doc") }
                    Button {
                        HapticManager.light()
                        guard let url = URL(string: shareURL) else {
                            ToastManager.shared.show("链接无效", type: .error)
                            return
                        }
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(activityVC, animated: true)
                        }
                    } label: { Label("分享到...", systemImage: "square.and.arrow.up") }
                    if let url = URL(string: shareURL) {
                        Link(destination: url) {
                            Label("在 Safari 中打开", systemImage: "safari")
                        }
                    }
                    // 二维码
                    HStack {
                        Spacer()
                        if let qrImage = generateQRImage(from: shareURL) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                        } else {
                            Text("无法生成二维码").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await ShareService.shared.disable(id: share.id)
                            ToastManager.shared.show("已禁用", type: .success)
                            dismiss()
                        }
                    } label: { Label("禁用分享", systemImage: "hand.raised") }
                }
            }
            .navigationTitle("分享详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private func generateQRImage(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = ciImage.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct CreateShareView: View {
    let filePath: String
    let isDir: Bool
    let fileName: String?
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var burnAfterRead = false
    @State private var accessLimit: Int64 = 0
    @State private var allowPreview = true
    @State private var allowDownload = true
    @State private var enableExpiry = false
    @State private var expiryDays = 7
    @State private var isLoading = false
    @State private var createdShareID: String?

    var body: some View {
        NavigationStack {
            Group {
                if let shareID = createdShareID {
                    shareCreatedView(shareID: shareID)
                } else {
                    createForm
                }
            }
            .navigationTitle(createdShareID == nil ? "创建分享" : "分享已创建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if createdShareID == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("创建") { createShare() }.disabled(isLoading || name.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
        .onAppear { if name.isEmpty { name = fileName ?? "" } }
    }

    private var createForm: some View {
        Form {
            Section("分享信息") {
                TextField("分享名称", text: $name)
                LabeledContent("路径", value: filePath)
            }
            Section("安全") {
                SecureField("访问密码（可选）", text: $password)
                Toggle("阅后即焚", isOn: $burnAfterRead)
                if !burnAfterRead {
                    Stepper("访问次数限制: \(accessLimit)", value: $accessLimit, in: 0...100)
                }
            }
            Section("权限") {
                Toggle("允许预览", isOn: $allowPreview)
                Toggle("允许下载", isOn: $allowDownload)
            }
            Section("有效期") {
                Toggle("设置有效期", isOn: $enableExpiry)
                if enableExpiry {
                    Stepper("\(expiryDays) 天后过期", value: $expiryDays, in: 1...365)
                }
            }
        }
    }

    private func shareCreatedView(shareID: String) -> some View {
        Form {
            Section("分享链接") {
                let url = "\(ServerConfig.shared.baseURL)/s/\(shareID)"
                Text(url)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
                Button {
                    UIPasteboard.general.string = url
                    HapticManager.light()
                    ToastManager.shared.show("链接已复制", type: .success)
                } label: {
                    Label("复制链接", systemImage: "doc.on.doc")
                }
                Button {
                    HapticManager.light()
                    guard let urlObj = URL(string: url) else {
                        ToastManager.shared.show("链接无效", type: .error)
                        return
                    }
                    let activityVC = UIActivityViewController(activityItems: [urlObj], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(activityVC, animated: true)
                    }
                } label: {
                    Label("分享到...", systemImage: "square.and.arrow.up")
                }
            }
            Section {
                Button {
                    HapticManager.light()
                    // 跳转到公共分享浏览器查看
                    NotificationCenter.default.post(name: .openPublicShareBrowser, object: shareID)
                    dismiss()
                } label: {
                    Label("在浏览器中查看", systemImage: "safari")
                }
            }
            Section {
                Button(role: .destructive) {
                    dismiss()
                } label: {
                    Text("关闭")
                }
            }
        }
    }

    private func createShare() {
        Task {
            isLoading = true
            defer { isLoading = false }
            let expiresAt = enableExpiry ? Calendar.current.date(byAdding: .day, value: expiryDays, to: Date()) : nil
            let req = CreateShareReq(
                name: name,
                path: filePath,
                password: password.isEmpty ? nil : password,
                isDir: isDir,
                burnAfterRead: burnAfterRead,
                accessLimit: burnAfterRead ? 1 : accessLimit,
                allowPreview: allowPreview,
                allowDownload: allowDownload,
                expiresAt: expiresAt
            )
            do {
                try await ShareService.shared.create(req: req)
                // 重新加载分享列表，按创建时间降序取最新的分享
                let shares = try await ShareService.shared.list()
                let sortedShares = shares.sorted { $0.createdAt > $1.createdAt }
                let created = sortedShares.first(where: { $0.name == name && $0.rootPath == filePath })
                    ?? sortedShares.first
                await MainActor.run {
                    HapticManager.success()
                    if let sid = created?.shareID {
                        createdShareID = sid
                    } else {
                        ToastManager.shared.show("分享创建成功", type: .success)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.show(error.localizedDescription, type: .error)
                }
            }
        }
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let openPublicShareBrowser = Notification.Name("openPublicShareBrowser")
}
