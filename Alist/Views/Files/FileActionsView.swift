import SwiftUI

struct FileActionsView: View {
    let file: FileObject
    let currentPath: String
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showRename = false
    @State private var showMoveCopy = false
    @State private var showShare = false
    @State private var showOfflineDownload = false
    @State private var showArchive = false
    @State private var showPreview = false
    @State private var showDownloadConfirm = false
    @State private var isOperating = false

    init(file: FileObject, currentPath: String, onComplete: @escaping () -> Void = {}) {
        self.file = file
        self.currentPath = currentPath
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // 预览
                    if !file.isDir && file.fileType.isPreviewable {
                        Button { HapticManager.light(); showPreview = true } label: { Label("预览", systemImage: "eye") }
                    }

                    // 下载
                    if !file.isDir {
                        Button { HapticManager.light(); downloadFile() } label: { Label("下载到本地", systemImage: "arrow.down.circle") }
                        Button { HapticManager.light(); copyLink() } label: { Label("复制直链", systemImage: "link") }
                        if file.fileType == .image, let url = file.thumbURL ?? effectiveDownloadURL() {
                            Button { HapticManager.light(); saveImageToAlbum(url: url) } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }
                        }
                    }

                    // 分享
                    Button { HapticManager.light(); showShare = true } label: { Label("创建分享", systemImage: "square.and.arrow.up") }
                }

                Section {
                    Button { HapticManager.light(); showRename = true } label: { Label("重命名", systemImage: "pencil") }
                    Button { HapticManager.light(); showMoveCopy = true } label: { Label("移动/复制", systemImage: "folder") }
                    if file.isDir {
                        Button { HapticManager.light(); showOfflineDownload = true } label: { Label("离线下载到此处", systemImage: "arrow.down.circle.dotted") }
                    }
                    if file.fileType == .archive {
                        Button { HapticManager.light(); showArchive = true } label: { Label("解压", systemImage: "archivebox") }
                    }
                }

                Section("文件信息") {
                    if let modified = file.modified {
                        LabeledContent("修改时间", value: modified.formatted)
                    }
                    if let created = file.created {
                        LabeledContent("创建时间", value: created.formatted)
                    }
                    if !file.isDir {
                        LabeledContent("大小", value: file.sizeFormatted)
                    }
                    if let p = file.virtualPath ?? file.path {
                        LabeledContent("路径", value: p)
                    }
                    if let provider = file.storageClass {
                        LabeledContent("存储类", value: provider)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        HapticManager.medium()
                        showDownloadConfirm = true
                    } label: { Label("删除", systemImage: "trash") }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showRename) {
                RenameView(file: file, currentPath: currentPath) { onComplete(); dismiss() }
            }
            .sheet(isPresented: $showMoveCopy) {
                MoveCopyView(file: file, currentPath: currentPath) { onComplete(); dismiss() }
            }
            .sheet(isPresented: $showShare) {
                CreateShareView(
                    filePath: file.virtualPath ?? file.path ?? currentPath.appendingPathComponent(file.name),
                    isDir: file.isDir,
                    fileName: file.name
                )
            }
            .sheet(isPresented: $showOfflineDownload) {
                OfflineDownloadView(targetPath: currentPath.appendingPathComponent(file.name))
            }
            .sheet(isPresented: $showArchive) {
                ArchiveView(file: file, currentPath: currentPath)
            }
            .fullScreenCover(isPresented: $showPreview) {
                FilePreviewView(file: file)
            }
            .confirmation(
                isPresented: $showDownloadConfirm,
                title: "删除文件",
                message: "确定要删除 \"\(file.name)\" 吗？此操作不可撤销。"
            ) {
                Task { await deleteFile() }
            }
        }
    }

    // MARK: - 操作
    private func downloadFile() {
        guard let url = effectiveDownloadURL() else {
            ToastManager.shared.show("无法获取下载链接", type: .error)
            return
        }
        HapticManager.light()
        DownloadManager.shared.addDownload(file: file, remoteURL: url)
    }

    private func copyLink() {
        guard let url = file.downloadURL else {
            ToastManager.shared.show("无法获取链接", type: .error)
            return
        }
        UIPasteboard.general.string = url
        HapticManager.light()
        ToastManager.shared.show("直链已复制", type: .success)
    }

    private func saveImageToAlbum(url: URL) {
        Task {
            do {
                let data = try await APIClient.shared.fetchData(from: url)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { ToastManager.shared.show("无法解析图片", type: .error) }
                    return
                }
                // 通过完成回调确认保存结果（相册权限被拒时会失败）
                let saved = await withCheckedContinuation { continuation in
                    AlbumSaveHelper.save(image) { success in
                        continuation.resume(returning: success)
                    }
                }
                await MainActor.run {
                    if saved {
                        HapticManager.success()
                        ToastManager.shared.show("已保存到相册", type: .success)
                    } else {
                        ToastManager.shared.show("保存失败，请检查相册权限", type: .error)
                    }
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.show("保存失败: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }

    private func deleteFile() async {
        isOperating = true
        defer { isOperating = false }
        do {
            try await FsService.shared.remove(dir: currentPath, names: [file.name])
            await MainActor.run {
                HapticManager.success()
                ToastManager.shared.show("已删除", type: .success)
                onComplete()
                dismiss()
            }
        } catch let error as APIError {
            await MainActor.run {
                HapticManager.error()
                ToastManager.shared.show(error.errorDescription ?? "操作失败", type: .error)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.show(error.localizedDescription, type: .error)
            }
        }
    }

    private func effectiveDownloadURL() -> URL? {
        if let raw = file.downloadURL { return URL(string: raw) }
        return nil
    }
}

// MARK: - 重命名视图
struct RenameView: View {
    let file: FileObject
    let currentPath: String
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var newName: String = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("新名称") {
                    TextField("文件名", text: $newName)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await performRename() }
                    }
                    .disabled(newName.isEmpty || isLoading || newName == file.name)
                }
            }
        }
        .onAppear { newName = file.name }
    }

    private func performRename() async {
        isLoading = true
        defer { isLoading = false }
        let path = currentPath.appendingPathComponent(file.name)
        do {
            try await FsService.shared.rename(path: path, name: newName)
            await MainActor.run {
                HapticManager.success()
                ToastManager.shared.show("重命名成功", type: .success)
                onDone()
                dismiss()
            }
        } catch let error as APIError {
            await MainActor.run {
                HapticManager.error()
                ToastManager.shared.show(error.errorDescription ?? "操作失败", type: .error)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.show(error.localizedDescription, type: .error)
            }
        }
    }
}

