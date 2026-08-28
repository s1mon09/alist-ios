import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var toastManager = ToastManager.shared

    var body: some View {
        ZStack {
            Group {
                if appState.isLoggedIn && !appState.token.isEmpty {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: appState.isLoggedIn)

            // 全局 Toast 浮层
            if toastManager.isShowing, let toast = toastManager.toast {
                VStack {
                    Spacer()
                    toast
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(false)
                .animation(.spring(), value: toastManager.isShowing)
            }
        }
        .task {
            if appState.isLoggedIn {
                await loadInitialData()
            }
        }
        .onChange(of: appState.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                Task { await loadInitialData() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { note in
            if let user = note.object as? UserResp {
                appState.currentUser = user
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
            appState.logout()
        }
    }

    private func loadInitialData() async {
        // 加载公共设置
        do {
            appState.publicSettings = try await PublicService.shared.publicSettings()
        } catch {
            // 静默处理
        }
        // 加载当前用户信息
        do {
            appState.currentUser = try await AuthService.shared.currentUser()
        } catch let error as APIError {
            if case .unauthorized = error {
                appState.logout()
            }
        } catch {
            // 忽略其他错误
        }
    }
}
