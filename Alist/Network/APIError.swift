import Foundation

/// API 错误类型
enum APIError: Error, LocalizedError {
    case invalidURL
    case noConnection
    case unauthorized(String? = nil)
    case forbidden
    case notFound
    case rateLimited      // 429 太多请求
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .noConnection: return "无法连接到服务器"
        case .unauthorized(let msg): return msg ?? "登录已过期，请重新登录"
        case .forbidden: return "没有权限执行此操作"
        case .notFound: return "资源不存在"
        case .rateLimited: return "请求过于频繁，请稍后重试"
        case .serverError(let code, let msg): return "服务器错误(\(code)): \(msg)"
        case .decodingError(let err): return "数据解析失败: \(err.localizedDescription)"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        case .custom(let msg): return msg
        }
    }

    /// 关联消息（用于跨 case 统一提取后端消息）
    var associatedMessage: String? {
        switch self {
        case .unauthorized(let msg): return msg
        case .serverError(_, let msg): return msg
        case .custom(let msg): return msg
        default: return nil
        }
    }
}
