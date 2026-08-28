import Foundation
import SwiftUI

@MainActor
final class FileListViewModel: ObservableObject {
    @Published var files: [FileObject] = []
    @Published var currentPath: String = "/"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore: Bool = false
    @Published var totalPages: Int = 0
    @Published var currentPage: Int = 1
    @Published var total: Int64 = 0
    @Published var canWrite: Bool = false
    @Published var readme: String?
    @Published var header: String?
    @Published var provider: String?
    @Published var selectedFiles: Set<String> = []
    @Published var isSelectionMode = false
    @Published var password: String?

    private var perPage: Int { UserDefaults.standard.object(forKey: "list_page_size") as? Int ?? 200 }

    // 排序
    @Published var sortField: String {
        didSet { UserDefaults.standard.set(sortField, forKey: "default_sort_field") }
    }
    @Published var sortOrder: String {
        didSet { UserDefaults.standard.set(sortOrder, forKey: "default_sort_order") }
    }

    init() {
        self.sortField = UserDefaults.standard.string(forKey: "default_sort_field") ?? "name"
        self.sortOrder = UserDefaults.standard.string(forKey: "default_sort_order") ?? "asc"
    }

    var sortedFiles: [FileObject] {
        let showHidden = UserDefaults.standard.bool(forKey: "show_hidden_files")
        var filtered = showHidden ? files : files.filter { !$0.name.hasPrefix(".") }

        let isAsc = sortOrder == "asc"
        filtered.sort { a, b in
            // 文件夹始终在前
            if a.isDir != b.isDir { return a.isDir }
            switch sortField {
            case "name":
                return isAsc ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                              : a.name.localizedStandardCompare(b.name) == .orderedDescending
            case "size":
                return isAsc ? a.size < b.size : a.size > b.size
            case "modified":
                let aDate = a.modified ?? Date.distantPast
                let bDate = b.modified ?? Date.distantPast
                return isAsc ? aDate < bDate : aDate > bDate
            default:
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
        return filtered
    }

    func loadList(path: String, refresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        currentPath = path
        if refresh {
            currentPage = 1
            files = []
        }
        // 记录发起请求时的路径与页码，用于丢弃过期响应
        let requestPath = path
        let requestPage = currentPage

        do {
            let resp = try await FsService.shared.list(
                path: path,
                password: password,
                page: requestPage,
                perPage: perPage,
                refresh: refresh
            )
            // 过期响应保护：若期间已导航到其他路径/页码，丢弃本次结果
            guard currentPath == requestPath, currentPage == requestPage else { return }
            if refresh || requestPage == 1 {
                files = resp.content
            } else {
                files.append(contentsOf: resp.content)
            }
            hasMore = resp.hasMore
            total = resp.total
            totalPages = resp.pagesTotal ?? 0
            canWrite = resp.write
            readme = resp.readme
            header = resp.header
            provider = resp.provider
        } catch let error as APIError {
            guard currentPath == requestPath else { return }
            errorMessage = error.errorDescription
        } catch {
            guard currentPath == requestPath else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        await loadList(path: currentPath)
        // 加载失败时回退页码，避免该页被永久跳过
        if errorMessage != nil {
            currentPage -= 1
        }
    }

    func navigateTo(_ path: String) async {
        selectedFiles.removeAll()
        isSelectionMode = false
        await loadList(path: path, refresh: true)
    }

    func toggleSelection(_ name: String) {
        if selectedFiles.contains(name) {
            selectedFiles.remove(name)
        } else {
            selectedFiles.insert(name)
        }
        if selectedFiles.isEmpty {
            isSelectionMode = false
        }
    }

    func selectAll() {
        selectedFiles = Set(sortedFiles.map { $0.name })
    }

    func deselectAll() {
        selectedFiles.removeAll()
    }

    // MARK: - 文件操作
    func mkdir(name: String) async -> Bool {
        do {
            let newPath = (currentPath as NSString).appendingPathComponent(name)
            try await FsService.shared.mkdir(path: newPath)
            await loadList(path: currentPath, refresh: true)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rename(oldName: String, newName: String) async -> Bool {
        do {
            let path = (currentPath as NSString).appendingPathComponent(oldName)
            try await FsService.shared.rename(path: path, name: newName)
            await loadList(path: currentPath, refresh: true)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func move(names: [String], from srcDir: String, to dstDir: String) async -> Bool {
        do {
            try await FsService.shared.move(srcDir: srcDir, dstDir: dstDir, names: names)
            if currentPath == srcDir || currentPath == dstDir {
                await loadList(path: currentPath, refresh: true)
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func copy(names: [String], from srcDir: String, to dstDir: String) async -> Bool {
        do {
            try await FsService.shared.copy(srcDir: srcDir, dstDir: dstDir, names: names)
            if currentPath == dstDir {
                await loadList(path: currentPath, refresh: true)
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func remove(names: [String]) async -> Bool {
        do {
            try await FsService.shared.remove(dir: currentPath, names: names)
            await loadList(path: currentPath, refresh: true)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - 路径辅助
extension String {
    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }

    var parentPath: String {
        guard self != "/" else { return "/" }
        let trimmed = hasSuffix("/") ? String(dropLast()) : self
        let nsStr = trimmed as NSString
        let parent = nsStr.deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
}
