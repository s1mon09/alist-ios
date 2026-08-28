import Foundation

/// Alist 通用 API 响应包装
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?

    var isSuccess: Bool { code == 200 }
}

/// 分页请求
struct PageReq: Encodable {
    var page: Int
    var perPage: Int

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
    }

    init(page: Int = 1, perPage: Int = 200) {
        self.page = page
        self.perPage = perPage
    }
}

/// 通用分页响应
struct PageResp<T: Decodable>: Decodable {
    let content: [T]
    let total: Int64
}

/// 通用空数据响应
struct EmptyData: Decodable {}

/// 通用消息响应
struct MessageResp: Decodable {
    let message: String?
}
