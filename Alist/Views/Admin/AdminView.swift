import SwiftUI

struct AdminView: View {
    var body: some View {
        List {
            Section("用户与权限") {
                NavigationLink { UserManageView() } label: { Label("用户管理", systemImage: "person.2").labelStyle(.titleAndIcon) }
                NavigationLink { RoleManageView() } label: { Label("角色管理", systemImage: "person.badge.shield.checkmark").labelStyle(.titleAndIcon) }
                NavigationLink { MetaManageView() } label: { Label("元数据管理", systemImage: "tag").labelStyle(.titleAndIcon) }
            }
            Section("存储") {
                NavigationLink { StorageManageView() } label: { Label("存储管理", systemImage: "externaldrive").labelStyle(.titleAndIcon) }
                NavigationLink { DriverListView() } label: { Label("驱动列表", systemImage: "list.bullet.below.rectangle").labelStyle(.titleAndIcon) }
            }
            Section("系统") {
                NavigationLink { SettingManageView() } label: { Label("系统设置", systemImage: "gearshape.2").labelStyle(.titleAndIcon) }
                NavigationLink { IndexManageView() } label: { Label("索引管理", systemImage: "magnifyingglass.circle").labelStyle(.titleAndIcon) }
                NavigationLink { LabelManageView() } label: { Label("标签管理", systemImage: "tag.circle").labelStyle(.titleAndIcon) }
            }
        }
        .navigationTitle("管理后台")
    }
}

// MARK: - 用户管理
struct UserManageView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var editUser: User?

    var body: some View {
        List {
            ForEach(users) { user in
                Button { editUser = user } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(user.username).font(.subheadline)
                            Text(user.basePath ?? "/").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if user.isAdmin { Text("管理员").font(.caption).foregroundStyle(.blue) }
                        if user.disabled == true { Text("已禁用").font(.caption).foregroundStyle(.red) }
                    }
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        try? await AdminUserService.shared.delete(id: users[index].id)
                    }
                    await loadUsers()
                }
            }
        }
        .navigationTitle("用户管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await loadUsers() }
        .sheet(isPresented: $showCreate) { UserEditView(user: nil) { await loadUsers() } }
        .sheet(item: $editUser) { user in UserEditView(user: user) { await loadUsers() } }
    }

    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await AdminUserService.shared.list(page: 1, perPage: 500)
            users = resp.content
        } catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
    }
}

struct UserEditView: View {
    let user: User?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var basePath = "/"
    @State private var permission: Int32 = 0
    @State private var disabled = false
    @State private var role: [Int] = [2]
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("账户") {
                    TextField("用户名", text: $username).textInputAutocapitalization(.never)
                    SecureField(user == nil ? "密码" : "新密码（留空不修改）", text: $password)
                }
                Section("路径") {
                    TextField("基础路径", text: $basePath).textInputAutocapitalization(.never)
                }
                Section("角色") {
                    Toggle("管理员", isOn: Binding(get: { role.contains(2) }, set: { if $0 { role = [2] } else { role = [0] } }))
                    Toggle("禁用", isOn: $disabled)
                }
                Section("权限位") {
                    Toggle("查看隐藏文件", isOn: bitBinding(0))
                    Toggle("免密码访问", isOn: bitBinding(1))
                    Toggle("添加离线下载", isOn: bitBinding(2))
                    Toggle("上传/创建", isOn: bitBinding(3))
                    Toggle("重命名", isOn: bitBinding(4))
                    Toggle("移动", isOn: bitBinding(5))
                    Toggle("复制", isOn: bitBinding(6))
                    Toggle("删除", isOn: bitBinding(7))
                }
            }
            .navigationTitle(user == nil ? "创建用户" : "编辑用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(isLoading) }
            }
        }
        .onAppear { if let user = user { username = user.username; basePath = user.basePath ?? "/"; permission = user.permission ?? 0; disabled = user.disabled ?? false; role = user.role ?? [0] } }
    }

    private func bitBinding(_ bit: Int) -> Binding<Bool> {
        Binding(get: { (permission >> bit) & 1 == 1 }, set: { if $0 { permission |= (1 << bit) } else { permission &= ~(1 << bit) } })
    }

    private func save() {
        Task {
            isLoading = true
            defer { isLoading = false }
            let u = User(id: user?.id ?? 0, username: username, password: password.isEmpty ? nil : password, basePath: basePath, role: role, disabled: disabled, permission: permission, ssoID: user?.ssoID, otpSecret: nil)
            do {
                if user == nil { try await AdminUserService.shared.create(user: u) }
                else { try await AdminUserService.shared.update(user: u) }
                await onSave()
                await MainActor.run { ToastManager.shared.show("保存成功", type: .success); dismiss() }
            } catch { await MainActor.run { ToastManager.shared.show(error.localizedDescription, type: .error) } }
        }
    }
}