// MARK: - 移动/复制视图
struct MoveCopyView: View {
    let file: FileObject
    let currentPath: String
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedPath = "/"
    @State private var dirs: [DirResp] = []
    @State private var pathHistory: [String] = ["/"]
    @State private var isCopy = true
    @State private var isLoading = false
    @State private var isLoadingDirs = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("操作", selection: $isCopy) {
                    Text("复制").tag(true)
                    Text("移动").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()

                List(dirs, id: \.id) { dir in
                    Button {
                        HapticManager.light()
                        pathHistory.append(selectedPath.appendingPathComponent(dir.name))
                        selectedPath = selectedPath.appendingPathComponent(dir.name)
                        Task { await loadDirs() }
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(.blue)
                            Text(dir.name)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }
                .overlay {
                    if isLoadingDirs {
                        ProgressView()
                    } else if dirs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("无子目录").foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("目标: \(selectedPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack {
                        Button {
                            HapticManager.light()
                            if pathHistory.count > 1 {
                                pathHistory.removeLast()
                                selectedPath = pathHistory.last ?? "/"
                                Task { await loadDirs() }
                            }
                        } label: {
                            Label("上级", systemImage: "arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(pathHistory.count <= 1)

                        Spacer()

                        Button(isCopy ? "复制到此" : "移动到此") {
                            Task { await performAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || selectedPath == currentPath)
                    }
                }
                .padding()
            }
            .navigationTitle("选择目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .task { await loadDirs() }
    }

    private func loadDirs() async {
        isLoadingDirs = true
        defer { isLoadingDirs = false }
        do {
            dirs = try await FsService.shared.dirs(path: selectedPath)
        } catch {
            dirs = []
        }
    }

    private func performAction() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if isCopy {
                try await FsService.shared.copy(srcDir: currentPath, dstDir: selectedPath, names: [file.name])
            } else {
                try await FsService.shared.move(srcDir: currentPath, dstDir: selectedPath, names: [file.name])
            }
            await MainActor.run {
                HapticManager.success()
                ToastManager.shared.show(isCopy ? "复制成功" : "移动成功", type: .success)
                onDone()
                dismiss()
            }
        } catch let error as APIError {
            await MainActor.run {
                HapticManager.error()
                ToastManager.shared.show(error.errorDescription ?? "操作失败", type: .error)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.show(error.localizedDescription, type: .error)
            }
        }
    }
}

// MARK: - 保存到相册辅助类（获取保存完成回调，权限被拒时可感知失败）
final class AlbumSaveHelper: NSObject {
    private var completion: ((Bool) -> Void)?
    private static let helper = AlbumSaveHelper()

    static func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        helper.completion = completion
        UIImageWriteToSavedPhotosAlbum(
            image,
            helper,
            #selector(helper.image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion?(error == nil)
        completion = nil
    }
}

// MARK: - 新建文件夹视图
struct CreateFolderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var folderName = ""
    @State private var isLoading = false
    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("文件夹名称") {
                    TextField("新文件夹", text: $folderName)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("新建文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        HapticManager.light()
                        onCreate(folderName)
                        dismiss()
                    }
                    .disabled(folderName.isEmpty || isLoading)
                }
            }
        }
    }
}
