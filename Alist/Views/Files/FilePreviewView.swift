import SwiftUI
import AVKit
import PDFKit
import WebKit
import Kingfisher
import MarkdownUI
import QuickLook
import Combine

/// 文件预览统一入口
struct FilePreviewView: View {
    let file: FileObject
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var detail: FsGetResp?
    @State private var relatedFiles: [FileObject] = []
    @State private var localFileURL: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    Text("加载中...")
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            } else if let detail = detail {
                previewContent(for: detail)
            }
        }
        .task { await loadDetail() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }.foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let url = effectiveURL(detail) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").foregroundStyle(.white)
                    }
                }
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func previewContent(for detail: FsGetResp) -> some View {
        switch file.fileType {
        case .image:
            if let url = effectiveURL(detail) {
                ImageViewer(url: url, relatedImages: relatedImageURLs)
            }
        case .video:
            if let url = effectiveURL(detail) {
                VideoPlayerView(url: url, title: file.name)
            }
        case .audio:
            if let url = effectiveURL(detail) {
                AudioPlayerView(url: url, title: file.name)
            }
        case .pdf:
            if let url = effectiveURL(detail) {
                PDFPreviewView(url: url, fileName: file.name)
            }
        case .text, .code:
            TextPreviewView(url: effectiveURL(detail), fileName: file.name)
        case .document, .word, .excel, .ppt:
            // Office 文档使用 QuickLook 预览（需先下载）
            if let localURL = localFileURL {
                QuickLookView(url: localURL)
            } else {
                DownloadAndPreviewView(url: effectiveURL(detail), fileName: file.name) { url in
                    localFileURL = url
                }
            }
        default:
            // 尝试按扩展名判断
            if file.fileExtension == "html" || file.fileExtension == "htm" {
                if let url = effectiveURL(detail) {
                    HTMLPreviewView(url: url, fileName: file.name)
                }
            } else {
                OtherFileView(file: file, url: effectiveURL(detail))
            }
        }
    }

    private func effectiveURL(_ detail: FsGetResp?) -> URL? {
        let raw = detail?.rawURL ?? file.downloadURL
        guard let raw = raw else { return nil }
        return URL(string: raw)
    }

    private var relatedImageURLs: [URL] {
        relatedFiles
            .filter { $0.fileType == .image }
            .compactMap { file -> URL? in
                let vpath = file.virtualPath ?? ""
                let sign = file.sign.map { "?sign=\($0)" } ?? ""
                return URL(string: ServerConfig.shared.baseURL + "/d" + vpath.encodedPath + sign)
            }
    }

    private func loadDetail() async {
        do {
            let path = file.virtualPath ?? file.path ?? ""
            detail = try await FsService.shared.get(path: path)
            relatedFiles = detail?.related ?? []
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 图片查看器（使用 Kingfisher，支持双击缩放/拖拽/翻页）
struct ImageViewer: View {
    let url: URL
    let relatedImages: [URL]
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentIndex = 0

    var allImages: [URL] {
        [url] + relatedImages
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(allImages.enumerated()), id: \.offset) { idx, imgURL in
                imageContent(url: imgURL)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: allImages.count > 1 ? .automatic : .never))
        .background(Color.black)
        .ignoresSafeArea()
        .onChange(of: currentIndex) { _ in
            // 切换页面时重置缩放
            withAnimation(.spring()) {
                scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
            }
        }
    }

    @ViewBuilder
    private func imageContent(url: URL) -> some View {
        KFImage(url)
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)))
            .scaleFactor(UIScreen.main.scale)
            .cacheOriginalImage()
            .placeholder {
                ProgressView().tint(.white)
            }
            .onFailure { _ in
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text("加载失败").foregroundStyle(.white)
                    Text("点击此处关闭").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
            }
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        scale = max(1, min(lastScale * val, 5))
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1 {
                            withAnimation { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1 {
                        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                    } else {
                        scale = 2.5; lastScale = 2.5
                    }
                }
            }
    }
}

