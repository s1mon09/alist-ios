import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needs2FA = false
    @Published var pendingUsername: String?
    @Published var pendingPassword: String?
    @Published var pendingIsLDAP = false

    func login(serverURL: String, username: String, password: String, otpCode: String = "", isLDAP: Bool = false) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmedURL = serverURL.trimmedURL
        guard trimmedURL.isValidURL else {
            errorMessage = "请输入有效的服务器地址（必须包含 http:// 或 https://）"
            return false
        }
        guard !username.isEmpty else {
            errorMessage = "请输入用户名"
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return false
        }

        // 配置服务器
        ServerConfig.shared.update(baseURL: trimmedURL)

        do {
            let resp: LoginResp
            if isLDAP {
                resp = try await AuthService.shared.loginLDAP(username: username, password: password, otpCode: otpCode)
            } else {
                resp = try await AuthService.shared.login(username: username, password: password, otpCode: otpCode)
            }

            // 保存到 Keychain（通过 AppState.token setter 触发）
            KeychainHelper.shared.save(resp.token, forKey: KeychainHelper.Key.token)
            ServerConfig.shared.update(token: resp.token)
            if let deviceKey = resp.deviceKey {
                KeychainHelper.shared.save(deviceKey, forKey: KeychainHelper.Key.deviceKey)
            }
            UserDefaults.standard.set(trimmedURL, forKey: "server_url")
            UserDefaults.standard.set(username, forKey: "username")

            // 加载当前用户
            await fetchCurrentUser()
            needs2FA = false
            pendingUsername = nil
            pendingPassword = nil
            return true
        } catch let error as APIError {
            // 检查是否需要 2FA：Alist 后端返回 401 且 message 含 2FA 关键字
            let msg = error.associatedMessage ?? ""
            let lowerMsg = msg.lowercased()
            if lowerMsg.contains("2fa") || msg.contains("两步") || lowerMsg.contains("otp") {
                needs2FA = true
                pendingUsername = username
                pendingPassword = password
                pendingIsLDAP = isLDAP
                errorMessage = "请输入两步验证码"
                return false
            }
            switch error {
            case .unauthorized(let m):
                errorMessage = (m?.isEmpty == false) ? m : "用户名或密码错误"
            default:
                errorMessage = error.errorDescription
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 使用 2FA 完成登录
    func complete2FA(otpCode: String) async -> Bool {
        guard let username = pendingUsername, let password = pendingPassword else {
            errorMessage = "会话已过期，请重新登录"
            return false
        }
        return await login(
            serverURL: ServerConfig.shared.baseURL,
            username: username,
            password: password,
            otpCode: otpCode,
            isLDAP: pendingIsLDAP
        )
    }

    func fetchCurrentUser() async {
        do {
            let user = try await AuthService.shared.currentUser()
            KeychainHelper.shared.save("\(user.id)", forKey: KeychainHelper.Key.userID)
            NotificationCenter.default.post(name: .userDidLogin, object: user)
        } catch {
            // 获取用户信息失败不影响登录流程，但需提示
            ToastManager.shared.show("获取用户信息失败: \(error.localizedDescription)", type: .warning)
            NotificationCenter.default.post(name: .userDidLogin, object: nil as Any?)
        }
    }

    func register(username: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard !username.isEmpty else {
            errorMessage = "请输入用户名"
            return false
        }
        guard password.count >= 8 else {
            errorMessage = "密码至少 8 位"
            return false
        }

        do {
            try await AuthService.shared.register(username: username, password: password)
            errorMessage = "注册成功，请登录"
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() async {
        do {
            try await AuthService.shared.logout()
        } catch {
            // 忽略错误
        }
        KeychainHelper.shared.delete(key: KeychainHelper.Key.token)
        KeychainHelper.shared.delete(key: KeychainHelper.Key.deviceKey)
        KeychainHelper.shared.delete(key: KeychainHelper.Key.userID)
        ServerConfig.shared.update(token: "")
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
}

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
}
