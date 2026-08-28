import SwiftUI

struct StorageManageView: View {
    @State private var storages: [Storage] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var editStorage: Storage?
    @State private var searchText = ""

    /// 按类别分组
    var groupedStorages: [(StorageCategory, [Storage])] {
        let filtered = searchText.isEmpty ? storages : storages.filter { $0.mountPath.localizedCaseInsensitiveContains(searchText) || $0.driver.localizedCaseInsensitiveContains(searchText) || $0.remark.localizedCaseInsensitiveContains(searchText) }
        let groups = Dictionary(grouping: filtered) { StorageCategory.from(driver: $0.driver) }
        return StorageCategory.allCases
            .compactMap { cat in groups[cat].map { (cat, $0) } }
            .sorted { lhs, rhs in
                // 本地优先，然后云盘，最后其他
                let order: (StorageCategory) -> Int = {
                    if $0 == .local { return 0 }
                    if $0.isCloudDrive { return 1 }
                    return 2
                }
                if order(lhs.0) != order(rhs.0) { return order(lhs.0) < order(rhs.0) }
                return lhs.0.displayName < rhs.0.displayName
            }
    }

    var body: some View {
        List {
            if !searchText.isEmpty || storages.count > 5 {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("筛选存储...", text: $searchText)
                            .textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        }
                    }
                }
            }

            ForEach(groupedStorages, id: \.0.rawValue) { category, items in
                Section {
                    ForEach(items) { storage in
                        Button { editStorage = storage } label: {
                            storageRow(storage: storage, category: category)
                        }
                        .swipeActions {
                            Button {
                                Task {
                                    if storage.disabled { try? await AdminStorageService.shared.enable(id: storage.id) }
                                    else { try? await AdminStorageService.shared.disable(id: storage.id) }
                                    await loadStorages()
                                }
                            } label: { Label(storage.disabled ? "启用" : "禁用", systemImage: storage.disabled ? "checkmark.circle" : "stop.circle") }
                            .tint(storage.disabled ? .green : .orange)

                            Button(role: .destructive) {
                                Task { try? await AdminStorageService.shared.delete(id: storage.id); await loadStorages() }
                            } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon).foregroundStyle(category.color).font(.caption)
                        Text(category.displayName)
                        Spacer()
                        Text("\(items.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if storages.isEmpty && !isLoading {
                Section {
                    EmptyStateView(icon: "externaldrive", title: "暂无存储", message: "点击右上角添加存储")
                        .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("存储管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showCreate = true } label: { Label("添加存储", systemImage: "plus") }
                    Button { Task { try? await AdminStorageService.shared.loadAll(); await loadStorages() } } label: { Label("重新加载", systemImage: "arrow.clockwise") }
                    Button { Task { await loadStorages() } } label: { Label("刷新列表", systemImage: "arrow.triangle.2.circlepath") }
                } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .task { await loadStorages() }
        .sheet(isPresented: $showCreate) { StorageEditView(storage: nil) { await loadStorages() } }
        .sheet(item: $editStorage) { s in StorageEditView(storage: s) { await loadStorages() } }
    }

    @ViewBuilder
    private func storageRow(storage: Storage, category: StorageCategory) -> some View {
        HStack(spacing: 12) {
            // 存储类型图标
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .font(.system(size: 18, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(storage.mountPath).font(.subheadline.weight(.medium))
                    Spacer()
                    if storage.disabled {
                        Text("已禁用").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.15)).foregroundStyle(.red).clipShape(Capsule())
                    } else {
                        Text("正常").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15)).foregroundStyle(.green).clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(storage.driver).font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(category.displayName).font(.caption).foregroundStyle(category.color)
                    if !storage.remark.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(storage.remark).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if !storage.status.isEmpty && storage.status != "work" {
                    Text(storage.status).font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func loadStorages() async {
        isLoading = true
        defer { isLoading = false }
        do { storages = try await AdminStorageService.shared.list() }
        catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
    }
}

struct StorageEditView: View {
    let storage: Storage?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var mountPath = ""
    @State private var driver = ""
    @State private var driverNames: [String] = []
    @State private var remark = ""
    @State private var cacheExpiration = 30
    @State private var orderBy = "name"
    @State private var orderDirection = "asc"
    @State private var webProxy = false
    @State private var webdavPolicy = "native_proxy"
    @State private var enableSign = false
    @State private var isLoading = false
    @State private var driverAdditions: [DriverAddition] = []
    @State private var additionValues: [String: String] = [:]
    @State private var hasLoadedDriver = false

    /// 当前驱动的分类
    var currentCategory: StorageCategory {
        StorageCategory.from(driver: driver)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    HStack {
                        Image(systemName: currentCategory.icon)
                            .foregroundStyle(currentCategory.color)
                        Text(currentCategory.displayName)
                            .font(.caption)
                            .foregroundStyle(currentCategory.color)
                    }
                    TextField("挂载路径", text: $mountPath).textInputAutocapitalization(.never)
                    Picker("驱动", selection: $driver) {
                        Text("请选择...").tag("")
                        ForEach(driverNames, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: driver) { newDriver in
                        guard !newDriver.isEmpty else { return }
                        loadDriverInfo()
                    }
                    TextField("备注", text: $remark)
                    Stepper("缓存时间: \(cacheExpiration)分钟", value: $cacheExpiration, in: 0...9999)
                }

                Section("排序") {
                    Picker("排序字段", selection: $orderBy) {
                        Text("名称").tag("name")
                        Text("大小").tag("size")
                        Text("修改时间").tag("modified")
                    }
                    Picker("排序方向", selection: $orderDirection) {
                        Text("升序").tag("asc")
                        Text("降序").tag("desc")
                    }
                }

                Section("代理") {
                    Toggle("Web 代理", isOn: $webProxy)
                    Picker("WebDAV 策略", selection: $webdavPolicy) {
                        Text("原生代理").tag("native_proxy")
                        Text("302 跳转").tag("302_redirect")
                        Text("使用代理 URL").tag("use_proxy_url")
                    }
                    Toggle("启用签名", isOn: $enableSign)
                }

                if !driverAdditions.isEmpty {
                    Section("驱动配置") {
                        ForEach(driverAdditions) { addition in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(addition.name).font(.subheadline)
                                    if addition.required == true {
                                        Text("*").foregroundStyle(.red).font(.caption)
                                    }
                                    Spacer()
                                    if let help = addition.help, !help.isEmpty {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .help(help)
                                    }
                                }
                                additionInput(for: addition)
                                if let def = addition.default, !def.isEmpty {
                                    Text("默认: \(def)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(storage == nil ? "添加存储" : "编辑存储")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(isLoading || mountPath.isEmpty || driver.isEmpty) }
            }
        }
        .task {
            if let names = try? await DriverService.shared.names() { driverNames = names.sorted() }
            if let storage = storage {
                mountPath = storage.mountPath
                driver = storage.driver
                remark = storage.remark
                cacheExpiration = storage.cacheExpiration
                orderBy = storage.orderBy ?? "name"
                orderDirection = storage.orderDirection ?? "asc"
                webProxy = storage.webProxy
                webdavPolicy = storage.webdavPolicy
                enableSign = storage.enableSign
                // 解析已有 addition 到 additionValues
                parseExistingAddition(storage.addition)
                loadDriverInfo()
            }
        }
    }

    @ViewBuilder
    private func additionInput(for addition: DriverAddition) -> some View {
        let value = Binding<String>(
            get: { additionValues[addition.name] ?? "" },
            set: { additionValues[addition.name] = $0 }
        )
        switch addition.type.lowercased() {
        case "bool":
            Toggle("", isOn: Binding(get: { value.wrappedValue == "true" }, set: { value.wrappedValue = $0 ? "true" : "false" }))
                .labelsHidden()
        case "select":
            if let options = addition.options, !options.isEmpty {
                Picker(addition.name, selection: value) {
                    ForEach(options.split(separator: ",").map { String($0) }, id: \.self) { Text($0).tag($0) }
                }
            } else {
                TextField(addition.default ?? "请输入", text: value)
                    .textInputAutocapitalization(.never)
            }
        default:
            TextField(addition.default ?? "请输入", text: value)
                .textInputAutocapitalization(.never)
        }
    }

    /// 解析已有 addition JSON 字符串到 additionValues
    private func parseExistingAddition(_ jsonString: String) {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (key, val) in obj {
            additionValues[key] = "\(val)"
        }
    }

    private func loadDriverInfo() {
        guard !driver.isEmpty else { return }
        Task {
            do {
                let info = try await DriverService.shared.info(name: driver)
                driverAdditions = info.addition
                // 保留已解析的值，未设置的补上默认值
                for add in info.addition {
                    if additionValues[add.name] == nil, let def = add.default {
                        additionValues[add.name] = def
                    }
                }
            } catch {
                ToastManager.shared.show("加载驱动信息失败: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func save() {
        Task {
            isLoading = true
            defer { isLoading = false }
            // addition 只包含非空值
            let filtered = additionValues.filter { !$0.value.isEmpty }
            let additionJSON = (try? JSONSerialization.data(withJSONObject: filtered))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let s = Storage(
                id: storage?.id ?? 0, mountPath: mountPath, order: storage?.order ?? 0,
                driver: driver, cacheExpiration: cacheExpiration, status: storage?.status ?? "",
                addition: additionJSON, remark: remark, modified: Date(), disabled: false,
                disableIndex: storage?.disableIndex ?? false, enableSign: enableSign,
                orderBy: orderBy, orderDirection: orderDirection, extractFolder: storage?.extractFolder ?? "",
                webProxy: webProxy, webdavPolicy: webdavPolicy, proxyRange: storage?.proxyRange ?? false,
                downProxyUrl: storage?.downProxyUrl, downProxySign: storage?.downProxySign
            )
            do {
                if storage == nil { try await AdminStorageService.shared.create(storage: s) }
                else { try await AdminStorageService.shared.update(storage: s) }
                await onSave()
                await MainActor.run { ToastManager.shared.show("保存成功", type: .success); dismiss() }
            } catch { await MainActor.run { ToastManager.shared.show(error.localizedDescription, type: .error) } }
        }
    }
}

extension Data {
    func `let`<T>(_ transform: (Data) -> T) -> T { transform(self) }
}

// MARK: - 驱动列表
struct DriverListView: View {
    @State private var drivers: [DriverInfo] = []
    @State private var isLoading = false
    @State private var searchText = ""

    /// 按类别分组
    var groupedDrivers: [(StorageCategory, [DriverInfo])] {
        let filtered = searchText.isEmpty ? drivers : drivers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        let groups = Dictionary(grouping: filtered) { StorageCategory.from(driver: $0.name) }
        return StorageCategory.allCases
            .compactMap { cat in groups[cat].map { (cat, $0) } }
            .sorted { lhs, rhs in
                let order: (StorageCategory) -> Int = {
                    if $0 == .local { return 0 }
                    if $0.isCloudDrive { return 1 }
                    return 2
                }
                if order(lhs.0) != order(rhs.0) { return order(lhs.0) < order(rhs.0) }
                return lhs.0.displayName < rhs.0.displayName
            }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("筛选驱动...", text: $searchText)
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
            }

            ForEach(groupedDrivers, id: \.0.rawValue) { category, items in
                Section {
                    ForEach(items) { driver in
                        NavigationLink {
                            DriverDetailView(driver: driver)
                        } label: {
                            driverRow(driver: driver, category: category)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon).foregroundStyle(category.color).font(.caption)
                        Text(category.displayName)
                        Spacer()
                        Text("\(items.count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            if drivers.isEmpty && !isLoading {
                Section {
                    EmptyStateView(icon: "externaldrive", title: "暂无驱动", message: "")
                        .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("驱动列表")
        .overlay { if isLoading { LoadingView() } }
        .task {
            isLoading = true
            defer { isLoading = false }
            do { drivers = try await DriverService.shared.list().sorted { $0.name < $1.name } } catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
        }
    }

    @ViewBuilder
    private func driverRow(driver: DriverInfo, category: StorageCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(driver.name).font(.subheadline)
                Text(category.displayName).font(.caption2).foregroundStyle(category.color)
            }
            Spacer()
            if driver.onlyProxy == true { Text("仅代理").font(.caption2).foregroundStyle(.orange) }
            if driver.onlyLocal == true { Text("仅本地").font(.caption2).foregroundStyle(.green) }
        }
    }
}

struct DriverDetailView: View {
    let driver: DriverInfo

    var category: StorageCategory { StorageCategory.from(driver: driver.name) }

    var body: some View {
        Form {
            Section("驱动信息") {
                HStack {
                    Image(systemName: category.icon).foregroundStyle(category.color)
                    Text(category.displayName).foregroundStyle(category.color)
                }
                LabeledContent("名称", value: driver.config.name)
                if let v = driver.config.localSort { LabeledContent("本地排序", value: v ? "是" : "否") }
                if let v = driver.config.onlyLocal { LabeledContent("仅本地", value: v ? "是" : "否") }
                if let v = driver.config.onlyProxy { LabeledContent("仅代理", value: v ? "是" : "否") }
                if let v = driver.config.noCache { LabeledContent("无缓存", value: v ? "是" : "否") }
                if let v = driver.config.noUpload { LabeledContent("禁止上传", value: v ? "是" : "否") }
            }
            if let alert = driver.config.alert {
                Section("提示") { Text(alert).foregroundStyle(.orange) }
            }
            Section("附加配置项") {
                if driver.addition.isEmpty {
                    Text("无").foregroundStyle(.secondary)
                } else {
                    ForEach(driver.addition) { addition in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(addition.name).font(.subheadline)
                                if addition.required == true {
                                    Text("*").foregroundStyle(.red).font(.caption)
                                }
                                Spacer()
                                Text(addition.type).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.secondaryBackground)
                                    .clipShape(Capsule())
                            }
                            if let help = addition.help { Text(help).font(.caption2).foregroundStyle(.secondary) }
                            if let def = addition.default { Text("默认: \(def)").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
        .navigationTitle(driver.name)
    }
}