// MARK: - 视频播放器（带全屏/手势/控制栏）
struct VideoPlayerView: View {
    let url: URL
    let title: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var rate: Float = 1.0
    @State private var timeObserver: Any?
    @State private var showControls = true
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var isFullscreen = false
    @State private var isDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            if let player = player {
                GeometryReader { geo in
                    ZStack {
                        VideoPlayer(player: player)
                            .onAppear { player.play(); isPlaying = true }
                            .onDisappear { player.pause() }
                            .ignoresSafeArea()

                        // 点击切换控制栏
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { showControls.toggle() }
                            }

                        // 控制栏
                        if showControls {
                            VStack {
                                Spacer()
                                controlBar
                                    .background(Color.black.opacity(0.85))
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            } else {
                ProgressView("加载视频...")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await setupPlayer() }
        .onDisappear { cleanup() }
        .statusBarHidden(!showControls)
    }

    private var controlBar: some View {
        VStack(spacing: 8) {
            // 进度条
            HStack(spacing: 8) {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Slider(value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        let target = CMTime(seconds: newValue, preferredTimescale: 600)
                        player?.seek(to: target)
                        currentTime = newValue
                    }
                ), in: 0...max(duration, 1))
                    .tint(Theme.primary)

                Text(formatTime(duration))
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            HStack(spacing: 24) {
                Button {
                    HapticManager.light()
                    let target = max(0, currentTime - 15)
                    player?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                Button {
                    HapticManager.light()
                    if isPlaying {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }

                Button {
                    HapticManager.light()
                    let target = min(duration, currentTime + 15)
                    player?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                Menu {
                    Button("0.5×") { rate = 0.5; player?.rate = 0.5 }
                    Button("1.0×") { rate = 1.0; player?.rate = 1.0 }
                    Button("1.25×") { rate = 1.25; player?.rate = 1.25 }
                    Button("1.5×") { rate = 1.5; player?.rate = 1.5 }
                    Button("2.0×") { rate = 2.0; player?.rate = 2.0 }
                } label: {
                    Text(String(format: "%.2f×", rate))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func setupPlayer() async {
        let headers: [String: String] = ["Authorization": ServerConfig.shared.token]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)

        await MainActor.run {
            // 视图已销毁则不再注册播放器与观察者，避免泄漏
            guard !isDismissed else { return }
            let player = AVPlayer(playerItem: item)
            self.player = player

            // 监听时长
            item.publisher(for: \.duration)
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak player] duration in
                    self.duration = CMTimeGetSeconds(duration)
                    _ = player
                }
                .store(in: &cancellables)

            // 监听播放进度
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { time in
                self.currentTime = CMTimeGetSeconds(time)
            }
        }
    }

    private func cleanup() {
        isDismissed = true
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        cancellables.removeAll()
        player?.pause()
        player = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 音频播放器
struct AudioPlayerView: View {
    let url: URL
    let title: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?
    @State private var rate: Float = 1.0
    @State private var durationObserver: NSObjectProtocol?
    @State private var endObserver: NSObjectProtocol?
    @State private var isDismissed = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 唱片图标
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.primary, Theme.primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 200, height: 200)
                    .shadow(radius: 20)

                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isPlaying ? currentTime * 30 : 0))
                    .animation(.linear(duration: 0.1), value: currentTime)
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal)

            Spacer()

            // 进度条
            VStack(spacing: 4) {
                Slider(value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        let target = CMTime(seconds: newValue, preferredTimescale: 600)
                        player?.seek(to: target)
                        currentTime = newValue
                    }
                ), in: 0...max(duration, 1))
                    .tint(Theme.primary)

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 24)

            // 控制按钮
            HStack(spacing: 40) {
                Button {
                    HapticManager.light()
                    let target = max(0, currentTime - 15)
                    player?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                } label: {
                    Image(systemName: "gobackward.15").font(.title).foregroundStyle(.white)
                }

                Button {
                    HapticManager.light()
                    if isPlaying {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                }

                Button {
                    HapticManager.light()
                    let target = min(duration, currentTime + 15)
                    player?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
                } label: {
                    Image(systemName: "goforward.15").font(.title).foregroundStyle(.white)
                }
            }
            .padding(.bottom, 60)
        }
        .background(Color.black.ignoresSafeArea())
        .task { await setupPlayer() }
        .onDisappear { cleanup() }
    }

