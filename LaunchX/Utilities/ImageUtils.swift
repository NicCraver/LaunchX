import AppKit

// MARK: - Image Utilities

/// 图像处理工具类
enum ImageUtils {

    /// 调整图标大小
    /// - Parameters:
    ///   - image: 原始图像
    ///   - size: 目标大小
    /// - Returns: 调整后的图像
    static func resizeIcon(_ image: NSImage, to size: CGFloat) -> NSImage {
        return resize(image, to: NSSize(width: size, height: size))
    }

    /// 调整图像大小
    /// - Parameters:
    ///   - image: 原始图像
    ///   - targetSize: 目标尺寸
    ///   - maintainAspectRatio: 是否保持宽高比
    /// - Returns: 调整后的图像
    static func resize(
        _ image: NSImage,
        to targetSize: NSSize,
        maintainAspectRatio: Bool = false
    ) -> NSImage {
        guard targetSize.width > 0 && targetSize.height > 0 else {
            return image
        }

        let finalSize: NSSize
        if maintainAspectRatio {
            let aspectRatio = image.size.width / image.size.height
            let targetAspectRatio = targetSize.width / targetSize.height

            if aspectRatio > targetAspectRatio {
                // 图像更宽，以宽度为准
                finalSize = NSSize(
                    width: targetSize.width,
                    height: targetSize.width / aspectRatio
                )
            } else {
                // 图像更高，以高度为准
                finalSize = NSSize(
                    width: targetSize.height * aspectRatio,
                    height: targetSize.height
                )
            }
        } else {
            finalSize = targetSize
        }

        let resized = NSImage(size: finalSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: finalSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }

    /// 为图像添加色调
    /// - Parameters:
    ///   - image: 原始图像
    ///   - color: 色调颜色
    /// - Returns: 添加色调后的图像
    static func tinted(_ image: NSImage, with color: NSColor) -> NSImage {
        let tinted = NSImage(size: image.size)
        tinted.lockFocus()

        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.draw(
            in: imageRect,
            from: imageRect,
            operation: .destinationIn,
            fraction: 1.0
        )

        tinted.unlockFocus()
        return tinted
    }
}
