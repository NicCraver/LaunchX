import Foundation

// MARK: - Validation Utilities

/// 输入验证工具类
enum ValidationUtils {

    /// 验证快捷键组合是否有效
    /// - Parameters:
    ///   - keyCode: 键码
    ///   - modifiers: 修饰键
    /// - Returns: 是否为有效的快捷键组合
    static func isValidHotKeyCombination(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // 快捷键必须包含至少一个修饰键
        return modifiers != 0
    }

    /// 验证别名格式是否有效
    /// - Parameter alias: 别名字符串
    /// - Returns: 是否为有效别名
    static func isValidAlias(_ alias: String) -> Bool {
        // 别名应该是 1-10 个字母数字字符
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 && trimmed.count <= 10 else { return false }

        // 只允许字母和数字
        let alphanumericSet = CharacterSet.alphanumerics
        return trimmed.unicodeScalars.allSatisfy { alphanumericSet.contains($0) }
    }

    /// 验证时间范围是否有效
    /// - Parameter minutes: 分钟数
    /// - Returns: 是否为有效时间范围
    static func isValidTimeSpan(minutes: Int) -> Bool {
        return minutes >= 1 && minutes <= 60
    }

    /// 验证 URL 格式
    /// - Parameter urlString: URL 字符串
    /// - Returns: 是否为有效 URL
    static func isValidURL(_ urlString: String) -> Bool {
        return StringUtils.isValidURL(urlString)
    }

    /// 验证端口号是否有效
    /// - Parameter port: 端口号
    /// - Returns: 是否为有效端口
    static func isValidPort(_ port: Int) -> Bool {
        return port >= 1 && port <= 65535
    }
}
