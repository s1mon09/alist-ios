import SwiftUI

struct FileBrowserView: View {
    @StateObject private var vm = FileListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showCreateFolder = false
    @State private var showUpload = false
    @State private var pasteAction: PasteAction?
    @State private var copiedFiles: [String] = []
    @State private var copiedFromPath: String = "/"
    @State private var previewFile: FileObject?
    @State private var showDownloads = false

    enum PasteAction: String {
        case copy, move
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            fileListContent
                .navigationTitle(rootTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .refreshable {
                    HapticManager.light()
                    await vm.loadList(path: vm.currentPath, refresh: true)
                }
                .navigationDestination(for: String.self) { path in
                    FileListSubview(
                        path: path,
                        vm: vm,
                        previewFile: $previewFile,
                        pasteAction: $pasteAction,
                        copiedFiles: $copiedFiles,
                        copiedFromPath: $copiedFromPath,
                        onNavigate: { newPath in
                            navigationPath.append(newPath)
                        },
                        onPop: {
                            if !navigationPath.isEmpty {
                                navigationPath.removeLast()
                            }
                        }
                    )
                }
        }
        .task {
            await vm.loadList(path: "/", refresh: true)
        }
        // 返回按钮回退到根目录时，同步 vm 状态（修复返回后路径/面包屑不更新）
        .onChange(of: navigationPath.count) { count in
            if count == 0 && vm.currentPath != "/" {
                // 必须 refresh 重置页码，否则会把根目录内容追加到子目录列表上
                Task { await vm.loadList(path: "/", refresh: true) }
            }
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderView { name in
                Task {
                    if await vm.mkdir(name: name) {
                        HapticManager.success()
                    }
                }
            }
        }
        .sheet(isPresented: $showUpload) {
            UploadView(currentPath: vm.currentPath) {
                Task { await vm.loadList(path: vm.currentPath, refresh: true) }
            }
        }
        .sheet(item: $previewFile) { file in
            FileActionsView(file: file, currentPath: vm.currentPath) {
                Task { await vm.loadList(path: vm.currentPath, refresh: true) }
            }
        }
        .sheet(isPresented: $showDownloads) {
            DownloadsView()
        }
    }

    /// 根目录标题：provider 为空或 "unknown" 时显示"根目录"
    private var rootTitle: String {
        guard let provider = vm.provider, !provider.isEmpty,
              provider.lowercased() != "unknown" else {
            return "根目录"
        }
        return provider
    }