    private func setupPlayer() async {
        let headers: [String: String] = ["Authorization": ServerConfig.shared.token]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)

        await MainActor.run {
            // 视图已销毁则不再注册播放器与观察者，避免泄漏
            guard !isDismissed else { return }
            let player = AVPlayer(playerItem: item)
            self.player = player

            // 监听时长（保存 token 以便正确移除）
            durationObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "AVPlayerItemDurationDidChangeNotification"), object: item, queue: .main) { _ in
                self.duration = CMTimeGetSeconds(item.duration)
            }

            // 监听播放结束
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                player.seek(to: .zero)
                player.pause()
                self.isPlaying = false
            }

            // 监听播放进度
            let time = CMTime(seconds: 0.2, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { time in
                self.currentTime = CMTimeGetSeconds(time)
                if self.duration == 0 {
                    self.duration = CMTimeGetSeconds(item.duration)
                }
            }
        }
    }

    private func cleanup() {
        isDismissed = true
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let obs = durationObserver {
            NotificationCenter.default.removeObserver(obs)
            durationObserver = nil
        }
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "00:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - PDF 预览（带加载进度和错误处理）
struct PDFPreviewView: View {
    let url: URL
    let fileName: String
    @State private var document: PDFDocument?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var progress: Double = 0

    var body: some View {
        VStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    Text("正在加载 PDF...")
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let doc = document {
                PDFKitView(document: doc)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { await loadPDF() }
    }

    private func loadPDF() async {
        do {
            let data = try await APIClient.shared.fetchData(from: url)
            // 大文件直接拒绝，避免内存暴涨被系统杀死
            guard data.count <= 100_000_000 else {
                await MainActor.run {
                    loadError = "PDF 文件过大（超过 100MB），请下载后查看"
                    isLoading = false
                }
                return
            }
            // 解析移出主线程，避免大文件阻塞 UI
            let doc = await Task.detached(priority: .userInitiated) {
                PDFDocument(data: data)
            }.value
            await MainActor.run {
                if let doc = doc {
                    document = doc
                } else {
                    loadError = "无法解析 PDF 文件"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = "加载失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - 文本预览（增大限制/行号/编码检测/搜索/CSV表格/JSON美化）
struct TextPreviewView: View {
    let url: URL?
    let fileName: String
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var isMarkdown = false
    @State private var isCSV = false
    @State private var loadError: String?
    @State private var searchText: String = ""
    @State private var showSearch = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("加载中...").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isCSV {
                CSVTableView(content: content, fileName: fileName)
            } else if isMarkdown {
                ScrollView {
                    Markdown(content)
                        .padding()
                        .markdownTheme(.gitHub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // 代码/文本：行号 + 内容
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        // 行号
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(lineNumbers.enumerated()), id: \.offset) { idx, _ in
                                Text("\(idx + 1)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                            }
                        }
                        .background(Color(.secondarySystemBackground))

                        // 内容
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isMarkdown && !isLoading && loadError == nil {
                    Button { showSearch.toggle() } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .task { await loadContent() }
    }

    private var lineNumbers: [Int] {
        Array(repeating: 0, count: content.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    private func loadContent() async {
        guard let url = url else {
            isLoading = false
            loadError = "无效的 URL"
            return
        }
        do {
            let data = try await APIClient.shared.fetchData(from: url)
            // 限制 5MB，避免大文件卡顿
            let maxBytes = 5_000_000
            let truncatedData = data.count > maxBytes ? Data(data.prefix(maxBytes)) : data
            let isOverLimit = data.count > maxBytes
            let name = fileName
            // 多编码尝试/JSON美化移到后台线程，避免主线程全量扫描卡顿
            let result = await Task.detached(priority: .userInitiated) { () -> (String, Bool) in
                let lower = name.lowercased()
                // JSON 自动美化
                if lower.hasSuffix(".json"),
                   let obj = try? JSONSerialization.jsonObject(with: truncatedData, options: [.fragmentsAllowed]),
                   let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
                   let str = String(data: pretty, encoding: .utf8) {
                    return (str, false)
                }
                let content = String(data: truncatedData, encoding: .utf8)
                    ?? String(data: truncatedData, encoding: .gb_18030_2000)
                    ?? String(data: truncatedData, encoding: .unicode)
                    ?? String(data: truncatedData, encoding: .ascii)
                    ?? "无法解码文件内容"
                // CSV/TSV 表格
                if lower.hasSuffix(".csv") || lower.hasSuffix(".tsv") {
                    return (content, true)
                }
                return (content, false)
            }.value
            content = result.0
            isCSV = result.1
            if isOverLimit {
                content += "\n\n... 文件较大,已截断显示前 5MB ..."
            }
            let lowerName = name.lowercased()
            isMarkdown = lowerName.hasSuffix(".md") || lowerName.hasSuffix(".markdown")
        } catch {
            loadError = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - CSV/TSV 表格预览
struct CSVTableView: View {
    let content: String
    let fileName: String

    private var separator: Character {
        fileName.lowercased().hasSuffix(".tsv") ? "\t" : ","
    }

    /// 解析 CSV（支持引号包裹的字段与转义），限制行数避免大文件卡顿
    private var rows: [[String]] {
        let maxRows = 500
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        func endField() {
            currentRow.append(currentField)
            currentField = ""
        }
        func endRow() {
            endField()
            result.append(currentRow)
            currentRow = []
        }

        for ch in content {
            if result.count >= maxRows { break }
            if inQuotes {
                if ch == "\"" {
                    inQuotes = false
                } else {
                    currentField.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == separator {
                endField()
            } else if ch == "\n" {
                endRow()
            } else if ch == "\r" {
                continue
            } else {
                currentField.append(ch)
            }
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            if result.count < maxRows { endRow() }
        }
        return result
    }

    var body: some View {
        let data = rows
        return ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(row.prefix(30).enumerated()), id: \.offset) { _, cell in
                            Text(cell.isEmpty ? " " : cell)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(minWidth: 60, maxWidth: 220, alignment: .leading)
                                .background(headerBackground(row: idx))
                        }
                    }
                }
                if content.split(separator: "\n", omittingEmptySubsequences: false).count > data.count {
                    Text("... 仅显示前 \(data.count) 行 ...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private func headerBackground(row idx: Int) -> Color {
        if idx == 0 { return Color(.tertiarySystemFill) }
        return idx % 2 == 1 ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }
}

extension String.Encoding {
    static let gb_18030_2000 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}

// MARK: - HTML 预览
struct HTMLPreviewView: View {
    let url: URL
    let fileName: String

    var body: some View {
        WebView(url: url)
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - QuickLook 预览
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookView
        init(_ parent: QuickLookView) { self.parent = parent }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.url as NSURL
        }
    }
}

// MARK: - 下载后预览
struct DownloadAndPreviewView: View {
    let url: URL?
    let fileName: String
    let onDownloaded: (URL) -> Void
    @State private var isDownloading = false
    @State private var progress: Double = 0
    @State private var error: String?

    var body: some View {
        VStack(spacing: 24) {
            if let error = error {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text(error).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if isDownloading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .scaleEffect(1.2)
                    .frame(width: 200)
                Text("正在准备预览... \(Int(progress * 100))%")
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.6))
                Text("正在加载文档").foregroundStyle(.white)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { await download() }
    }

    private func download() async {
        guard let url = url else { error = "无效的 URL"; return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let destURL = cachesURL.appendingPathComponent(fileName)
            try await APIClient.shared.download(from: url, to: destURL, progress: { p in
                Task { @MainActor in
                    progress = p
                }
            })
            onDownloaded(destURL)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - 其他文件类型
struct OtherFileView: View {
    let file: FileObject
    let url: URL?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: Theme.fileIcon(for: file.fileType))
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.6))
            Text(file.name)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("此文件类型暂不支持预览")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            if let url = url {
                Link("下载文件", destination: url)
                    .foregroundStyle(Theme.primary)
            }
        }
    }
}

// MARK: - Markdown 渲染视图（使用 MarkdownUI）
struct MarkdownRenderView: View {
    let markdown: String

    var body: some View {
        Markdown(markdown)
            .markdownTheme(.gitHub)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
