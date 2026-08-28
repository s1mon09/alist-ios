import Foundation
import SwiftUI

// MARK: - 存储驱动分类
/// 将 Alist 驱动名映射到存储类别（本地/云盘/网络），用于在 UI 中展示直观标签
enum StorageCategory: String, CaseIterable {
    case local          // 本地存储
    case baidu          // 百度网盘
    case aliyun         // 阿里云盘
    case quark          // 夸克网盘
    case xunlei         // 迅雷云盘
    case drive115       // 115网盘
    case onedrive       // OneDrive
    case googleDrive    // Google Drive
    case dropbox        // Dropbox
    case webdav         // WebDAV
    case s3             // S3 兼容
    case ftp            // FTP/SFTP
    case samba          // Samba
    case oss            // 阿里云 OSS
    case cos            // 腾讯云 COS
    case b2             // Backblaze B2
    case media          // 媒体类（Emby/Jellyfin 等）
    case url            // URL 直链
    case archive        // 归档/压缩
    case other          // 其他

    /// 显示名称
    var displayName: String {
        switch self {
        case .local:        return "本地存储"
        case .baidu:        return "百度网盘"
        case .aliyun:       return "阿里云盘"
        case .quark:        return "夸克网盘"
        case .xunlei:       return "迅雷云盘"
        case .drive115:      return "115网盘"
        case .onedrive:     return "OneDrive"
        case .googleDrive:  return "Google Drive"
        case .dropbox:      return "Dropbox"
        case .webdav:       return "WebDAV"
        case .s3:           return "S3 对象存储"
        case .ftp:          return "FTP/SFTP"
        case .samba:        return "Samba"
        case .oss:          return "阿里云 OSS"
        case .cos:          return "腾讯云 COS"
        case .b2:           return "Backblaze B2"
        case .media:        return "媒体服务"
        case .url:          return "URL 直链"
        case .archive:      return "归档"
        case .other:        return "其他"
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .local:        return "internaldrive"
        case .baidu:        return "icloud.and.arrow.up"
        case .aliyun:       return "icloud.fill"
        case .quark:        return "bolt.icloud"
        case .xunlei:       return "icloud.and.arrow.down"
        case .drive115:      return "externaldrive.connected.to.line.below"
        case .onedrive:     return "icloud.circle"
        case .googleDrive:  return "triangle.fill"
        case .dropbox:      return "shippingbox.fill"
        case .webdav:       return "globe.asia.australia"
        case .s3:           return "server.rack"
        case .ftp:          return "rectangle.connected.to.line.below"
        case .samba:        return "folder.fill.badge.gearshape"
        case .oss:          return "externaldrive.fill"
        case .cos:          return "externaldrive.fill.badge.plus"
        case .b2:           return "hockey puck.fill"
        case .media:        return "play.rectangle.fill"
        case .url:          return "link"
        case .archive:      return "archivebox.fill"
        case .other:        return "questionmark.folder"
        }
    }

    /// 主题颜色
    var color: Color {
        switch self {
        case .local:        return .gray
        case .baidu:        return Color(hex: "2932E1")    // 百度蓝
        case .aliyun:       return Color(hex: "FF6A00")    // 阿里橙
        case .quark:        return Color(hex: "5C6BFF")
        case .xunlei:       return Color(hex: "1AB6FF")
        case .drive115:      return Color(hex: "1EAA1E")
        case .onedrive:     return Color(hex: "0078D4")
        case .googleDrive:  return Color(hex: "4285F4")
        case .dropbox:      return Color(hex: "0061FF")
        case .webdav:       return Color(hex: "2D8CFF")
        case .s3:           return Color(hex: "FF9900")
        case .ftp:          return Color(hex: "0052CC")
        case .samba:        return Color(hex: "7B68EE")
        case .oss:          return Color(hex: "FF6A00")
        case .cos:          return Color(hex: "00A4EF")
        case .b2:           return Color(hex: "E2231A")
        case .media:        return Color(hex: "6A5ACD")
        case .url:          return Color(hex: "00A8E8")
        case .archive:      return Color(hex: "8B5CF6")
        case .other:        return Color(hex: "6B7280")
        }
    }

    /// 是否为本地存储类
    var isLocal: Bool { self == .local }

    /// 是否为云盘类
    var isCloudDrive: Bool {
        switch self {
        case .baidu, .aliyun, .quark, .xunlei, .drive115,
             .onedrive, .googleDrive, .dropbox:
            return true
        default:
            return false
        }
    }

    /// 根据驱动名推断分类
    static func from(driver: String) -> StorageCategory {
        let name = driver.lowercased()
        if name.contains("local") || name == "local" { return .local }
        if name.contains("baidu") || name.contains("baidu_netdisk") { return .baidu }
        if name.contains("aliyun") || name.contains("aliyundrive") || name.contains("alipan") { return .aliyun }
        if name.contains("quark") { return .quark }
        if name.contains("thunder") || name.contains("xunlei") { return .xunlei }
        if name.contains("115") { return .drive115 }
        if name.contains("onedrive") { return .onedrive }
        if name.contains("google") || name.contains("gdrive") { return .googleDrive }
        if name.contains("dropbox") { return .dropbox }
        if name.contains("webdav") { return .webdav }
        if name.contains("s3") || name.contains("minio") || name.contains("ceph") { return .s3 }
        if name.contains("ftp") || name.contains("sftp") { return .ftp }
        if name.contains("smb") || name.contains("samba") { return .samba }
        if name.contains("oss") { return .oss }
        if name.contains("cos") || name.contains("tencent") { return .cos }
        if name.contains("b2") || name.contains("backblaze") { return .b2 }
        if name.contains("emby") || name.contains("jellyfin") || name.contains("plex") { return .media }
        if name.contains("url") { return .url }
        if name.contains("archive") || name.contains("decompress") { return .archive }
        return .other
    }
}
