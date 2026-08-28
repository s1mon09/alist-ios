import SwiftUI
import QuickLook
import UIKit

// MARK: - 下载列表视图
struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var previewURL: URL?
    @State private var exportURL: URL?

    var activeDownloads: [DownloadRecord] {
        downloadManager.downloads.filter { $0.state == .downloading || $0.state == .pending || $0.state == .paused }
    }

    var completedDownloads: [DownloadRecord] {
        downloadManager.downloads.filter { $0.state == .completed || $0.state == .failed || $0.state == .canceled }
    }

    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloads.isEmpty {
                    EmptyStateView(
                        icon: "arrow.down.circle",
                        title: "暂无下载",
                        message: "从文件菜单选择\"下载到本地\"即可添加",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    List {
                        if !activeDownloads.isEmpty {
                            Section("进行中 (\(activeDownloads.count))") {
                                ForEach(activeDownloads) { record in
                                    DownloadRowView(record: record)
                                }
                            }
                        }
                        if !completedDownloads.isEmpty {
                            Section("已完成 (\(completedDownloads.count))") {
                                ForEach(completedDownloads) { record in
                                    DownloadRowView(
                                        record: record,
                                        onPreview: { handlePreview(record) },
                                        onExport: { handleExport($0) }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("下载管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            downloadManager.clearCompleted()
                        } label: {
                            Label("清空已完成", systemImage: "trash")
                        }
                        .disabled(completedDownloads.isEmpty)

                        Button {
                            // 暂停所有
                            for r in activeDownloads where r.state == .downloading {
                                downloadManager.pauseDownload(recordID: r.id)
                            }
                        } label: {
                            Label("全部暂停", systemImage: "pause.circle")
                        }
                        .disabled(activeDownloads.allSatisfy { $0.state != .downloading })

                        Button {
                            // 恢复所有
                            for r in activeDownloads where r.state == .paused {
                                downloadManager.resumeDownload(recordID: r.id)
                            }
                        } label: {
                            Label("全部继续", systemImage: "play.circle")
                        }
                        .disabled(activeDownloads.allSatisfy { $0.state != .paused })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .quickLookPreview($previewURL)
            .sheet(item: $exportURL) { url in
                DocumentExporterView(url: url)
            }
        }
    }

    private func handlePreview(_ record: DownloadRecord) {
        let url = URL(fileURLWithPath: record.localPath)
        if FileManager.default.fileExists(atPath: url.path) {
            previewURL = url
        } else {
            ToastManager.shared.show("文件不存在", type: .error)
        }
    }

    fileprivate func handleExport(_ record: DownloadRecord) {
        let url = URL(fileURLWithPath: record.localPath)
        if FileManager.default.fileExists(atPath: url.path) {
            exportURL = url
        } else {
            ToastManager.shared.show("文件不存在", type: .error)
        }
    }
}

// MARK: - 文件导出器（保存到"文件"App）
extension URL: Identifiable {
    public var id: String { absoluteString }
}

struct DocumentExporterView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // exportMode 表示将本地文件导出到用户选择的位置
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

// MARK: - 下载行视图
struct DownloadRowView: View {
    let record: DownloadRecord
    var onPreview: (() -> Void)? = nil
    var onExport: ((DownloadRecord) -> Void)? = nil
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: fileIcon)
                    .font(.title2)
                    .foregroundStyle(record.state.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.fileName)
                        .font(.subheadline)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(record.state.rawValue)
                            .font(.caption2)
                            .foregroundStyle(record.state.color)
                        if record.fileSize > 0 {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(record.downloadedBytes.fileSizeFormatted) / \(record.fileSize.fileSizeFormatted)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if record.state == .downloading && record.downloadSpeed > 0 {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(formatSpeed(record.downloadSpeed))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if let error = record.errorMessage, record.state == .failed {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Text("\(record.progressPercent)%")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(record.state.color)
                    .monospacedDigit()
            }

            if record.state == .downloading || record.state == .paused || record.state == .pending {
                ProgressView(value: record.progress)
                    .tint(record.state.color)
            }

            // 操作按钮
            HStack(spacing: 16) {
                switch record.state {
                case .downloading:
                    Button {
                        HapticManager.light()
                        downloadManager.pauseDownload(recordID: record.id)
                    } label: {
                        Label("暂停", systemImage: "pause")
                            .font(.caption)
                    }
                    Button {
                        HapticManager.light()
                        downloadManager.cancelDownload(recordID: record.id)
                    } label: {
                        Label("取消", systemImage: "xmark")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                case .paused, .failed:
                    Button {
                        HapticManager.light()
                        downloadManager.resumeDownload(recordID: record.id)
                    } label: {
                        Label("继续", systemImage: "play")
                            .font(.caption)
                    }
                    Button {
                        HapticManager.light()
                        downloadManager.removeRecord(recordID: record.id)
                    } label: {
                        Label("移除", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                case .pending:
                    Button {
                        HapticManager.light()
                        downloadManager.cancelDownload(recordID: record.id)
                    } label: {
                        Label("取消", systemImage: "xmark")
                            .font(.caption)
                    }
                case .completed:
                    if let onPreview = onPreview {
                        Button {
                            HapticManager.light()
                            onPreview()
                        } label: {
                            Label("预览", systemImage: "eye")
                                .font(.caption)
                        }
                    }
                    ShareLink(
                        item: URL(fileURLWithPath: record.localPath),
                        preview: SharePreview(record.fileName)
                    ) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    Button {
                        HapticManager.light()
                        onExport?(record)
                    } label: {
                        Label("保存到文件App", systemImage: "folder")
                            .font(.caption)
                    }
                    Button {
                        HapticManager.light()
                        downloadManager.removeRecord(recordID: record.id)
                    } label: {
                        Label("移除", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                case .canceled:
                    Button {
                        HapticManager.light()
                        downloadManager.removeRecord(recordID: record.id)
                    } label: {
                        Label("移除", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: String {
        let ext = (record.fileName as NSString).pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"]
        let videoExts = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
        let audioExts = ["mp3", "wav", "flac", "aac", "m4a"]
        let archiveExts = ["zip", "rar", "7z", "tar", "gz"]
        let documentExts = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]
        if imageExts.contains(ext) { return "photo" }
        if videoExts.contains(ext) { return "film" }
        if audioExts.contains(ext) { return "music.note" }
        if archiveExts.contains(ext) { return "archivebox" }
        if documentExts.contains(ext) { return "doc.text" }
        return "doc"
    }

    private func formatSpeed(_ speed: Double) -> String {
        let speedInt = Int64(speed)
        return "\(speedInt.fileSizeFormatted)/s"
    }
}

// MARK: - 简化的下载指示器（用于 Tab 标签）
struct DownloadBadgeView: View {
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some View {
        if downloadManager.hasActiveDownloads {
            Text("\(downloadManager.activeDownloadsCount)")
                .font(.caption2)
                .padding(4)
                .background(Theme.danger)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
    }
}
