import SwiftUI

// MARK: - 归档（压缩包）查看
struct ArchiveView: View {
    let file: FileObject
    let currentPath: String
    @Environment(\.dismiss) var dismiss
    @State private var entries: [ArchiveListResp.ArchiveEntry] = []
    @State private var isLoading = false
    @State private var showExtract = false
    @State private var extractDst = ""

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                HStack {
                    Image(systemName: entry.isDir == true ? "folder.fill" : "doc")
                        .foregroundStyle(entry.isDir == true ? .blue : .gray)
                    VStack(alignment: .leading) {
                        Text(entry.name).font(.subheadline)
                        if let size = entry.size {
                            Text(size.fileSizeFormatted).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("解压") { showExtract = true }
                }
            }
            .overlay { if isLoading { LoadingView() } }
            .sheet(isPresented: $showExtract) {
                ExtractView(file: file, currentPath: currentPath)
            }
        }
        .task { await loadEntries() }
    }

    private func loadEntries() async {
        isLoading = true
        defer { isLoading = false }
        let path = currentPath.appendingPathComponent(file.name)
        do {
            let resp = try await FsService.shared.archiveList(path: path)
            entries = resp.content
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }
}

struct ExtractView: View {
    let file: FileObject
    let currentPath: String
    @Environment(\.dismiss) var dismiss
    @State private var dstDir = "/"
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("解压到目录") {
                    TextField("目标路径", text: $dstDir)
                        .textInputAutocapitalization(.never)
                }
                Section { Text("将把 '\(file.name)' 解压到指定目录").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("解压")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始解压") { startExtract() }.disabled(isLoading)
                }
            }
        }
    }

    private func startExtract() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await FsService.shared.decompress(
                    srcDir: currentPath,
                    srcFileName: file.name,
                    dstDir: dstDir
                )
                await MainActor.run {
                    ToastManager.shared.show("解压任务已创建", type: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.show(error.localizedDescription, type: .error)
                }
            }
        }
    }
}

// MARK: - 离线下载
struct OfflineDownloadView: View {
    let targetPath: String
    @Environment(\.dismiss) var dismiss
    @State private var urls: [String] = [""]
    @State private var selectedTool = "aria2"
    @State private var availableTools: [OfflineDownloadTool] = []
    @State private var deleteFiles = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("下载链接") {
                    ForEach(urls.indices, id: \.self) { index in
                        HStack {
                            TextField("https://...", text: Binding(
                                get: { urls[index] },
                                set: { urls[index] = $0 }
                            ))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)

                            if urls.count > 1 {
                                Button {
                                    urls.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    Button {
                        urls.append("")
                    } label: {
                        Label("添加链接", systemImage: "plus.circle.fill")
                    }
                }

                Section("下载工具") {
                    Picker("工具", selection: $selectedTool) {
                        ForEach(availableTools) { tool in
                            Text(tool.name).tag(tool.name)
                        }
                    }
                }

                Section {
                    Toggle("下载完成后删除源文件", isOn: $deleteFiles)
                }

                Section { Text("目标路径: \(targetPath)").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("离线下载")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { startDownload() }.disabled(isLoading)
                }
            }
        }
        .task { await loadTools() }
    }

    private func loadTools() async {
        do {
            availableTools = try await PublicService.shared.offlineDownloadTools()
            if let first = availableTools.first {
                selectedTool = first.name
            }
        } catch {
            ToastManager.shared.show("加载离线下载工具失败: \(error.localizedDescription)", type: .error)
        }
    }

    private func startDownload() {
        let validURLs = urls.filter { !$0.isEmpty }
        guard !validURLs.isEmpty else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await FsService.shared.addOfflineDownload(
                    urls: validURLs,
                    path: targetPath,
                    tool: selectedTool,
                    deleteFiles: deleteFiles
                )
                await MainActor.run {
                    ToastManager.shared.show("离线下载任务已添加", type: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.show(error.localizedDescription, type: .error)
                }
            }
        }
    }
}
