import SwiftUI
import CodeScanner

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authVM: AuthViewModel
    @State private var serverURL: String = UserDefaults.standard.string(forKey: "server_url") ?? ""
    @State private var username: String = UserDefaults.standard.string(forKey: "username") ?? ""
    @State private var password: String = ""
    @State private var otpCode: String = ""
    @State private var isLDAP = false
    @State private var showRegister = false
    @State private var showSettings = false
    @State private var showScanner = false
    @State private var showRecentServers = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Theme.primary)
                        Text("Alist")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.primary)
                        Text("连接到你的服务器")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.top, 20)

                    // 表单
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("服务器地址").font(.caption).foregroundStyle(Theme.secondaryText)
                                Spacer()
                                Button { showRecentServers = true } label: {
                                    Label("历史", systemImage: "clock")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.primary)
                                }
                                Button { showScanner = true } label: {
                                    Label("扫码", systemImage: "qrcode.viewfinder")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                            HStack {
                                Image(systemName: "globe").foregroundStyle(Theme.secondaryText)
                                TextField("https://your-server.com", text: $serverURL)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                if !serverURL.isEmpty {
                                    Button(action: { serverURL = "" }) {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("用户名").font(.caption).foregroundStyle(Theme.secondaryText)
                            HStack {
                                Image(systemName: "person").foregroundStyle(Theme.secondaryText)
                                TextField("admin", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding(12)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码").font(.caption).foregroundStyle(Theme.secondaryText)
                            HStack {
                                Image(systemName: "lock").foregroundStyle(Theme.secondaryText)
                                SecureField("密码", text: $password)
                                if !password.isEmpty {
                                    Button(action: { password = "" }) {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if authVM.needs2FA {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("两步验证码").font(.caption).foregroundStyle(Theme.secondaryText)
                                HStack {
                                    Image(systemName: "shield").foregroundStyle(Theme.secondaryText)
                                    TextField("6 位验证码", text: $otpCode)
                                        .keyboardType(.numberPad)
                                        .onChange(of: otpCode) { new in
                                            if new.count > 6 { otpCode = String(new.prefix(6)) }
                                        }
                                }
                                .padding(12)
                                .background(Theme.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Toggle(isOn: $isLDAP) {
                            Label("LDAP 登录", systemImage: "person.badge.key")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal)

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }

                    // 按钮组
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                let success = await authVM.login(
                                    serverURL: serverURL,
                                    username: username,
                                    password: password,
                                    otpCode: otpCode,
                                    isLDAP: isLDAP
                                )
                                if success {
                                    appState.serverURL = serverURL
                                    appState.token = ServerConfig.shared.token
                                    appState.addRecentServer(serverURL.trimmedURL)
                                }
                            }
                        } label: {
                            HStack {
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                }
                                Text(authVM.needs2FA ? "验证并登录" : "登录").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(authVM.isLoading || serverURL.isEmpty || username.isEmpty || password.isEmpty || (authVM.needs2FA && otpCode.count != 6))

                        Button("注册新账号") { showRegister = true }
                            .font(.subheadline)
                            .foregroundStyle(Theme.primary)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .background(Theme.background)
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRegister) {
                RegisterView(serverURL: $serverURL)
            }
            .sheet(isPresented: $showScanner) {
                CodeScannerView(
                    codeTypes: [.qr],
                    simulatedData: "https://al.nn.ci",
                    completion: { result in
                        showScanner = false
                        switch result {
                        case .success(let scan):
                            var code = scan.string
                            // 去除可能的尾部斜杠和路径
                            if code.hasSuffix("/") { code.removeLast() }
                            serverURL = code
                        case .failure(let err):
                            authVM.errorMessage = "扫码失败: \(err.localizedDescription)"
                        }
                    }
                )
            }
            .confirmationDialog("最近服务器", isPresented: $showRecentServers, titleVisibility: .visible) {
                if appState.recentServers.isEmpty {
                    Button("无历史记录", role: .cancel) {}
                } else {
                    ForEach(appState.recentServers, id: \.self) { url in
                        Button(url) { serverURL = url }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}

struct RegisterView: View {
    @Binding var serverURL: String
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("服务器地址", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("账号信息") {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码（至少 8 位）", text: $password)
                    SecureField("确认密码", text: $confirmPassword)
                }
                if let error = authVM.errorMessage {
                    Section { Text(error).foregroundStyle(Theme.danger) }
                }
            }
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("注册") {
                        guard password == confirmPassword else {
                            authVM.errorMessage = "两次输入的密码不一致"
                            return
                        }
                        Task {
                            let success = await authVM.register(username: username, password: password)
                            if success { dismiss() }
                        }
                    }
                    .disabled(username.isEmpty || password.count < 8)
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
        .environmentObject(AuthViewModel())
}
