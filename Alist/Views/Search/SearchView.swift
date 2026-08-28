import SwiftUI

struct SearchView: View {
    @State private var keywords = ""
    @State private var scope: SearchScope = .all
    @State private var fileTypeFilter: FileTypeFilter = .all
    @State private var results: [FileObject] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var selectedFile: FileObject?
    @State private var showScopeSheet = false
    @State private var customScope = "/"

    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "/"
        case documents = "/文档"
        case images = "/图片"
        case videos = "/视频"
        case music = "/音乐"
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .all: return "全部"
            case .documents: return "文档"
            case .images: return "图片"
            case .videos: return "视频"
            case .music: return "音乐"
            }
        }
        var icon: String {
            switch self {
            case .all: return "folder"
            case .documents: return "doc.text"
            case .images: return "photo"
            case .videos: return "film"
            case .music: return "music.note"
            }
        }
    }

    enum FileTypeFilter: String, CaseIterable, Identifiable {
        case all, folder, image, video, audio, document, archive
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .all: return "全部"
            case .folder: return "文件夹"
            case .image: return "图片"
            case .video: return "视频"
            case .audio: return "音频"
            case .document: return "文档"
            case .archive: return "压缩包"
            }
        }
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .folder: return "folder"
            case .image: return "photo"
            case .video: return "film"
            case .audio: return "music.note"
            case .document: return "doc.text"
            case .archive: return "archivebox"
            }
        }
    }

    var filteredResults: [FileObject] {
        switch fileTypeFilter {
        case .all: return results
        case .folder: return results.filter { $0.isDir }
        case .image: return results.filter { $0.fileType == .image }
        case .video: return results.filter { $0.fileType == .video }
        case .audio: return results.filter { $0.fileType == .audio }
        case .document: return results.filter { [.pdf, .word, .excel, .ppt, .text, .code].contains($0.fileType) }
        case .archive: return results.filter { $0.fileType == .archive }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                filterBar
                resultList
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedFile) { file in
                FileActionsView(file: file, currentPath: file.parentPath) {
                    Task { await search() }
                }
            }
            .sheet(isPresented: $showScopeSheet) {
                scopeSheet
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Button {
                showScopeSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: scope.icon)
                    Text(scope.displayName).font(.caption)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.secondaryBackground)
                .clipShape(Capsule())
                .foregroundStyle(Theme.primary)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索文件...", text: $keywords)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if !keywords.isEmpty {
                    Button { keywords = ""; results = []; hasSearched = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FileTypeFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { fileTypeFilter = filter }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon).font(.caption2)
                            Text(filter.displayName).font(.caption)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(fileTypeFilter == filter ? Theme.primary : Theme.secondaryBackground)
                        .foregroundStyle(fileTypeFilter == filter ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var resultList: some View {
        if isLoading {
            Spacer()
            LoadingView(message: "搜索中...")
            Spacer()
        } else if !hasSearched {
            Spacer()
            EmptyStateView(icon: "magnifyingglass", title: "搜索文件", message: "输入关键词以搜索全站文件\n注意：服务器需开启搜索索引")
            Spacer()
        } else if results.isEmpty {
            Spacer()
            EmptyStateView(icon: "doc.questionmark", title: "未找到结果", message: "试试其他关键词或检查服务器索引")
            Spacer()
        } else if filteredResults.isEmpty {
            Spacer()
            EmptyStateView(icon: "line.3.horizontal.decrease.circle", title: "当前筛选无结果", message: "共有 \(results.count) 条搜索结果\n切换其他筛选条件")
            Spacer()
        } else {
            List(filteredResults) { file in
                Button {
                    selectedFile = file
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: file.isDir ? "folder.fill" : Theme.fileIcon(for: file.fileType))
                            .foregroundStyle(file.isDir ? .blue : Theme.fileColor(for: file.fileType))
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name).font(.subheadline).lineLimit(1)
                            Text(displayPath(for: file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if !file.isDir {
                            Text(file.sizeFormatted).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    /// 搜索结果中显示文件所在目录路径
    private func displayPath(for file: FileObject) -> String {
        // 搜索结果中 path 字段是父目录
        if let p = file.path, !p.isEmpty {
            return p
        }
        // 退回到 virtualPath 取父路径
        if let vp = file.virtualPath {
            return (vp as NSString).deletingLastPathComponent
        }
        return "/"
    }

    private var scopeSheet: some View {
        NavigationStack {
            List {
                Section("搜索范围") {
                    ForEach(SearchScope.allCases) { s in
                        Button {
                            scope = s
                            customScope = s.rawValue
                            showScopeSheet = false
                            if hasSearched { Task { await search() } }
                        } label: {
                            HStack {
                                Image(systemName: s.icon).foregroundStyle(Theme.primary)
                                Text(s.displayName)
                                Spacer()
                                if scope == s { Image(systemName: "checkmark").foregroundStyle(Theme.primary) }
                            }
                        }
                    }
                }
                Section("自定义路径") {
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        TextField("搜索路径，如 /downloads", text: $customScope)
                            .textInputAutocapitalization(.never)
                    }
                    Button {
                        scope = .all
                        // 直接使用自定义路径
                        showScopeSheet = false
                        if hasSearched { Task { await search(customPath: customScope) } }
                    } label: {
                        Label("使用此路径搜索", systemImage: "magnifyingglass")
                    }
                    .disabled(customScope.isEmpty)
                }
            }
            .navigationTitle("选择范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showScopeSheet = false } }
            }
        }
        .presentationDetents([.medium])
    }

    private func search(customPath: String? = nil) async {
        let trimmed = keywords.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        hasSearched = true
        let searchScope = customPath ?? scope.rawValue
        do {
            let resp = try await FsService.shared.search(parent: searchScope, keywords: trimmed, page: 1, perPage: 200)
            results = resp.content
        } catch let error as APIError {
            ToastManager.shared.show(error.errorDescription ?? error.localizedDescription, type: .error)
            results = []
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
            results = []
        }
        isLoading = false
    }
}
