import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var selectedTab = 0
    @State private var showDownloads = false

    var body: some View {
        TabView(selection: $selectedTab) {
            FileBrowserView()
                .tabItem {
                    Label("文件", systemImage: "folder.fill")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(1)

            TaskListView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet.rectangle")
                }
                .tag(2)

            ShareListView()
                .tabItem {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle.fill")
                }
                .tag(4)
        }
        .tint(Theme.primary)
        .overlay(alignment: .bottom) {
            if downloadManager.hasActiveDownloads {
                Button {
                    showDownloads = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.white)
                        Text("下载中: \(downloadManager.activeDownloadsCount)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                        if downloadManager.downloads.contains(where: { $0.state == .downloading }) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.primary)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .padding(.bottom, 60)
                }
            }
        }
        .sheet(isPresented: $showDownloads) {
            DownloadsView()
        }
        // 桌面小组件 / 分享扩展通过 alistios:// URL Scheme 唤起
        .onOpenURL { url in
            if url.host == "downloads" {
                showDownloads = true
            }
        }
    }
}
