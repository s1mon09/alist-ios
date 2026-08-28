import Foundation
import Alamofire

/// HTTP 方法
enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, HEAD
}

/// API 客户端（基于 Alamofire）
final class APIClient {
    static let shared = APIClient()

    private let session: Alamofire.Session
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 10
        self.session = Alamofire.Session(configuration: config)
        self.decoder = .serverDecoder
        self.encoder = .serverEncoder
    }

    // MARK: - 通用请求（带 429 自动重试）
    @discardableResult
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        query: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        // 429 自动重试：最多 3 次，指数退避
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                return try await requestOnce(
                    path: path, method: method, body: body,
                    query: query, responseType: T.self
                )
            } catch APIError.rateLimited {
                lastError = APIError.rateLimited
                // 指数退避：1s, 2s, 4s；任务被取消时直接退出重试
                let delay = UInt64(min(1 << attempt, 4)) * 1_000_000_000
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    throw lastError ?? APIError.rateLimited
                }
                continue
            } catch {
                throw error
            }
        }
        throw lastError ?? APIError.rateLimited
    }

    private func requestOnce<T: Decodable>(
        path: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        query: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let url = buildURL(path: path, query: query) else {
            throw APIError.invalidURL
        }

        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Alist-iOS/1.0",
            "Client-Id": generateClientID()
        ]
        let token = ServerConfig.shared.token
        if !token.isEmpty {
            headers["Authorization"] = token
        }

        var bodyData: Data?
        if let body = body {
            bodyData = try encoder.encode(body)
        }

        // 直接构造 URLRequest，避免 Alamofire parameters/encoding 重载的 [String: Any] 类型要求
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = afMethod(method).rawValue
        urlRequest.headers = headers
        if let bodyData = bodyData {
            urlRequest.httpBody = bodyData
        }

        let dataReq = session.request(urlRequest)

        let response = try await dataReq.serializingData().value
        let httpResponse = dataReq.response ?? HTTPURLResponse()

        return try handleResponse(data: response, statusCode: httpResponse.statusCode, responseType: T.self)
    }

    // MARK: - 处理响应
    private func handleResponse<T: Decodable>(data: Data, statusCode: Int, responseType: T.Type) throws -> T {
        guard (200...299).contains(statusCode) else {
            // 429 速率限制：抛出专用错误，由上层重试
            if statusCode == 429 { throw APIError.rateLimited }
            // 解析后端错误消息
            if let apiResp = try? decoder.decode(APIResponse<EmptyData>.self, from: data) {
                switch statusCode {
                case 401: throw APIError.unauthorized(apiResp.message.isEmpty ? nil : apiResp.message)
                case 403: throw APIError.forbidden
                case 404: throw APIError.notFound
                default: throw APIError.serverError(statusCode, apiResp.message)
                }
            }
            throw APIError.serverError(statusCode, "HTTP \(statusCode)")
        }

        // T 是 EmptyData 时，data 可能为空或无 data 字段
        if T.self == EmptyData.self {
            return EmptyData() as! T
        }

        let apiResp = try decoder.decode(APIResponse<T>.self, from: data)
        if apiResp.isSuccess {
            if let data = apiResp.data {
                return data
            }
            // 成功但无 data：尝试返回 EmptyData
            if let empty = EmptyData() as? T {
                return empty
            }
            throw APIError.custom(apiResp.message.isEmpty ? "响应无数据" : apiResp.message)
        } else {
            switch apiResp.code {
            case 401: throw APIError.unauthorized(apiResp.message.isEmpty ? nil : apiResp.message)
            case 403: throw APIError.forbidden
            case 404: throw APIError.notFound
            default: throw APIError.serverError(apiResp.code, apiResp.message)
            }
        }
    }

    // MARK: - 上传（流式，PUT）
    /// 后端 /fs/put 接口要求：
    /// - Header `File-Path`: URL编码的完整路径
    /// - Header `As-Task`: "true" 时作为任务上传
    /// - Header `Overwrite`: "false" 时拒绝覆盖
    /// - Body: 文件原始二进制
    @discardableResult
    func uploadStream(
        path: String,
        fileURL: URL,
        asTask: Bool = true,
        overwrite: Bool = true,
        progress: ((Double) -> Void)? = nil
    ) async throws -> UploadResult {
        guard let url = ServerConfig.shared.apiURL("/fs/put") else {
            throw APIError.invalidURL
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var headers: HTTPHeaders = [
            "Content-Type": "application/octet-stream",
            "File-Path": encodedPath,
            "As-Task": asTask ? "true" : "false",
            "Overwrite": overwrite ? "true" : "false",
            "User-Agent": "Alist-iOS/1.0",
            "Client-Id": generateClientID()
        ]
        let token = ServerConfig.shared.token
        if !token.isEmpty { headers["Authorization"] = token }

        // 文件大小
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0
        headers["Content-Length"] = "\(fileSize)"

        let uploadReq = session.upload(fileURL, to: url, method: .put, headers: headers)

        for await progressEvent in uploadReq.uploadProgress() {
            progress?(progressEvent.fractionCompleted)
        }

        let response = try await uploadReq.serializingData().value
        let statusCode = uploadReq.response?.statusCode ?? 500

        // 解析返回，可能包含 task 信息
        if let apiResp = try? decoder.decode(APIResponse<UploadTaskData>.self, from: response),
           apiResp.isSuccess {
            return UploadResult(task: apiResp.data?.task)
        }

        guard (200...299).contains(statusCode) else {
            if let apiResp = try? decoder.decode(APIResponse<EmptyData>.self, from: response) {
                throw APIError.serverError(statusCode, apiResp.message)
            }
            throw APIError.serverError(statusCode, "上传失败")
        }
        return UploadResult(task: nil)
    }

    // MARK: - 上传（表单，PUT）
    @discardableResult
    func uploadForm(
        path: String,
        fileURL: URL,
        asTask: Bool = true,
        overwrite: Bool = true,
        progress: ((Double) -> Void)? = nil
    ) async throws -> UploadResult {
        guard let url = ServerConfig.shared.apiURL("/fs/form") else {
            throw APIError.invalidURL
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var headers: HTTPHeaders = [
            "File-Path": encodedPath,
            "As-Task": asTask ? "true" : "false",
            "Overwrite": overwrite ? "true" : "false",
            "User-Agent": "Alist-iOS/1.0",
            "Client-Id": generateClientID()
        ]
        let token = ServerConfig.shared.token
        if !token.isEmpty { headers["Authorization"] = token }

        let uploadReq = session.upload(
            multipartFormData: { formData in
                formData.append(fileURL, withName: "file", fileName: fileURL.lastPathComponent, mimeType: "application/octet-stream")
            },
            to: url,
            method: .put,
            headers: headers
        )

        for await progressEvent in uploadReq.uploadProgress() {
            progress?(progressEvent.fractionCompleted)
        }

        let response = try await uploadReq.serializingData().value
        let statusCode = uploadReq.response?.statusCode ?? 500

        if let apiResp = try? decoder.decode(APIResponse<UploadTaskData>.self, from: response),
           apiResp.isSuccess {
            return UploadResult(task: apiResp.data?.task)
        }

        guard (200...299).contains(statusCode) else {
            if let apiResp = try? decoder.decode(APIResponse<EmptyData>.self, from: response) {
                throw APIError.serverError(statusCode, apiResp.message)
            }
            throw APIError.serverError(statusCode, "上传失败")
        }
        return UploadResult(task: nil)
    }

    // MARK: - 下载文件到本地
    func download(
        from url: URL,
        to destinationURL: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        var headers: HTTPHeaders = [
            "User-Agent": "Alist-iOS/1.0",
            "Client-Id": generateClientID()
        ]
        let token = ServerConfig.shared.token
        if !token.isEmpty { headers["Authorization"] = token }

        let dest: DownloadRequest.Destination = { _, _ in
            (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        let downloadReq = session.download(url, method: .get, headers: headers, to: dest)

        for await progressEvent in downloadReq.downloadProgress() {
            progress?(progressEvent.fractionCompleted)
        }

        let response = try await downloadReq.serializingDownloadedFileURL().value
        if !FileManager.default.fileExists(atPath: response.path) {
            throw APIError.custom("下载文件不存在")
        }
    }

    // MARK: - 获取文件原始数据（用于预览）
    func fetchData(from url: URL) async throws -> Data {
        var headers: HTTPHeaders = [
            "User-Agent": "Alist-iOS/1.0",
            "Client-Id": generateClientID()
        ]
        let token = ServerConfig.shared.token
        if !token.isEmpty { headers["Authorization"] = token }

        let req = session.request(url, method: .get, headers: headers)
        let response = try await req.serializingData().value
        let statusCode = req.response?.statusCode ?? 500
        guard (200...299).contains(statusCode) else {
            throw APIError.serverError(statusCode, "获取数据失败")
        }
        return response
    }

    // MARK: - 工具方法
    private func buildURL(path: String, query: [String: Any]?) -> URL? {
        guard let url = ServerConfig.shared.apiURL(path) else { return nil }
        guard let query = query, !query.isEmpty else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        return components?.url
    }

    private func afMethod(_ method: HTTPMethod) -> Alamofire.HTTPMethod {
        switch method {
        case .GET: return .get
        case .POST: return .post
        case .PUT: return .put
        case .DELETE: return .delete
        case .HEAD: return .head
        }
    }

    private func generateClientID() -> String {
        if let id = UserDefaults.standard.string(forKey: "client_id") {
            return id
        }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(id, forKey: "client_id")
        return id
    }
}

// MARK: - 上传结果
struct UploadResult {
    let task: UploadTaskData.TaskInfo?
}

struct UploadTaskData: Decodable {
    struct TaskInfo: Decodable {
        let id: String
        let name: String
        let progress: Double?
    }
    let task: TaskInfo?
}
