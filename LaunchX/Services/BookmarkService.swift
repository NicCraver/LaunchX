import AppKit
import Foundation

// MARK: - 书签项目

struct BookmarkItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let source: BookmarkSource
    let folderPath: [String]  // 书签所在的文件夹路径

    init(title: String, url: String, source: BookmarkSource, folderPath: [String] = []) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.source = source
        self.folderPath = folderPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(source)
    }

    static func == (lhs: BookmarkItem, rhs: BookmarkItem) -> Bool {
        lhs.url == rhs.url && lhs.source == rhs.source
    }
}

// MARK: - 书签来源

enum BookmarkSource: String, Codable, CaseIterable {
    case safari = "Safari"
    case chrome = "Chrome"

    var icon: NSImage {
        switch self {
        case .safari:
            // Safari 在 macOS Sonoma+ 位于不同位置
            let possiblePaths = [
                "/Applications/Safari.app",
                "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
            ]
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    let appIcon = NSWorkspace.shared.icon(forFile: path)
                    appIcon.size = NSSize(width: 16, height: 16)
                    return appIcon
                }
            }
            return NSImage(systemSymbolName: "safari", accessibilityDescription: "Safari")
                ?? NSImage()
        case .chrome:
            let chromePath = "/Applications/Google Chrome.app"
            if FileManager.default.fileExists(atPath: chromePath) {
                let appIcon = NSWorkspace.shared.icon(forFile: chromePath)
                appIcon.size = NSSize(width: 16, height: 16)
                return appIcon
            }
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Chrome")
                ?? NSImage()
        }
    }

    var displayName: String {
        switch self {
        case .safari: return "Safari 浏览器"
        case .chrome: return "Google Chrome"
        }
    }
}

// MARK: - 书签搜索设置

struct BookmarkSettings: Codable {
    var isEnabled: Bool
    var alias: String  // 别名，如 "bk"
    var openWith: BookmarkOpenWith  // 打开方式
    var enabledSources: [BookmarkSource]  // 启用的浏览器
    var hotKeyCode: UInt32  // 快捷键 keyCode
    var hotKeyModifiers: UInt32  // 快捷键修饰键

    static let `default` = BookmarkSettings(
        isEnabled: true,
        alias: "bk",
        openWith: .defaultBrowser,
        enabledSources: [.safari, .chrome],
        hotKeyCode: 0,
        hotKeyModifiers: 0
    )

    static func load() -> BookmarkSettings {
        if let data = UserDefaults.standard.data(forKey: "bookmarkSettings"),
            let settings = try? JSONDecoder().decode(BookmarkSettings.self, from: data)
        {
            return settings
        }
        return .default
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "bookmarkSettings")
        }
    }
}

// MARK: - 书签打开方式

enum BookmarkOpenWith: String, Codable, CaseIterable {
    case bookmarkBrowser = "bookmarkBrowser"  // 书签所属浏览器
    case defaultBrowser = "defaultBrowser"  // 默认浏览器
    case safari = "safari"
    case chrome = "chrome"

    var displayName: String {
        switch self {
        case .bookmarkBrowser: return "书签浏览器"
        case .defaultBrowser: return "默认浏览器"
        case .safari: return "Safari 浏览器"
        case .chrome: return "Google Chrome"
        }
    }

    var icon: NSImage {
        switch self {
        case .bookmarkBrowser:
            return NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Bookmark")
                ?? NSImage()
        case .defaultBrowser:
            // 获取默认浏览器图标
            if let defaultBrowser = NSWorkspace.shared.urlForApplication(
                toOpen: URL(string: "https://")!)
            {
                return NSWorkspace.shared.icon(forFile: defaultBrowser.path)
            }
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Browser")
                ?? NSImage()
        case .safari:
            return BookmarkSource.safari.icon
        case .chrome:
            return BookmarkSource.chrome.icon
        }
    }
}

// MARK: - 书签服务

final class BookmarkService {
    static let shared = BookmarkService()

    private var cachedBookmarks: [BookmarkItem] = []
    private var lastLoadTime: Date?
    private let cacheValidDuration: TimeInterval = 60  // 缓存有效期 60 秒

    private init() {}

    // MARK: - 公开 API

    /// 获取所有书签
    func getAllBookmarks(forceReload: Bool = false) -> [BookmarkItem] {
        if !forceReload,
            let lastLoad = lastLoadTime,
            Date().timeIntervalSince(lastLoad) < cacheValidDuration,
            !cachedBookmarks.isEmpty
        {
            return cachedBookmarks
        }

        var bookmarks: [BookmarkItem] = []
        let settings = BookmarkSettings.load()

        for source in settings.enabledSources {
            switch source {
            case .safari:
                bookmarks.append(contentsOf: loadSafariBookmarks())
            case .chrome:
                bookmarks.append(contentsOf: loadChromeBookmarks())
            }
        }

        cachedBookmarks = bookmarks
        lastLoadTime = Date()
        return bookmarks
    }

