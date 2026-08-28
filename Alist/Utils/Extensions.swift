import Foundation
import SwiftUI

// MARK: - 视图扩展
extension View {
    @ViewBuilder
    func ifLet<T, Transform: View>(_ value: T?, transform: (Self, T) -> Transform) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 字符串扩展
extension String {
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }

    var trimmedURL: String {
        var result = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    var fileNameExtension: String {
        (self as NSString).pathExtension.lowercased()
    }

    var fileNameWithoutExtension: String {
        (self as NSString).deletingPathExtension
    }

    var encodedPath: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}

// MARK: - 日期格式化
extension Date {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .short
        return f
    }()

    var formatted: String {
        Date.formatter.string(from: self)
    }

    var relativeFormatted: String {
        Date.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - 文件大小格式化
extension Int64 {
    var fileSizeFormatted: String {
        let size = Double(self)
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var index = 0
        var value = size
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%.2f %@", value, units[index])
    }
}

extension Int {
    var fileSizeFormatted: String {
        Int64(self).fileSizeFormatted
    }
}

// MARK: - JSON 编码辅助
extension Encodable {
    var dictionary: [String: Any]? {
        guard let data = try? JSONEncoder.serverEncoder.encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)) as? [String: Any]
    }
}

// MARK: - JSONEncoder 配置
extension JSONEncoder {
    static let serverEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let serverDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Alist 服务端返回的日期格式不固定，这里使用多种策略兼容
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // 尝试 ISO8601
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: str) {
                return date
            }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: str) {
                return date
            }
            // 尝试自定义格式
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ",
                           "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS",
                           "yyyy-MM-dd'T'HH:mm:ss"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: str) {
                    return date
                }
            }
            return Date(timeIntervalSince1970: 0)
        }
        return decoder
    }()
}
