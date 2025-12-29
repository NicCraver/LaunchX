import AppKit
import Foundation

/// 工具类型
enum ToolType: String, Codable, CaseIterable {
    case app  // 应用/文件夹
    case webLink  // 网页直达
    case utility  // 实用工具（扩展）
    case systemCommand  // 系统命令

    /// 显示名称
    var displayName: String {
        switch self {
        case .app: return "应用"
        case .webLink: return "网页"
        case .utility: return "工具"
        case .systemCommand: return "命令"
        }
    }

    /// 分组标题
    var sectionTitle: String {
        switch self {
        case .app: return "自定义"
        case .webLink: return "网页直达"
        case .utility: return "实用工具"
        case .systemCommand: return "系统命令"
        }
    }

    /// 默认图标
    var defaultIcon: NSImage {
        switch self {
        case .app:
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        case .webLink:
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        case .utility:
            return NSImage(
                systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: nil)
                ?? NSImage()
        case .systemCommand:
            return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
        }
    }
}

/// 统一工具项目
struct ToolItem: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var type: ToolType
    var name: String
    var alias: String?
    var hotKey: HotKeyConfig?
    var isEnabled: Bool
    var isBuiltIn: Bool  // 是否为内置工具（不能删除）

    // App 特有属性
    var path: String?
    var extensionHotKey: HotKeyConfig?  // IDE/实用工具 进入扩展快捷键

    // WebLink 特有属性
    var url: String?
    var defaultUrl: String?  // 默认 URL（用户未输入 query 时使用）
    var iconData: Data?  // 自定义图标数据（PNG 格式）
    var showInSearchPanel: Bool?  // 是否在搜索面板中默认显示（仅支持 query 的网页直达有效）

    // Utility 特有属性
    var extensionIdentifier: String?  // 实用工具标识符

    // SystemCommand 特有属性 (预留)
    var command: String?

    // MARK: - 初始化方法

    /// 完整初始化
    init(
        id: UUID = UUID(),
        type: ToolType,
        name: String,
        alias: String? = nil,
        hotKey: HotKeyConfig? = nil,
        isEnabled: Bool = true,
        isBuiltIn: Bool = false,
        path: String? = nil,
        extensionHotKey: HotKeyConfig? = nil,
        url: String? = nil,
        defaultUrl: String? = nil,
        iconData: Data? = nil,
        showInSearchPanel: Bool? = nil,
        extensionIdentifier: String? = nil,
        command: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.alias = alias
        self.hotKey = hotKey
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
        self.path = path
        self.extensionHotKey = extensionHotKey
        self.url = url
        self.defaultUrl = defaultUrl
        self.iconData = iconData
        self.showInSearchPanel = showInSearchPanel
        self.extensionIdentifier = extensionIdentifier
        self.command = command
    }

    /// 从应用/文件夹路径创建
    static func app(path: String, alias: String? = nil) -> ToolItem {
        let url = URL(fileURLWithPath: path)
        var name = url.deletingPathExtension().lastPathComponent
        if path.hasSuffix(".app") {
            name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        return ToolItem(
            type: .app,
            name: name,
            alias: alias,
            path: path
        )
    }

    /// 从网页 URL 创建
    static func webLink(
        name: String, url: String, defaultUrl: String? = nil, alias: String? = nil,
        iconData: Data? = nil, showInSearchPanel: Bool? = nil
    )
        -> ToolItem
    {
        ToolItem(
            type: .webLink,
            name: name,
            alias: alias,
            url: url,
            defaultUrl: defaultUrl,
            iconData: iconData,
            showInSearchPanel: showInSearchPanel
        )
    }

    /// 从系统命令创建
    static func systemCommand(name: String, command: String, alias: String? = nil) -> ToolItem {
        ToolItem(
            type: .systemCommand,
            name: name,
            alias: alias,
            isBuiltIn: true,
            command: command
        )
    }

    /// 创建内置实用工具
    static func utility(
        name: String,
        identifier: String,
        alias: String? = nil,
        iconData: Data? = nil
    ) -> ToolItem {
        ToolItem(
            type: .utility,
            name: name,
            alias: alias,
            isEnabled: true,
            isBuiltIn: true,
            iconData: iconData,
            extensionIdentifier: identifier
        )
    }

    /// 从 CustomItem 迁移创建
    static func fromCustomItem(_ item: CustomItem) -> ToolItem {
        ToolItem(
            id: item.id,
            type: .app,
            name: item.name,
            alias: item.alias,
            hotKey: item.openHotKey,
            isEnabled: true,
            path: item.path,
            extensionHotKey: item.extensionHotKey
        )
    }

    // MARK: - 计算属性

    /// 显示名称（支持动态名称）
    /// 对于系统命令，会根据当前状态返回动态名称（如"打开/关闭自动隐藏程序坞"）
    var displayName: String {
        if type == .systemCommand, let command = command {
            return SystemCommandService.shared.getDynamicName(for: command)
        }
        return name
    }

    /// 是否为 IDE 应用
    var isIDE: Bool {
        guard type == .app, let path = path else { return false }
        return IDEType.detect(from: path) != nil
    }

    /// IDE 类型（如果是 IDE）
    var ideType: IDEType? {
        guard type == .app, let path = path else { return nil }
        return IDEType.detect(from: path)
    }

    /// 是否为应用程序
    var isApp: Bool {
        type == .app && (path?.hasSuffix(".app") ?? false)
    }

    /// 是否为文件夹
    var isDirectory: Bool {
        guard type == .app, let path = path else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
            && !path.hasSuffix(".app")
    }

    /// 是否支持 Query 扩展（URL 中包含 {query} 占位符）
    var supportsQueryExtension: Bool {
        guard type == .webLink, let url = url else { return false }
        return url.contains("{query}")
    }

    /// 是否支持扩展模式（IDE、网页直达 query、实用工具）
    var supportsExtension: Bool {
        if type == .utility { return true }
        if isIDE { return true }
        if supportsQueryExtension { return true }
        return false
    }

    /// 获取图标
    var icon: NSImage {
        switch type {
        case .app:
            if let path = path {
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 32, height: 32)
                return icon
            }
            return type.defaultIcon

        case .webLink:
            // 优先使用自定义图标
            if let data = iconData, let customIcon = NSImage(data: data) {
                customIcon.size = NSSize(width: 32, height: 32)
                return customIcon
            }
            // 使用默认图标
            let icon = type.defaultIcon
            icon.size = NSSize(width: 32, height: 32)
            return icon

        case .utility:
            // 优先使用自定义图标
            if let data = iconData, let customIcon = NSImage(data: data) {
                customIcon.size = NSSize(width: 32, height: 32)
                return customIcon
            }
            // 使用默认图标
            let icon = type.defaultIcon
            icon.size = NSSize(width: 32, height: 32)
            return icon

        case .systemCommand:
            // 根据命令类型使用不同的 SF Symbol 图标
            if let command = command,
                let identifier = SystemCommandService.Identifier(rawValue: command),
                let icon = NSImage(
                    systemSymbolName: identifier.iconName, accessibilityDescription: nil)
            {
                icon.size = NSSize(width: 32, height: 32)
                return icon
            }
            let icon = type.defaultIcon
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
    }

    /// 简化的显示路径
    var displayPath: String? {
        guard let path = path else { return nil }
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + String(path.dropFirst(homeDir.count))
        }
        return path
    }

    /// 显示的副标题（路径或 URL）
    var subtitle: String? {
        switch type {
        case .app:
            return displayPath
        case .webLink:
            return url
        case .utility:
            return extensionIdentifier
        case .systemCommand:
            return command
        }
    }

    /// 类别标签文字
    var categoryLabel: String {
        switch type {
        case .app:
            if isApp {
                return "应用"
            } else if isDirectory {
                return "文件夹"
            }
            return "应用"
        case .webLink:
            return "网页"
        case .utility:
            return "工具"
        case .systemCommand:
            return "命令"
        }
    }

    // MARK: - Equatable & Hashable

    static func == (lhs: ToolItem, rhs: ToolItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
