import SwiftUI

// MARK: - 角色管理
struct RoleManageView: View {
    @State private var roles: [Role] = []
    @State private var showCreate = false
    @State private var editRole: Role?

    var body: some View {
        List {
            ForEach(roles) { role in
                Button { editRole = role } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(role.name).font(.subheadline)
                            if role.default == true { Text("默认").font(.caption).foregroundStyle(.blue) }
                            Spacer()
                        }
                        if let desc = role.description { Text(desc).font(.caption).foregroundStyle(.secondary) }
                        Text("\(role.permissionScopes?.count ?? 0) 个权限范围").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idx in Task { for i in idx { try? await AdminRoleService.shared.delete(id: roles[i].id) }; await loadRoles() } }
        }
        .navigationTitle("角色管理")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .task { await loadRoles() }
        .sheet(isPresented: $showCreate) { RoleEditView(role: nil) { await loadRoles() } }
        .sheet(item: $editRole) { r in RoleEditView(role: r) { await loadRoles() } }
    }

    private func loadRoles() async {
        do { roles = try await AdminRoleService.shared.list() } catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
    }
}

struct RoleEditView: View {
    let role: Role?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var permissions: [PermissionEntry] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("角色名", text: $name)
                    TextField("描述", text: $description)
                }
                Section {
                    if permissions.isEmpty {
                        Text("暂无权限范围").foregroundStyle(.secondary).font(.caption)
                    }
                    ForEach(permissions) { perm in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("路径", text: permissionPathBinding(for: perm.id))
                                .textInputAutocapitalization(.never)
                                .font(.subheadline)
                            Picker("权限", selection: permissionValueBinding(for: perm.id)) {
                                Text("只读 (0)").tag(Int32(0))
                                Text("查看+下载 (8)").tag(Int32(8))
                                Text("上传 (16)").tag(Int32(16))
                                Text("管理 (256)").tag(Int32(256))
                                Text("自定义").tag(Int32(-1))
                            }
                            if perm.permission == -1 {
                                HStack {
                                    Text("自定义权限值")
                                    Spacer()
                                    TextField("", value: permissionValueBinding(for: perm.id), format: .number)
                                        .keyboardType(.numberPad)
                                        .frame(width: 100)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { permissions.remove(atOffsets: $0) }
                    Button { permissions.append(PermissionEntry(path: "/", permission: 0)) } label: { Label("添加权限范围", systemImage: "plus") }
                } header: {
                    HStack {
                        Text("权限范围")
                        Spacer()
                        Text("\(permissions.count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(role == nil ? "创建角色" : "编辑角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(isLoading || name.isEmpty) }
            }
        }
        .onAppear { if let r = role { name = r.name; description = r.description ?? ""; permissions = r.permissionScopes ?? [] } }
    }

    private func permissionPathBinding(for id: String) -> Binding<String> {
        Binding(get: { permissions.first { $0.id == id }?.path ?? "" },
                set: { newValue in if let idx = permissions.firstIndex(where: { $0.id == id }) { permissions[idx].path = newValue } })
    }

    private func permissionValueBinding(for id: String) -> Binding<Int32> {
        Binding(get: { permissions.first { $0.id == id }?.permission ?? 0 },
                set: { newValue in if let idx = permissions.firstIndex(where: { $0.id == id }) { permissions[idx].permission = newValue } })
    }

    private func save() {
        Task {
            isLoading = true; defer { isLoading = false }
            let r = Role(id: role?.id ?? 0, name: name, description: description, default: role?.default, permissionScopes: permissions)
            do {
                if role == nil { try await AdminRoleService.shared.create(role: r) } else { try await AdminRoleService.shared.update(role: r) }
                await onSave()
                await MainActor.run { ToastManager.shared.show("保存成功", type: .success); dismiss() }
            } catch { await MainActor.run { ToastManager.shared.show(error.localizedDescription, type: .error) } }
        }
    }
}

// MARK: - Meta 管理
struct MetaManageView: View {
    @State private var metas: [Meta] = []
    @State private var showCreate = false
    @State private var editMeta: Meta?

    var body: some View {
        List {
            ForEach(metas) { meta in
                Button { editMeta = meta } label: {
                    VStack(alignment: .leading) {
                        Text(meta.path).font(.subheadline)
                        HStack(spacing: 6) {
                            if !(meta.password ?? "").isEmpty { Image(systemName: "lock").font(.caption2) }
                            if meta.write { Image(systemName: "pencil").font(.caption2) }
                            if !(meta.hide ?? "").isEmpty { Image(systemName: "eye.slash").font(.caption2) }
                            if !(meta.readme ?? "").isEmpty { Image(systemName: "doc.text").font(.caption2) }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idx in Task { for i in idx { try? await AdminMetaService.shared.delete(id: metas[i].id) }; await loadMetas() } }
        }
        .navigationTitle("元数据管理")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .task { await loadMetas() }
        .sheet(isPresented: $showCreate) { MetaEditView(meta: nil) { await loadMetas() } }
        .sheet(item: $editMeta) { m in MetaEditView(meta: m) { await loadMetas() } }
    }

    private func loadMetas() async {
        do { metas = try await AdminMetaService.shared.list() } catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
    }
}

struct MetaEditView: View {
    let meta: Meta?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var path = ""
    @State private var password = ""
    @State private var pSub = false
    @State private var write = false
    @State private var wSub = false
    @State private var hide = ""
    @State private var hSub = false
    @State private var readme = ""
    @State private var rSub = false
    @State private var header = ""
    @State private var headerSub = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("路径") { TextField("路径", text: $path).textInputAutocapitalization(.never) }
                Section("密码保护") {
                    SecureField("密码", text: $password)
                    Toggle("应用到子目录", isOn: $pSub)
                }
                Section("写入权限") {
                    Toggle("允许写入", isOn: $write)
                    Toggle("应用到子目录", isOn: $wSub)
                }
                Section("隐藏文件") {
                    TextEditor(text: $hide).frame(height: 80).font(.caption)
                    Toggle("应用到子目录", isOn: $hSub)
                }
                Section("README") {
                    TextEditor(text: $readme).frame(height: 80).font(.caption)
                    Toggle("应用到子目录", isOn: $rSub)
                }
                Section("头部内容") {
                    TextEditor(text: $header).frame(height: 80).font(.caption)
                    Toggle("应用到子目录", isOn: $headerSub)
                }
            }
            .navigationTitle(meta == nil ? "创建 Meta" : "编辑 Meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(isLoading) }
            }
        }
        .onAppear { if let m = meta { path = m.path; password = m.password ?? ""; pSub = m.pSub; write = m.write; wSub = m.wSub; hide = m.hide ?? ""; hSub = m.hSub; readme = m.readme ?? ""; rSub = m.rSub; header = m.header ?? ""; headerSub = m.headerSub } }
    }

    private func save() {
        Task {
            isLoading = true; defer { isLoading = false }
            let m = Meta(id: meta?.id ?? 0, path: path, password: password, pSub: pSub, write: write, wSub: wSub, hide: hide, hSub: hSub, readme: readme, rSub: rSub, header: header, headerSub: headerSub)
            do {
                if meta == nil { try await AdminMetaService.shared.create(meta: m) } else { try await AdminMetaService.shared.update(meta: m) }
                await onSave()
                await MainActor.run { ToastManager.shared.show("保存成功", type: .success); dismiss() }
            } catch { await MainActor.run { ToastManager.shared.show(error.localizedDescription, type: .error) } }
        }
    }
}
