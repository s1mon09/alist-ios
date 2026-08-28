import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct UploadView: View {
    let currentPath: String
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss

    /// 待上传条目（用 UUID 作为唯一键，避免同名文件冲突）
    struct UploadItem: Identifiable {
        let id = UUID()
        let url: URL
        let displayName: String
        var progress: Double = 0
        var state: ItemState = .pending
        var errorMessage: String?
        var bytesSent: Int64 = 0
        var totalBytes: Int64 = 0
    }

    enum ItemState: String {
        case pending, uploading, success, failed, canceled
    }

    @State private var items: [UploadItem] = []
    @State private var showFilePicker = false
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var useStream = true
    @State private var asTask = true
    @State private var overwrite = true
    @State private var concurrentUploads = 2

    /// 已完成数量
    var completedCount: Int { items.filter { $0.state == .success || $0.state == .failed }.count }
    var successCount: Int { items.filter { $0.state == .success }.count }
    var failedCount: Int { items.filter { $0.state == .failed }.count }
    /// 总进度
    var overallProgress: Double {
        guard !items.isEmpty else { return 0 }
        return items.map { $0.progress }.reduce(0, +) / Double(items.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("上传选项") {
                        Toggle("流式上传", isOn: $useStream).tint(Theme.primary)
                        Toggle("作为任务上传", isOn: $asTask).tint(Theme.primary)
                        Toggle("覆盖已存在", isOn: $overwrite).tint(Theme.primary)
                        Picker("并发数", selection: $concurrentUploads) {
                            Text("1 (顺序)").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                            Text("4").tag(4)
                        }
                    }

                    Section("添加文件") {
                        Button { showFilePicker = true } label: { Label("从文件选择", systemImage: "doc") }
                        Button { showImagePicker = true } label: { Label("从相册选择", systemImage: "photo") }
                    }

                    if !items.isEmpty {
                        Section {
                            ForEach($items) { $item in
                                uploadRow(item: $item)
                            }
                            .onDelete { idx in items.remove(atOffsets: idx) }

                            if isUploading || completedCount > 0 {
                                HStack {
                                    Text("总进度").font(.caption)
                                    Spacer()
                                    Text("\(completedCount)/\(items.count)  成功 \(successCount)  失败 \(failedCount)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                ProgressView(value: overallProgress)
                            }
                        } header: {
                            HStack {
                                Text("上传列表 (\(items.count))")
                                Spacer()
                                if !isUploading {
                                    Button { items.removeAll() } label: { Text("清空").font(.caption) }
                                }
                            }
                        }
                    }
                }

                // 底部操作栏
                actionBar
            }
            .navigationTitle("上传文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(types: [.item]) { urls in
                    appendItems(urls: urls)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImageMultiPicker { images in
                    appendImages(images)
                }
            }
        }
    }

    @ViewBuilder
    private func uploadRow(item: Binding<UploadItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconFor(url: item.wrappedValue.url))
                    .foregroundStyle(iconColor(for: item.wrappedValue.url))
                    .frame(width: 24)
                Text(item.wrappedValue.displayName).font(.subheadline).lineLimit(1)
                Spacer()
                stateIcon(for: item.wrappedValue.state)
            }
            switch item.wrappedValue.state {
            case .uploading:
                HStack {
                    ProgressView(value: item.wrappedValue.progress)
                    Text("\(Int(item.wrappedValue.progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                if item.wrappedValue.totalBytes > 0 {
                    Text("\(formatBytes(item.wrappedValue.bytesSent)) / \(formatBytes(item.wrappedValue.totalBytes))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            case .failed:
                if let err = item.wrappedValue.errorMessage {
                    Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
                }
                Button {
                    Task { await retryItem(id: item.wrappedValue.id) }
                } label: {
                    Label("重试", systemImage: "arrow.clockwise").font(.caption)
                }
            case .success:
                Text("上传成功").font(.caption2).foregroundStyle(.green)
            case .pending:
                Text("等待中...").font(.caption2).foregroundStyle(.secondary)
            case .canceled:
                Text("已取消").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func stateIcon(for state: ItemState) -> some View {
        switch state {
        case .success:
            return AnyView(Image(systemName: "checkmark.circle.fill").foregroundStyle(.green))
        case .failed:
            return AnyView(Image(systemName: "xmark.circle.fill").foregroundStyle(.red))
        case .uploading:
            return AnyView(ProgressView().scaleEffect(0.6).frame(width: 20))
        case .pending:
            return AnyView(Image(systemName: "clock").foregroundStyle(.secondary))
        case .canceled:
            return AnyView(Image(systemName: "slash.circle").foregroundStyle(.secondary))
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if isUploading {
                Button {
                    cancelUpload()
                } label: {
                    HStack {
                        Image(systemName: "stop.circle")
                        Text("取消")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.danger)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    startUpload()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(items.isEmpty ? "请先选择文件" : "开始上传 (\(items.count))")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(items.isEmpty ? Color.gray : Theme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(items.isEmpty)

                if failedCount > 0 {
                    Button {
                        Task { await retryAllFailed() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试失败 (\(failedCount))")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.warning)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - 数据处理
    private func appendItems(urls: [URL]) {
        for url in urls {
            items.append(UploadItem(url: url, displayName: url.lastPathComponent))
        }
    }

    private func appendImages(_ images: [UIImage]) {
        let timestamp = Date().timeIntervalSince1970
        // 图片编码与写临时文件放到后台线程，避免多张大图卡死主线程
        Task.detached(priority: .userInitiated) {
            var newItems: [UploadItem] = []
            for (idx, image) in images.enumerated() {
                // 保留 PNG 透明通道，非透明图用 JPEG 节省体积
                let hasAlpha = image.cgImage?.alphaInfo != nil && image.cgImage?.alphaInfo != .none
                let data: Data?
                if hasAlpha, let pngData = image.pngData() {
                    data = pngData
                } else if let jpegData = image.jpegData(compressionQuality: 0.92) {
                    data = jpegData
                } else {
                    data = nil
                }
                guard let data = data else { continue }
                let ext = hasAlpha ? "png" : "jpg"
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("upload_\(timestamp)_\(idx).\(ext)")
                try? data.write(to: tmpURL)
                newItems.append(UploadItem(url: tmpURL, displayName: "image_\(idx + 1).\(ext)"))
            }
            await MainActor.run {
                items.append(contentsOf: newItems)
            }
        }
    }

    // MARK: - 上传逻辑
    private func startUpload() {
        guard !items.isEmpty else { return }
        isUploading = true
        // 重置状态
        for i in items.indices {
            if items[i].state != .success {
                items[i].state = .pending
                items[i].progress = 0
                items[i].errorMessage = nil
            }
        }

        Task {
            await uploadAll()
            await MainActor.run {
                isUploading = false
                if failedCount == 0 {
                    ToastManager.shared.show("全部上传成功", type: .success)
                    onComplete()
                    dismiss()
                } else if successCount > 0 {
                    ToastManager.shared.show("部分文件上传失败: \(failedCount) 个", type: .warning)
                    onComplete()
                } else {
                    ToastManager.shared.show("上传失败", type: .error)
                }
            }
        }
    }

    private func uploadAll() async {
        // 取出待上传项的索引
        let pendingIndices = items.indices.filter { items[$0].state == .pending }
        // 并发控制
        await withTaskGroup(of: Void.self) { group in
            var iterator = pendingIndices.makeIterator()
            var running = 0
            // 先填充至并发上限
            while running < concurrentUploads, let idx = iterator.next() {
                running += 1
                group.addTask { await uploadItem(at: idx) }
            }
            // 每完成一个，补充新的
            for await _ in group {
                running -= 1
                if running < concurrentUploads, let idx = iterator.next() {
                    running += 1
                    group.addTask { await uploadItem(at: idx) }
                }
            }
        }
    }

    private func uploadItem(at index: Int) async {
        guard index < items.count else { return }
        let item = items[index]
        guard item.state == .pending else { return }

        await MainActor.run {
            items[index].state = .uploading
        }

        let fileName = item.displayName
        let path = currentPath.appendingPathComponent(fileName)
        var lastUpdate = Date()
        var lastBytes: Int64 = 0

        do {
            if useStream {
                _ = try await FsService.shared.uploadStream(
                    path: path,
                    fileURL: item.url,
                    asTask: asTask,
                    overwrite: overwrite,
                    progress: { progress in
                        // 节流：每 0.2 秒更新一次 UI，避免高频刷新
                        let now = Date()
                        if now.timeIntervalSince(lastUpdate) > 0.2 || progress >= 1.0 {
                            lastUpdate = now
                            Task { @MainActor in
                                guard index < items.count else { return }
                                items[index].progress = progress
                                if progress >= 1.0 {
                                    items[index].bytesSent = items[index].totalBytes
                                }
                            }
                        }
                    }
                )
            } else {
                _ = try await FsService.shared.uploadForm(
                    path: path,
                    fileURL: item.url,
                    asTask: asTask,
                    overwrite: overwrite,
                    progress: { progress in
                        let now = Date()
                        if now.timeIntervalSince(lastUpdate) > 0.2 || progress >= 1.0 {
                            lastUpdate = now
                            Task { @MainActor in
                                guard index < items.count else { return }
                                items[index].progress = progress
                                if progress >= 1.0 {
                                    items[index].bytesSent = items[index].totalBytes
                                }
                            }
                        }
                    }
                )
            }
            await MainActor.run {
                guard index < items.count else { return }
                items[index].progress = 1.0
                items[index].state = .success
            }
        } catch {
            await MainActor.run {
                guard index < items.count else { return }
                items[index].state = .failed
                items[index].errorMessage = error.localizedDescription
            }
        }
        _ = lastBytes
    }

    private func retryItem(id: UUID) async {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].state == .failed else { return }
        items[idx].state = .pending
        items[idx].progress = 0
        items[idx].errorMessage = nil
        if !isUploading {
            isUploading = true
            await uploadAll()
            await MainActor.run { isUploading = false }
        }
    }

    private func retryAllFailed() async {
        for i in items.indices where items[i].state == .failed {
            items[i].state = .pending
            items[i].progress = 0
            items[i].errorMessage = nil
        }
        if !isUploading {
            isUploading = true
            await uploadAll()
            await MainActor.run { isUploading = false }
        }
    }

    private func cancelUpload() {
        // 简单取消：把 pending 改成 canceled
        for i in items.indices where items[i].state == .pending || items[i].state == .uploading {
            items[i].state = .canceled
        }
        isUploading = false
    }

    // MARK: - 辅助
    private func iconFor(url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"]
        let videoExts = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
        let audioExts = ["mp3", "wav", "flac", "aac", "m4a"]
        if imageExts.contains(ext) { return "photo" }
        if videoExts.contains(ext) { return "film" }
        if audioExts.contains(ext) { return "music.note" }
        return "doc"
    }

    private func iconColor(for url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"]
        let videoExts = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
        let audioExts = ["mp3", "wav", "flac", "aac", "m4a"]
        if imageExts.contains(ext) { return .pink }
        if videoExts.contains(ext) { return .purple }
        if audioExts.contains(ext) { return .orange }
        return Theme.primary
    }

    private func formatBytes(_ bytes: Int64) -> String {
        return bytes.fileSizeFormatted
    }
}

// MARK: - 文件选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
}

// MARK: - 图片选择器（支持多选）
struct ImageMultiPicker: UIViewControllerRepresentable {
    let onPick: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0  // 0 表示无限制
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImageMultiPicker
        init(_ parent: ImageMultiPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            var images: [UIImage] = []
            let lock = NSLock()  // loadObject 回调在并发队列执行，保护数组写入
            let group = DispatchGroup()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let image = obj as? UIImage {
                        lock.lock()
                        images.append(image)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.onPick(images)
            }
        }
    }
}

// MARK: - 旧版单选 ImagePicker（保留以备需要 UIImagePickerController 的场景）
struct ImagePicker: UIViewControllerRepresentable {
    let onPick: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick([image])
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
