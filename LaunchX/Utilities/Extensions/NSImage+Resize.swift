import AppKit

// MARK: - NSImage Extensions

extension NSImage {

    /// 调整图像大小
    /// - Parameter size: 目标尺寸
    /// - Returns: 调整后的图像
    func resized(to size: NSSize) -> NSImage {
        return ImageUtils.resize(self, to: size)
    }

    /// 调整图像大小（正方形）
    /// - Parameter size: 目标边长
    /// - Returns: 调整后的图像
    func resized(to size: CGFloat) -> NSImage {
        return ImageUtils.resizeIcon(self, to: size)
    }

    /// 为图像添加色调
    /// - Parameter color: 色调颜色
    /// - Returns: 添加色调后的图像
    func tinted(with color: NSColor) -> NSImage {
        return ImageUtils.tinted(self, with: color)
    }
}
