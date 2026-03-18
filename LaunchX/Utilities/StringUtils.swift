import Foundation

// MARK: - String Utilities

/// 字符串处理工具类
enum StringUtils {

    /// 验证是否为有效的 URL 格式
    /// - Parameter string: 待验证的字符串
    /// - Returns: 是否为有效 URL
    static func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }

        // 检查是否可以创建 URL
        guard let url = URL(string: string) else { return false }

        // 检查是否有 scheme
        guard url.scheme != nil else { return false }

        return true
    }

    /// 截断字符串到指定长度
    /// - Parameters:
    ///   - string: 原始字符串
    ///   - maxLength: 最大长度
    ///   - suffix: 截断后添加的后缀（默认为 "..."）
    /// - Returns: 截断后的字符串
    static func truncate(_ string: String, to maxLength: Int, suffix: String = "...") -> String {
        guard string.count > maxLength else { return string }
        let endIndex = string.index(string.startIndex, offsetBy: maxLength)
        return String(string[..<endIndex]) + suffix
    }

    /// 移除字符串首尾空白字符
    /// - Parameter string: 原始字符串
    /// - Returns: 移除空白后的字符串
    static func trimmed(_ string: String) -> String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 检查字符串是否为空或只包含空白字符
    /// - Parameter string: 待检查的字符串
    /// - Returns: 是否为空白
    static func isBlank(_ string: String) -> Bool {
        return trimmed(string).isEmpty
    }
}
