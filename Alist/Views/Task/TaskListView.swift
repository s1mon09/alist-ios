import SwiftUI

struct TaskListView: View {
    @State private var selectedType: TaskType = .upload
    @State private var showUndone = true
    @State private var tasks: [TaskInfo] = []
    @State private var isLoading = false
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack {
            VStack {
                // 任务类型选择
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TaskType.allCases) { type in
                            Button {
                                HapticManager.light()
                                selectedType = type
                                Task { await loadTasks() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedType == type ? Theme.primary : Theme.secondaryBackground)
                                .foregroundStyle(selectedType == type ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)

                // 进行中/已完成切换
                Picker("", selection: $showUndone) {
                    Text("进行中").tag(true)
                    Text("已完成").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: showUndone) { _ in
                    Task { await loadTasks() }
                    stopAutoRefresh()
                    startAutoRefresh()
                }

                // 任务列表
                if isLoading && tasks.isEmpty {
                    LoadingView()
                } else if tasks.isEmpty {
                    EmptyStateView(
                        icon: "checklist",
                        title: "暂无任务",
                        message: "没有\(showUndone ? "进行中" : "已完成")的\(selectedType.displayName)任务"
                    )
                } else {
                    List {
                        ForEach(tasks) { task in
                            TaskRowView(
                                task: task,
                                type: selectedType,
                                onRefresh: { Task { await loadTasks() } }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("任务管理")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { Task { await loadTasks() } } label: { Label("刷新", systemImage: "arrow.clockwise") }
                        if showUndone {
                            Divider()
                            Button { Task { await clearDone() } } label: { Label("清理已完成", systemImage: "trash") }
                            Button { Task { await retryFailed() } } label: { Label("重试失败", systemImage: "arrow.clockwise.circle") }
                        }
                        if !showUndone && !tasks.isEmpty {
                            Divider()
                            Button(role: .destructive) { Task { await clearSucceeded() } } label: { Label("清理已成功", systemImage: "trash") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task { await loadTasks() }
        .onAppear { startAutoRefresh() }
        .onDisappear { stopAutoRefresh() }
    }

    private func loadTasks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tasks = showUndone
                ? try await TaskService.shared.undone(type: selectedType)
                : try await TaskService.shared.done(type: selectedType)
        } catch let error as APIError {
            ToastManager.shared.show(error.errorDescription ?? "操作失败", type: .error)
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }

    private func startAutoRefresh() {
        // 仅在进行中页面自动刷新
        guard showUndone else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { await loadTasks() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func clearDone() async {
        do {
            try await TaskService.shared.clearDone(type: selectedType)
            await loadTasks()
            HapticManager.success()
            ToastManager.shared.show("已清理", type: .success)
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }

    private func clearSucceeded() async {
        do {
            try await TaskService.shared.clearSucceeded(type: selectedType)
            await loadTasks()
            HapticManager.success()
            ToastManager.shared.show("已清理成功任务", type: .success)
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }

    private func retryFailed() async {
        do {
            try await TaskService.shared.retryFailed(type: selectedType)
            await loadTasks()
            HapticManager.success()
            ToastManager.shared.show("已重试", type: .success)
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }
}

struct TaskRowView: View {
    let task: TaskInfo
    let type: TaskType
    let onRefresh: () -> Void
    @State private var showDetail = false
    @State private var isOperating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(taskStateColor)
                    .font(.caption)
                Text(task.name).font(.subheadline).lineLimit(1)
                Spacer()
                Text("\(task.progressPercent)%").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: task.progress, total: 100)
                .tint(taskStateColor)

            HStack(spacing: 8) {
                Text(task.status).font(.caption2).foregroundStyle(.secondary)
                if !task.creator.isEmpty {
                    Text("· \(task.creator)").font(.caption2).foregroundStyle(.secondary)
                }
                if let bytes = task.totalBytes, bytes > 0 {
                    Text("· \(bytes.fileSizeFormatted)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if !task.taskState.isDone {
                    Button {
                        Task { await cancel() }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .disabled(isOperating)

                    Button {
                        Task { await retry() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(isOperating)
                } else {
                    Button {
                        Task { await delete() }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .disabled(isOperating)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            TaskDetailView(task: task, type: type)
        }
    }

    private var taskStateColor: Color {
        switch task.taskState {
        case .pending, .waitingRetry, .beforeRetry: return .orange
        case .running: return .blue
        case .succeeded: return .green
        case .failed, .errored, .failing: return .red
        case .canceled, .canceling: return .gray
        }
    }

    private func cancel() async {
        isOperating = true
        defer { isOperating = false }
        do {
            try await TaskService.shared.cancel(type: type, tid: task.id)
            HapticManager.light()
            onRefresh()
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }

    private func retry() async {
        isOperating = true
        defer { isOperating = false }
        do {
            try await TaskService.shared.retry(type: type, tid: task.id)
            HapticManager.light()
            onRefresh()
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }

    private func delete() async {
        isOperating = true
        defer { isOperating = false }
        do {
            try await TaskService.shared.delete(type: type, tid: task.id)
            HapticManager.light()
            onRefresh()
        } catch {
            ToastManager.shared.show(error.localizedDescription, type: .error)
        }
    }
}

// MARK: - 任务详情
struct TaskDetailView: View {
    let task: TaskInfo
    let type: TaskType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("任务 ID", value: task.id)
                    LabeledContent("名称", value: task.name)
                    LabeledContent("状态", value: task.status)
                    LabeledContent("类型", value: type.displayName)
                    LabeledContent("创建者", value: task.creator.isEmpty ? "—" : task.creator)
                }
                Section("进度") {
                    ProgressView(value: task.progress, total: 100)
                    LabeledContent("进度", value: "\(task.progressPercent)%")
                    if let bytes = task.totalBytes, bytes > 0 {
                        LabeledContent("总大小", value: bytes.fileSizeFormatted)
                    }
                }
                Section("时间") {
                    if let start = task.startTime {
                        LabeledContent("开始时间", value: start.formatted)
                    }
                    if let end = task.endTime {
                        LabeledContent("结束时间", value: end.formatted)
                    }
                }
                if let err = task.error, !err.isEmpty {
                    Section("错误信息") {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
                Section {
                    Button("关闭") { dismiss() }
                }
            }
            .navigationTitle("任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }
    }
}
