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
    let supportsQueryExtension: Bool  // 是否支持 query 扩展
    let defaultUrl: String?  // 默认 URL（用于 query 扩展）

    init(
        id: UUID = UUID(), name: String, path: String, icon: NSImage, isDirectory: Bool,
        displayAlias: String? = nil, isWebLink: Bool = false,
        supportsQueryExtension: Bool = false, defaultUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.icon = icon
        self.isDirectory = isDirectory
        self.displayAlias = displayAlias
        self.isWebLink = isWebLink
        self.supportsQueryExtension = supportsQueryExtension
        self.defaultUrl = defaultUrl
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
