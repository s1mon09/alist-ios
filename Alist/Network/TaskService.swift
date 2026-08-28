import Foundation

/// 任务服务
final class TaskService {
    static let shared = TaskService()
    private init() {}

    // MARK: - 任务列表
    func undone(type: TaskType) async throws -> [TaskInfo] {
        try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/undone",
            responseType: [TaskInfo].self
        )
    }

    func done(type: TaskType) async throws -> [TaskInfo] {
        try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/done",
            responseType: [TaskInfo].self
        )
    }

    // MARK: - 任务操作
    func info(type: TaskType, tid: String) async throws -> TaskInfo {
        try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/info",
            method: .POST,
            query: ["tid": tid],
            responseType: TaskInfo.self
        )
    }

    func cancel(type: TaskType, tid: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/cancel",
            method: .POST,
            query: ["tid": tid],
            responseType: EmptyData.self
        )
    }

    func delete(type: TaskType, tid: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/delete",
            method: .POST,
            query: ["tid": tid],
            responseType: EmptyData.self
        )
    }

    func retry(type: TaskType, tid: String) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/retry",
            method: .POST,
            query: ["tid": tid],
            responseType: EmptyData.self
        )
    }

    // MARK: - 批量操作
    func cancelSome(type: TaskType, tids: [String]) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/cancel_some",
            method: .POST,
            body: tids,
            responseType: EmptyData.self
        )
    }

    func deleteSome(type: TaskType, tids: [String]) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/delete_some",
            method: .POST,
            body: tids,
            responseType: EmptyData.self
        )
    }

    func retrySome(type: TaskType, tids: [String]) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/retry_some",
            method: .POST,
            body: tids,
            responseType: EmptyData.self
        )
    }

    // MARK: - 清理
    func clearDone(type: TaskType) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/clear_done",
            method: .POST,
            responseType: EmptyData.self
        )
    }

    func clearSucceeded(type: TaskType) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/clear_succeeded",
            method: .POST,
            responseType: EmptyData.self
        )
    }

    func retryFailed(type: TaskType) async throws {
        _ = try await APIClient.shared.request(
            path: "/task/\(type.rawValue)/retry_failed",
            method: .POST,
            responseType: EmptyData.self
        )
    }
}
