import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showSessions = false
    @State private var showSSHKeys = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var show2FA = false
    @State private var showAdmin = false

    var body: some View {
        NavigationStack {
            List {
                // 用户信息
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.2))
                                .frame(width: 60, height: 60)
                            Text(String((appState.currentUser?.username ?? "U").prefix(1)).uppercased())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.primary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.currentUser?.username ?? "未登录")
                                .font(.headline)
                            HStack(spacing: 4) {
                                ForEach(appState.currentUser?.roleNames ?? [], id: \.self) { role in
                                    Text(role)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.primary.opacity(0.2))
                                        .foregroundStyle(Theme.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // 账户操作
                Section("账户") {
                    NavigationLink {
                        EditProfileView()
                    } label: { Label("编辑资料", systemImage: "person") }

                    Button { show2FA = true } label: {
                        Label(appState.currentUser?.otp == true ? "两步验证（已启用）" : "两步验证", systemImage: "shield")
                    }

                    Button { showSessions = true } label: {
                        Label("会话管理", systemImage: "iphone")
                    }

                    Button { showSSHKeys = true } label: {
                        Label("SSH 公钥", systemImage: "key")
                    }
                }

                // 管理后台
                if appState.currentUser?.isAdmin == true {
                    Section("管理") {
                        NavigationLink {
                            AdminView()
                        } label: { Label("管理后台", systemImage: "shield.lefthalf.filled") }
                    }
                }

                // 设置
                Section("设置") {
                    NavigationLink {
                        SettingsView()
                    } label: { Label("应用设置", systemImage: "gear") }

                    NavigationLink {
                        AboutView()
                    } label: { Label("关于", systemImage: "info.circle") }
                }

                // 退出登录
                Section {
                    Button(role: .destructive) {
                        Task { await authVM.logout() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showSessions) { SessionListView() }
            .sheet(isPresented: $showSSHKeys) { SSHKeyListView() }
            .sheet(isPresented: $show2FA) { TwoFAView() }
        }
    }
}

// MARK: - 编辑资料
struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var basePath = ""
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("账户信息") {
                TextField("用户名", text: $username).textInputAutocapitalization(.never)
                SecureField("新密码（留空不修改）", text: $password)
                TextField("基础路径", text: $basePath).textInputAutocapitalization(.never)
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        // 保留原有的 disabled/otpSecret，避免被重置
                        let user = User(
                            id: appState.currentUser?.id ?? 0,
                            username: username,
                            password: password.isEmpty ? nil : password,
                            basePath: basePath,
                            role: appState.currentUser?.role,
                            disabled: appState.currentUser?.disabled,
                            permission: appState.currentUser?.permission,
                            ssoID: appState.currentUser?.ssoID,
                            otpSecret: nil
                        )
                        do {
                            try await AuthService.shared.updateCurrent(user: user)
                            appState.currentUser?.username = username
                            appState.currentUser?.basePath = basePath
                            ToastManager.shared.show("保存成功", type: .success)
                        } catch {
                            ToastManager.shared.show(error.localizedDescription, type: .error)
                        }
                    }
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            username = appState.currentUser?.username ?? ""
            basePath = appState.currentUser?.basePath ?? ""
        }
    }
}

// MARK: - 两步验证
struct TwoFAView: View {
    @Environment(\.dismiss) var dismiss
    @State private var qrCode = ""
    @State private var secret = ""
    @State private var code = ""
    @State private var isLoading = false
    @State private var generated = false

    var body: some View {
        NavigationStack {
            Form {
                if !qrCode.isEmpty {
                    Section("扫描二维码") {
                        // 显示 QR 码 URL，由于无法直接渲染 base64 PNG，显示 secret
                        Text("请使用验证器 App 添加以下密钥").font(.caption)
                        Text(secret)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                Section("验证码") {
                    TextField("6 位验证码", text: $code)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("两步验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("验证") { verify() }.disabled(code.count != 6 || isLoading)
                }
            }
            .onAppear { generate() }
        }
    }

    private func generate() {
        Task {
            do {
                let resp = try await AuthService.shared.generate2FA()
                qrCode = resp.qr
                secret = resp.secret
                generated = true
            } catch {
                ToastManager.shared.show(error.localizedDescription, type: .error)
            }
        }
    }

    private func verify() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await AuthService.shared.verify2FA(code: code, secret: secret)
                await MainActor.run {
                    ToastManager.shared.show("两步验证已启用", type: .success)
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

// MARK: - 关于
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.primary)
                    Text("Alist iOS").font(.title2.bold())
                    Text("版本 1.0.0").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            Section("项目") {
                Link(destination: URL(string: "https://alistgo.com")!) {
                    Label("官方网站", systemImage: "globe")
                }
                Link(destination: URL(string: "https://github.com/alist-org/alist")!) {
                    Label("GitHub 仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://alistgo.com/guide/")!) {
                    Label("使用文档", systemImage: "book")
                }
            }
            Section("说明") {
                Text("Alist 是一个支持多种存储的文件列表程序。本应用为 iOS 客户端，连接到您自建的 Alist 服务器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
