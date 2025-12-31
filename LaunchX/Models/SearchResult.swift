import AppKit
import Foundation

struct SearchResult: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let icon: NSImage
    let isDirectory: Bool
    let displayAlias: String?  // 用于显示的别名
    let isWebLink: Bool  // 是否为网页直达
    let isUtility: Bool  // 是否为实用工具
    let isSystemCommand: Bool  // 是否为系统命令
    let isBookmark: Bool  // 是否为书签
    let bookmarkSource: String?  // 书签来源（Safari/Chrome）
    let isBookmarkEntry: Bool  // 是否为书签搜索入口（通过别名进入）
    let is2FACode: Bool  // 是否为 2FA 验证码
    let is2FAEntry: Bool  // 是否为 2FA 入口（通过别名进入）
    let supportsQueryExtension: Bool  // 是否支持 query 扩展
    let defaultUrl: String?  // 默认 URL（用于 query 扩展）
    let isSectionHeader: Bool  // 是否为分组标题
    let processStats: String?  // 进程统计信息（CPU、内存等，靠右显示）

    init(
        id: UUID = UUID(), name: String, path: String, icon: NSImage, isDirectory: Bool,
        displayAlias: String? = nil, isWebLink: Bool = false, isUtility: Bool = false,
        isSystemCommand: Bool = false, isBookmark: Bool = false, bookmarkSource: String? = nil,
        isBookmarkEntry: Bool = false, is2FACode: Bool = false, is2FAEntry: Bool = false,
        supportsQueryExtension: Bool = false, defaultUrl: String? = nil,
        isSectionHeader: Bool = false, processStats: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.icon = icon
        self.isDirectory = isDirectory
        self.displayAlias = displayAlias
        self.isWebLink = isWebLink
        self.isUtility = isUtility
        self.isSystemCommand = isSystemCommand
        self.isBookmark = isBookmark
        self.bookmarkSource = bookmarkSource
        self.isBookmarkEntry = isBookmarkEntry
        self.is2FACode = is2FACode
        self.is2FAEntry = is2FAEntry
        self.supportsQueryExtension = supportsQueryExtension
        self.defaultUrl = defaultUrl
        self.isSectionHeader = isSectionHeader
        self.processStats = processStats
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
