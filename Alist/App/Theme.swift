import SwiftUI

/// 主题与颜色定义
enum Theme {
    // 主色调
    static let primary = Color(red: 0.22, green: 0.53, blue: 0.93)
    static let primaryDark = Color(red: 0.15, green: 0.4, blue: 0.78)
    static let accent = Color(red: 0.96, green: 0.55, blue: 0.38)

    // 背景色
    static let background = Color(.systemGroupedBackground)
    static let secondaryBackground = Color(.secondarySystemGroupedBackground)
    static let cardBackground = Color(.secondarySystemBackground)

    // 文字色
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    // 功能色
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let info = Color.blue

    // 文件类型颜色
    static func fileColor(for type: FileType) -> Color {
        switch type {
        case .folder: return .blue
        case .image: return .purple
        case .video: return .pink
        case .audio: return .orange
        case .document: return .red
        case .code: return .green
        case .archive: return .brown
        case .text: return .gray
        default: return .secondary
        }
    }

    // SF Symbols 图标
    static func fileIcon(for type: FileType) -> String {
        switch type {
        case .folder: return "folder.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "music.note"
        case .document: return "doc.richtext.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "archivebox.fill"
        case .text: return "doc.text.fill"
        case .pdf: return "doc.text.fill"
        default: return "doc.fill"
        }
    }
}
