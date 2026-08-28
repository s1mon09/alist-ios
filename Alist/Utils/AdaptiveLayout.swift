import SwiftUI

// MARK: - iPad/横屏 自适应布局
/// 在 iPad 或横屏（regular 宽度）下，限制内容最大宽度，避免列表被拉得过宽
struct AdaptiveContainerModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    func body(content: Content) -> some View {
        if hSizeClass == .regular {
            // iPad：居中并限制宽度
            content
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// 在 iPad 上限制内容最大宽度（居中显示），iPhone 保持全宽
    func adaptiveContainer() -> some View {
        modifier(AdaptiveContainerModifier())
    }
}

// MARK: - Sheet 高度适配
/// 在 iPhone 上为 sheet 添加中等高度 detent，避免内容少时占用全屏
struct AdaptiveSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }
}

extension View {
    func adaptiveSheet() -> some View {
        modifier(AdaptiveSheetModifier())
    }
}
