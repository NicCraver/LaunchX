import SwiftUI

/// 设置页面顶部样式常量
enum SettingsHeaderStyle {
    /// 图标尺寸（字体大小）
    static let iconSize: CGFloat = 20

    /// 图标固定 frame 尺寸（确保所有图标占用相同空间）
    static let iconFrameSize: CGFloat = 24

    /// 图标和标题之间的间距
    static let iconTitleSpacing: CGFloat = 12

    /// 标题字体
    static let titleFont: Font = .title2

    /// 标题字重
    static let titleFontWeight: Font.Weight = .bold

    /// 水平内边距
    static let horizontalPadding: CGFloat = 20

    /// 顶部内边距
    static let topPadding: CGFloat = 20

    /// 底部内边距
    static let bottomPadding: CGFloat = 16
}

