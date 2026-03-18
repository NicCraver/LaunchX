import Foundation

// MARK: - String Extensions

extension String {

    /// 检查字符串是否为有效的 URL
    var isValidURL: Bool {
        return StringUtils.isValidURL(self)
    }

    /// 截断字符串到指定长度
    /// - Parameters:
    ///   - maxLength: 最大长度
    ///   - suffix: 截断后添加的后缀（默认为 "..."）
    /// - Returns: 截断后的字符串
    func truncated(to maxLength: Int, suffix: String = "...") -> String {
        return StringUtils.truncate(self, to: maxLength, suffix: suffix)
    }

    /// 移除首尾空白字符
    var trimmed: String {
        return StringUtils.trimmed(self)
    }

    /// 检查字符串是否为空或只包含空白字符
    var isBlank: Bool {
        return StringUtils.isBlank(self)
    }
}
