import SwiftUI

// MARK: - 系统设置管理
struct SettingManageView: View {
    @State private var settings: [SettingItem] = []
    @State private var currentGroup: SettingGroup = .site
    @State private var editedValues: [String: String] = [:]
    @State private var isLoading = false

    var filteredSettings: [SettingItem] {
        settings.filter { $0.group == currentGroup.rawValue }
    }

    var body: some View {
        VStack {
            // 分组选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SettingGroup.allCases, id: \.self) { group in
                        Button {
                            currentGroup = group
                        } label: {
                            Text(group.name)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(currentGroup == group ? Theme.primary : Theme.secondaryBackground)
                                .foregroundStyle(currentGroup == group ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            List {
                ForEach(filteredSettings) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.key).font(.subheadline)
                        if let help = item.help, !help.isEmpty {
                            Text(help).font(.caption2).foregroundStyle(.secondary)
                        }
                        settingInput(for: item)
                    }
                }
            }
        }
        .navigationTitle("系统设置")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { Task { await saveSettings() } }.disabled(isLoading)
            }
        }
        .task { await loadSettings() }
    }

    @ViewBuilder
    private func settingInput(for item: SettingItem) -> some View {
        let value = Binding(
            get: { editedValues[item.key] ?? item.value },
            set: { editedValues[item.key] = $0 }
        )
        switch item.type {
        case "bool":
            Toggle("", isOn: Binding(get: { value.wrappedValue == "true" }, set: { value.wrappedValue = $0 ? "true" : "false" })).labelsHidden()
        case "number":
            TextField("值", text: value).keyboardType(.numberPad)
        case "select":
            if let options = item.options {
                Picker("值", selection: value) {
                    ForEach(options.split(separator: ",").map { String($0) }, id: \.self) { Text($0).tag($0) }
                }
            } else {
                TextField("值", text: value)
            }
        default:
            TextField("值", text: value)
        }
    }

    private func loadSettings() async {
        isLoading = true; defer { isLoading = false }
        do { settings = try await AdminSettingService.shared.list() } catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
    }

    private func saveSettings() async {
        isLoading = true; defer { isLoading = false }
        var items: [SettingItem] = []
        for (key, value) in editedValues {
            if let orig = settings.first(where: { $0.key == key }) {
                items.append(SettingItem(key: key, value: value, help: orig.help, type: orig.type, options: orig.options, group: orig.group, flag: orig.flag, index: orig.index))
            }
        }
        do {
            try await AdminSettingService.shared.save(items: items)
            await MainActor.run { ToastManager.shared.show("保存成功", type: .success); editedValues.removeAll() }
        } catch { await MainActor.run { ToastManager.shared.show(error.localizedDescription, type: .error) } }
    }
}

// MARK: - 索引管理
struct IndexManageView: View {
    @State private var progress: IndexProgress?
    @State private var isLoading = false
    @State private var timer: Timer?

    var body: some View {
        Form {
            Section("索引状态") {
                if let p = progress {
                    if let total = p.total, total > 0 {
                        ProgressView(value: Double(p.current ?? 0), total: Double(total))
                        Text("\(p.current ?? 0) / \(total)").font(.caption).foregroundStyle(.secondary)
                    }
                    LabeledContent("完成", value: p.done == true ? "是" : "否")
                } else {
                    Text("加载中...").foregroundStyle(.secondary)
                }
            }
            Section("操作") {
                Button { Task { await buildIndex() } } label: { Label("构建索引", systemImage: "hammer") }
                Button { Task { await updateIndex() } } label: { Label("更新索引", systemImage: "arrow.clockwise") }
                Button { Task { await stopIndex() } } label: { Label("停止", systemImage: "stop.circle") }.foregroundStyle(.orange)
                Button(role: .destructive) { Task { await clearIndex() } } label: { Label("清空索引", systemImage: "trash") }
            }
        }
        .navigationTitle("索引管理")
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    private func startPolling() {
        Task { await loadProgress() }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in Task { await loadProgress() } }
    }
    private func stopPolling() { timer?.invalidate(); timer = nil }

    private func loadProgress() async {
        do { progress = try await AdminIndexService.shared.progress() } catch {
            ToastManager.shared.show("加载索引进度失败: \(error.localizedDescription)", type: .error)
        }
    }
    private func buildIndex() async { do { try await AdminIndexService.shared.build(); ToastManager.shared.show("已开始构建", type: .success) } catch { ToastManager.shared.show(error.localizedDescription, type: .error) } }
    private func updateIndex() async { do { try await AdminIndexService.shared.update(); ToastManager.shared.show("已开始更新", type: .success) } catch { ToastManager.shared.show(error.localizedDescription, type: .error) } }
    private func stopIndex() async { do { try await AdminIndexService.shared.stop(); ToastManager.shared.show("已停止", type: .success) } catch { ToastManager.shared.show(error.localizedDescription, type: .error) } }
    private func clearIndex() async { do { try await AdminIndexService.shared.clear(); ToastManager.shared.show("已清空", type: .success) } catch { ToastManager.shared.show(error.localizedDescription, type: .error) } }
}

// MARK: - 标签管理
struct LabelManageView: View {
    @State private var labels: [FileLabel] = []
    @State private var showCreate = false
    @State private var editLabel: FileLabel?

    var body: some View {
        List {
            ForEach(labels) { label in
                Button { editLabel = label } label: {
                    HStack {
                        Text(label.name)
                        Spacer()
                        Text(label.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(label.bgColor.map { Color(hex: $0) } ?? .gray)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .onDelete { idx in Task { for i in idx { try? await LabelService.shared.delete(id: labels[i].id) }; await loadLabels() } }
        }
        .navigationTitle("标签管理")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .task { await loadLabels() }
        .sheet(isPresented: $showCreate) { LabelEditView(label: nil) { await loadLabels() } }
        .sheet(item: $editLabel) { l in LabelEditView(label: l) { await loadLabels() } }
    }

    private func loadLabels() async {
        do { labels = try await LabelService.shared.list() } catch { ToastManager.shared.show(error.localizedDescription, type: .error) }
    }
}

struct LabelEditView: View {
    let label: FileLabel?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var bgColor = "#3B82F6"
    @State private var type = 0
    @State private var isLoading = false
    private let colors = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899", "#6B7280"]

    var body: some View {
        NavigationStack {
            Form {
                Section("标签信息") {
                    TextField("名称", text: $name)
                    TextField("描述", text: $description)
                    Stepper("类型: \(type)", value: $type, in: 0...10)
                }
                Section("颜色") {
                    HStack {
                        ForEach(colors, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 32, height: 32)
                                .overlay { if bgColor == c { Image(systemName: "checkmark").foregroundStyle(.white) } }
                                .onTapGesture { bgColor = c }
                        }
                    }
                }
            }
            .navigationTitle(label == nil ? "创建标签" : "编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(isLoading) }
            }
        }
        .onAppear { if let l = label { name = l.name; description = l.description ?? ""; bgColor = l.bgColor ?? "#3B82F6"; type = l.type ?? 0 } }
    }

    private func save() {
        Task {
            isLoading = true; defer { isLoading = false }
            do {
                if label == nil { try await LabelService.shared.create(name: name, description: description, bgColor: bgColor, type: type) }
                else { try await LabelService.shared.update(id: label!.id, name: name, description: description, bgColor: bgColor, type: type) }
                await onSave()
                await MainActor.run { ToastManager.shared.show("保存成功", type: .success); dismiss() }
            } catch { await MainActor.run { ToastManager.shared.show(error.localizedDescription, type: .error) } }
        }
    }
}