    /// 搜索书签
    func search(query: String) -> [BookmarkItem] {
        let bookmarks = getAllBookmarks()
        guard !query.isEmpty else { return bookmarks }

        let queryLower = query.lowercased()
        return bookmarks.filter { bookmark in
            bookmark.title.lowercased().contains(queryLower)
                || bookmark.url.lowercased().contains(queryLower)
        }
    }

    /// 打开书签
    func open(_ bookmark: BookmarkItem) {
        guard let url = URL(string: bookmark.url) else { return }

        let settings = BookmarkSettings.load()

        switch settings.openWith {
        case .bookmarkBrowser:
            openWithBrowser(url: url, source: bookmark.source)
        case .defaultBrowser:
            NSWorkspace.shared.open(url)
        case .safari:
            openWithBrowser(url: url, source: .safari)
        case .chrome:
            openWithBrowser(url: url, source: .chrome)
        }
    }

    /// 清除缓存
    func clearCache() {
        cachedBookmarks = []
        lastLoadTime = nil
    }

    // MARK: - Safari 书签

    private func loadSafariBookmarks() -> [BookmarkItem] {
        let bookmarksPath = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"

        guard FileManager.default.fileExists(atPath: bookmarksPath),
            let data = FileManager.default.contents(atPath: bookmarksPath),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        else {
            print("[BookmarkService] Failed to load Safari bookmarks")
            return []
        }

        var bookmarks: [BookmarkItem] = []
        parseBookmarkFolder(plist, into: &bookmarks, source: .safari, folderPath: [])
        return bookmarks
    }

    private func parseBookmarkFolder(
        _ dict: [String: Any], into bookmarks: inout [BookmarkItem], source: BookmarkSource,
        folderPath: [String]
    ) {
        guard let children = dict["Children"] as? [[String: Any]] else { return }

        for child in children {
            let type = child["WebBookmarkType"] as? String

            if type == "WebBookmarkTypeLeaf" {
                // 这是一个书签
                if let urlDict = child["URLString"] as? String,
                    let title = (child["URIDictionary"] as? [String: Any])?["title"] as? String
                        ?? child["Title"] as? String
                {
                    let bookmark = BookmarkItem(
                        title: title,
                        url: urlDict,
                        source: source,
                        folderPath: folderPath
                    )
                    bookmarks.append(bookmark)
                }
            } else if type == "WebBookmarkTypeList" {
                // 这是一个文件夹，递归处理
                let folderTitle = child["Title"] as? String ?? ""
                var newPath = folderPath
                if !folderTitle.isEmpty && folderTitle != "BookmarksBar"
                    && folderTitle != "BookmarksMenu"
                {
                    newPath.append(folderTitle)
                }
                parseBookmarkFolder(child, into: &bookmarks, source: source, folderPath: newPath)
            }
        }
    }

    // MARK: - Chrome 书签

    private func loadChromeBookmarks() -> [BookmarkItem] {
        let bookmarksPath =
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/Bookmarks"

        guard FileManager.default.fileExists(atPath: bookmarksPath),
            let data = FileManager.default.contents(atPath: bookmarksPath),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let roots = json["roots"] as? [String: Any]
        else {
            print("[BookmarkService] Failed to load Chrome bookmarks")
            return []
        }

        var bookmarks: [BookmarkItem] = []

        // 解析书签栏
        if let bookmarkBar = roots["bookmark_bar"] as? [String: Any] {
            parseChromeBookmarkFolder(bookmarkBar, into: &bookmarks, folderPath: [])
        }

        // 解析其他书签
        if let other = roots["other"] as? [String: Any] {
            parseChromeBookmarkFolder(other, into: &bookmarks, folderPath: [])
        }

        return bookmarks
    }

    private func parseChromeBookmarkFolder(
        _ dict: [String: Any], into bookmarks: inout [BookmarkItem], folderPath: [String]
    ) {
        guard let children = dict["children"] as? [[String: Any]] else { return }

        for child in children {
            let type = child["type"] as? String

            if type == "url" {
                // 这是一个书签
                if let url = child["url"] as? String,
                    let name = child["name"] as? String
                {
                    let bookmark = BookmarkItem(
                        title: name,
                        url: url,
                        source: .chrome,
                        folderPath: folderPath
                    )
                    bookmarks.append(bookmark)
                }
            } else if type == "folder" {
                // 这是一个文件夹，递归处理
                let folderName = child["name"] as? String ?? ""
                var newPath = folderPath
                if !folderName.isEmpty {
                    newPath.append(folderName)
                }
                parseChromeBookmarkFolder(child, into: &bookmarks, folderPath: newPath)
            }
        }
    }

    // MARK: - 辅助方法

    private func openWithBrowser(url: URL, source: BookmarkSource) {
        let browserPath: String
        switch source {
        case .safari:
            browserPath = "/Applications/Safari.app"
        case .chrome:
            browserPath = "/Applications/Google Chrome.app"
        }

        let browserURL = URL(fileURLWithPath: browserPath)
        NSWorkspace.shared.open(
            [url], withApplicationAt: browserURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// 检查是否有完全磁盘访问权限（Safari 书签需要）
    func checkFullDiskAccess() -> Bool {
        let testPath = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: testPath)
    }
}