    @ViewBuilder
    private var fileListContent: some View {
        if vm.isLoading && vm.files.isEmpty {
            LoadingView()
        } else if let error = vm.errorMessage, vm.files.isEmpty {
            ErrorStateView(message: error) {
                Task { await vm.loadList(path: vm.currentPath, refresh: true) }
            }
        } else if vm.sortedFiles.isEmpty {
            EmptyStateView(
                icon: "folder",
                title: "空文件夹",
                message: "当前目录没有文件",
                actionTitle: canWrite ? "上传文件" : nil,
                action: canWrite ? { showUpload = true } : nil
            )
        } else {
            List {
                if let header = vm.header, !header.isEmpty {
                    Section { Text(header).font(.caption).foregroundStyle(Theme.secondaryText) }
                }
                // 面包屑导航
                Section {
                    BreadcrumbView(currentPath: vm.currentPath) { path in
                        // 回到某层级
                        navigationPath.removeLast(navigationPath.count)
                        Task { await vm.loadList(path: path, refresh: true) }
                    }
                }
                ForEach(vm.sortedFiles) { file in
                    FileRowItem(file: file, vm: vm) {
                        handleTap(file)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canWrite {
                            Button { copy([file.name]) } label: { Label("复制", systemImage: "doc.on.doc") }
                            Button { pasteAction = .move; copiedFiles = [file.name]; copiedFromPath = vm.currentPath } label: { Label("移动", systemImage: "scissors") }.tint(.orange)
                            Button(role: .destructive) {
                                Task {
                                    if await vm.remove(names: [file.name]) {
                                        HapticManager.success()
                                    }
                                }
                            } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                }
                if vm.hasMore {
                    Section {
                        Button {
                            Task { await vm.loadMore() }
                        } label: {
                            HStack { Spacer(); ProgressView(); Text("加载更多"); Spacer() }
                        }
                    }
                }
                if let readme = vm.readme, !readme.isEmpty {
                    Section("README") {
                        MarkdownRenderView(markdown: readme)
                            .padding(.vertical)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var canWrite: Bool { vm.canWrite }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button {
                    HapticManager.light()
                    Task { await vm.loadList(path: vm.currentPath, refresh: true) }
                } label: { Label("刷新", systemImage: "arrow.clockwise") }

                Picker("排序", selection: $vm.sortField) {
                    Text("名称").tag("name")
                    Text("大小").tag("size")
                    Text("修改时间").tag("modified")
                }
                Picker("方向", selection: $vm.sortOrder) {
                    Text("升序").tag("asc")
                    Text("降序").tag("desc")
                }

                Divider()
                Toggle("显示隐藏文件", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "show_hidden_files") },
                    set: { UserDefaults.standard.set($0, forKey: "show_hidden_files"); vm.objectWillChange.send() }
                ))

                if vm.isSelectionMode {
                    Divider()
                    Button { vm.selectAll() } label: { Label("全选", systemImage: "checkmark.circle.fill") }
                    Button { vm.deselectAll() } label: { Label("取消全选", systemImage: "circle") }
                    if !vm.selectedFiles.isEmpty {
                        Divider()
                        Menu("批量操作") {
                            Button { Task { await batchCopy() } } label: { Label("复制选中", systemImage: "doc.on.doc") }
                            Button { Task { await batchMove() } } label: { Label("移动选中", systemImage: "scissors") }
                            Button(role: .destructive) { Task { await batchDelete() } } label: { Label("删除选中", systemImage: "trash") }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if canWrite {
                    Button { HapticManager.light(); showCreateFolder = true } label: { Label("新建文件夹", systemImage: "folder.badge.plus") }
                    Button { HapticManager.light(); showUpload = true } label: { Label("上传", systemImage: "arrow.up.circle") }
                    Divider()
                }
                Button { HapticManager.light(); showDownloads = true } label: {
                    Label("下载管理", systemImage: "arrow.down.circle")
                }
                Divider()
                if !copiedFiles.isEmpty {
                    Button {
                        HapticManager.light()
                        Task { await pasteFiles() }
                    } label: { Label("粘贴 (\(copiedFiles.count))", systemImage: "doc.on.clipboard") }
                    Button {
                        copiedFiles.removeAll()
                        pasteAction = nil
                    } label: { Label("取消粘贴", systemImage: "xmark") }
                    Divider()
                }
                Button {
                    HapticManager.light()
                    vm.isSelectionMode.toggle()
                    if !vm.isSelectionMode { vm.deselectAll() }
                } label: {
                    Label(vm.isSelectionMode ? "退出选择" : "多选", systemImage: vm.isSelectionMode ? "checkmark.circle" : "checklist")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
    }

    private func handleTap(_ file: FileObject) {
        if vm.isSelectionMode {
            vm.toggleSelection(file.name)
            HapticManager.light()
            return
        }
        if file.isDir {
            HapticManager.light()
            let newPath = vm.currentPath.appendingPathComponent(file.name)
            navigationPath.append(newPath)
        } else {
            HapticManager.light()
            previewFile = file
        }
    }

    private func copy(_ names: [String]) {
        HapticManager.light()
        pasteAction = .copy
        copiedFiles = names
        copiedFromPath = vm.currentPath
    }

    private func pasteFiles() async {
        guard !copiedFiles.isEmpty else { return }
        let success: Bool
        if pasteAction == .copy {
            success = await vm.copy(names: copiedFiles, from: copiedFromPath, to: vm.currentPath)
        } else {
            success = await vm.move(names: copiedFiles, from: copiedFromPath, to: vm.currentPath)
        }
        if success {
            HapticManager.success()
            ToastManager.shared.show("\(pasteAction == .copy ? "复制" : "移动")成功", type: .success)
            copiedFiles.removeAll()
            pasteAction = nil
        } else {
            HapticManager.error()
        }
    }

    private func batchCopy() async {
        let names = Array(vm.selectedFiles)
        pasteAction = .copy
        copiedFiles = names
        copiedFromPath = vm.currentPath
        vm.isSelectionMode = false
        vm.deselectAll()
        ToastManager.shared.show("已复制 \(names.count) 项,请导航到目标目录后粘贴", type: .info)
    }

    private func batchMove() async {
        let names = Array(vm.selectedFiles)
        pasteAction = .move
        copiedFiles = names
        copiedFromPath = vm.currentPath
        vm.isSelectionMode = false
        vm.deselectAll()
        ToastManager.shared.show("已剪切 \(names.count) 项,请导航到目标目录后粘贴", type: .info)
    }

    private func batchDelete() async {
        let names = Array(vm.selectedFiles)
        if await vm.remove(names: names) {
            HapticManager.success()
            vm.isSelectionMode = false
            vm.deselectAll()
        }
    }
}

// MARK: - 面包屑导航
struct BreadcrumbView: View {
    let currentPath: String
    let onNavigate: (String) -> Void

    var components: [String] {
        var parts = currentPath.split(separator: "/").map { String($0) }
        parts.insert("根目录", at: 0)
        return parts
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(components.indices, id: \.self) { index in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        HapticManager.light()
                        if index == 0 {
                            onNavigate("/")
                        } else {
                            let path = "/" + components[1...index].joined(separator: "/")
                            onNavigate(path)
                        }
                    } label: {
                        Text(components[index])
                            .font(.caption)
                            .foregroundStyle(index == components.count - 1 ? Theme.primary : .secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 子目录视图
struct FileListSubview: View {
    let path: String
    @ObservedObject var vm: FileListViewModel
    @Binding var previewFile: FileObject?
    @Binding var pasteAction: FileBrowserView.PasteAction?
    @Binding var copiedFiles: [String]
    @Binding var copiedFromPath: String
    let onNavigate: (String) -> Void
    let onPop: () -> Void
    @State private var showCreateFolder = false
    @State private var showUpload = false
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if vm.isLoading && vm.files.isEmpty {
                LoadingView()
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error) {
                    Task { await vm.loadList(path: path, refresh: true) }
                }
            } else {
                List {
                    BreadcrumbView(currentPath: path) { target in
                        // 通过导航路径回退
                        if target == "/" {
                            onPop()
                            Task { await vm.loadList(path: "/", refresh: true) }
                        } else {
                            // 计算需要回退多少层
                            let currentDepth = path.split(separator: "/").count
                            let targetDepth = target.split(separator: "/").count
                            if targetDepth < currentDepth {
                                for _ in 0..<(currentDepth - targetDepth) {
                                    onPop()
                                }
                                Task { await vm.loadList(path: target, refresh: true) }
                            }
                        }
                    }
                    ForEach(vm.sortedFiles) { file in
                        FileRowItem(file: file, vm: vm) {
                            if vm.isSelectionMode {
                                vm.toggleSelection(file.name)
                                HapticManager.light()
                            } else if file.isDir {
                                HapticManager.light()
                                let newPath = path.appendingPathComponent(file.name)
                                onNavigate(newPath)
                            } else {
                                HapticManager.light()
                                previewFile = file
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if vm.canWrite {
                                Button { pasteAction = .copy; copiedFiles = [file.name]; copiedFromPath = path } label: { Label("复制", systemImage: "doc.on.doc") }
                                Button { pasteAction = .move; copiedFiles = [file.name]; copiedFromPath = path } label: { Label("移动", systemImage: "scissors") }.tint(.orange)
                                Button(role: .destructive) {
                                    Task { if await vm.remove(names: [file.name]) { HapticManager.success() } }
                                } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                    }
                    if vm.hasMore {
                        Section {
                            Button { Task { await vm.loadMore() } } label: {
                                HStack { Spacer(); ProgressView(); Text("加载更多"); Spacer() }
                            }
                        }
                    }
                    if let readme = vm.readme, !readme.isEmpty {
                        Section("README") {
                            MarkdownRenderView(markdown: readme)
                                .padding(.vertical)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(path.lastPathComponent.isEmpty ? "根目录" : path.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if vm.canWrite {
                        Button { HapticManager.light(); showCreateFolder = true } label: { Label("新建文件夹", systemImage: "folder.badge.plus") }
                        Button { HapticManager.light(); showUpload = true } label: { Label("上传", systemImage: "arrow.up.circle") }
                        Divider()
                    }
                    if !copiedFiles.isEmpty {
                        Button {
                            HapticManager.light()
                            Task { await pasteFiles() }
                        } label: { Label("粘贴 (\(copiedFiles.count))", systemImage: "doc.on.clipboard") }
                        Divider()
                    }
                    Button {
                        HapticManager.light()
                        vm.isSelectionMode.toggle()
                        if !vm.isSelectionMode { vm.deselectAll() }
                    } label: {
                        Label(vm.isSelectionMode ? "退出选择" : "多选", systemImage: vm.isSelectionMode ? "checkmark.circle" : "checklist")
                    }
                    Button { HapticManager.light(); Task { await vm.loadList(path: path, refresh: true) } } label: { Label("刷新", systemImage: "arrow.clockwise") }
                } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .task {
            // 避免重复加载
            guard !hasLoaded || vm.currentPath != path else { return }
            hasLoaded = true
            await vm.navigateTo(path)
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderView { name in
                Task {
                    if await vm.mkdir(name: name) {
                        HapticManager.success()
                    }
                }
            }
        }
        .sheet(isPresented: $showUpload) {
            UploadView(currentPath: path) {
                Task { await vm.loadList(path: path, refresh: true) }
            }
        }
        .sheet(item: $previewFile) { file in
            FileActionsView(file: file, currentPath: path) {
                Task { await vm.loadList(path: path, refresh: true) }
            }
        }
    }

    private func pasteFiles() async {
        guard !copiedFiles.isEmpty else { return }
        let success: Bool
        if pasteAction == .copy {
            success = await vm.copy(names: copiedFiles, from: copiedFromPath, to: path)
        } else {
            success = await vm.move(names: copiedFiles, from: copiedFromPath, to: path)
        }
        if success {
            HapticManager.success()
            ToastManager.shared.show("\(pasteAction == .copy ? "复制" : "移动")成功", type: .success)
            copiedFiles.removeAll()
            pasteAction = nil
        } else {
            HapticManager.error()
        }
    }
}

// MARK: - 文件行视图
struct FileRowItem: View {
    let file: FileObject
    @ObservedObject var vm: FileListViewModel
    let onTap: () -> Void

    var isSelected: Bool { vm.selectedFiles.contains(file.name) }

    var body: some View {
        HStack(spacing: 12) {
            if vm.isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.primary : Theme.secondaryText)
                    .font(.title3)
            }

            // 缩略图/图标
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

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(file.sizeFormatted)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    if let modified = file.modified {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Text(modified.relativeFormatted)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            Spacer()

            // 标签
            if let labels = file.labelList, !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(2)) { label in
                        Text(label.name)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(label.bgColor.map { Color(hex: $0) } ?? Theme.secondaryText.opacity(0.3))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            if !vm.isSelectionMode {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
