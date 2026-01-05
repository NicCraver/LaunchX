import AppKit
import Combine
import Foundation

/// 剪贴板服务 - 负责剪贴板监听、内容解析、数据存储
final class ClipboardService: ObservableObject {
    static let shared = ClipboardService()

    // MARK: - Published 属性

    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var totalSize: Int64 = 0

    // MARK: - 私有属性

    private var monitorTimer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general

    // 数据存储路径
    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let clipboardDir = appSupport.appendingPathComponent(
            "LaunchX/Clipboard", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: clipboardDir, withIntermediateDirectories: true)
        return clipboardDir
    }()

    private let itemsFileURL: URL
    private let imagesDir: URL

    private init() {
        self.itemsFileURL = storageURL.appendingPathComponent("items.json")
        self.imagesDir = storageURL.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        loadItems()
        print("[ClipboardService] Initialized with \(items.count) items")
    }

    // MARK: - 监听控制

    /// 开始监听剪贴板变化
    func startMonitoring() {
        guard !isMonitoring else { return }

        let settings = ClipboardSettings.load()
        guard settings.isEnabled else {
            print("[ClipboardService] Monitoring disabled in settings")
            return
        }

        lastChangeCount = pasteboard.changeCount

        // 使用 Timer 轮询检测剪贴板变化
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            self?.checkClipboardChange()
        }

        isMonitoring = true
        print("[ClipboardService] Started monitoring")
    }

    /// 停止监听
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
        print("[ClipboardService] Stopped monitoring")
    }

    /// 重启监听（设置变化时调用）
    func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    // MARK: - 剪贴板检测

    private func checkClipboardChange() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // 注意：不再检查当前前台应用是否为 LaunchX
        // 因为截图工具等应用可能在后台运行，而 LaunchX 在前台
        // 我们仍然需要记录这些截图

        // 只检查用户配置的忽略列表中的应用
        if shouldIgnoreCurrentApp() {
            print("[ClipboardService] Ignored clipboard from excluded app")
            return
        }

        // 解析剪贴板内容
        if let item = parseClipboardContent() {
            addItem(item)
            print("[ClipboardService] Added new item: \(item.contentType.displayName)")
        }
    }

    /// 检查是否应该忽略当前前台应用
    private func shouldIgnoreCurrentApp() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
            let bundleId = frontApp.bundleIdentifier
        else {
            return false
        }

        // 不再自动忽略 LaunchX 自身
        // 这样可以正确记录截图工具等后台应用的剪贴板内容

        let settings = ClipboardSettings.load()
        return settings.ignoredAppBundleIds.contains(bundleId)
    }

    /// 获取当前前台应用信息
    private func getCurrentAppInfo() -> (bundleId: String?, name: String?) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        return (frontApp.bundleIdentifier, frontApp.localizedName)
    }

    // MARK: - 内容解析

    private func parseClipboardContent() -> ClipboardItem? {
        let appInfo = getCurrentAppInfo()

        // 调试：打印剪贴板中的所有类型
        let types = pasteboard.types ?? []
        print("[ClipboardService] Available pasteboard types: \(types.map { $0.rawValue })")

        // 1. 检查文件（优先级最高）
        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            !fileURLs.isEmpty
        {
            let paths = fileURLs.map { $0.path }
            return ClipboardItem(
                contentType: .file,
                filePaths: paths,
                sourceAppBundleId: appInfo.bundleId,
                sourceAppName: appInfo.name
            )
        }

        // 2. 检查图片（支持多种图片格式）
        // 尝试从多种常见的图片类型中读取
        var imageData: Data? = nil

        // 首先尝试直接读取常见的图片格式
        if let data = pasteboard.data(forType: .png) {
            print("[ClipboardService] Found PNG data")
            imageData = data
        } else if let data = pasteboard.data(forType: .tiff) {
            print("[ClipboardService] Found TIFF data")
            imageData = data
        } else if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            print("[ClipboardService] Found JPEG data")
            imageData = data
        } else if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.heic")) {
            print("[ClipboardService] Found HEIC data")
            imageData = data
        }

        // 如果没有找到标准格式，尝试使用 NSImage 类从剪贴板读取图片
        // 这可以处理更多的图片格式，包括某些应用特殊的剪贴板格式
        if imageData == nil {
            if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)
                as? [NSImage],
                let image = images.first
            {
                print("[ClipboardService] Found image via NSImage class")
                if let tiffData = image.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiffData),
                    let pngData = bitmap.representation(using: .png, properties: [:])
                {
                    imageData = pngData
                }
            }
        }

        // 最后尝试检查是否有任何图片相关的类型
        if imageData == nil {
            for type in types {
                let typeString = type.rawValue.lowercased()
                if typeString.contains("image") || typeString.contains("png")
                    || typeString.contains("tiff") || typeString.contains("jpeg")
                    || typeString.contains("jpg") || typeString.contains("heic")
                {
                    if let data = pasteboard.data(forType: type) {
                        print("[ClipboardService] Found image data for type: \(type.rawValue)")
                        // 尝试用 NSImage 解析
                        if let image = NSImage(data: data),
                            let tiffData = image.tiffRepresentation,
                            let bitmap = NSBitmapImageRep(data: tiffData),
                            let pngData = bitmap.representation(using: .png, properties: [:])
                        {
                            imageData = pngData
                            break
                        }
                    }
                }
            }
        }

        if let imageData = imageData {
            // 转换为 PNG 存储
            var pngData = imageData
            // 如果不是 PNG 格式，转换为 PNG
            if pasteboard.data(forType: .png) == nil {
                if let image = NSImage(data: imageData),
                    let tiffData = image.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiffData),
                    let png = bitmap.representation(using: .png, properties: [:])
                {
                    pngData = png
                }
            }

            print("[ClipboardService] Successfully parsed image, size: \(pngData.count) bytes")

            return ClipboardItem(
                contentType: .image,
                imageData: pngData,
                sourceAppBundleId: appInfo.bundleId,
                sourceAppName: appInfo.name
            )
        }

        // 3. 检查 URL（http/https）
        if let urlString = pasteboard.string(forType: .URL) {
            return ClipboardItem(
                contentType: .link,
                textContent: urlString,
                sourceAppBundleId: appInfo.bundleId,
                sourceAppName: appInfo.name
            )
        }

        // 4. 检查普通文本
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // 检查是否为 URL
            if let url = URL(string: text),
                url.scheme == "http" || url.scheme == "https"
            {
                return ClipboardItem(
                    contentType: .link,
                    textContent: text,
                    sourceAppBundleId: appInfo.bundleId,
                    sourceAppName: appInfo.name
                )
            }

            // 检查是否为颜色（十六进制格式）
            let colorPattern = "^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$"
            if let regex = try? NSRegularExpression(pattern: colorPattern),
                regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
            {
                let hex = text.hasPrefix("#") ? text : "#\(text)"
                return ClipboardItem(
                    contentType: .color,
                    colorHex: hex,
                    sourceAppBundleId: appInfo.bundleId,
                    sourceAppName: appInfo.name
                )
            }

            // 普通文本
            return ClipboardItem(
                contentType: .text,
                textContent: text,
                sourceAppBundleId: appInfo.bundleId,
                sourceAppName: appInfo.name
            )
        }

        return nil
    }

    // MARK: - 项目管理

    /// 添加新项目
    func addItem(_ item: ClipboardItem) {
        // 检查重复（相同内容不重复添加，但更新时间）
        if let existingIndex = findDuplicateIndex(for: item) {
            var existing = items[existingIndex]
            // 创建新项目，更新时间和来源
            existing = ClipboardItem(
                id: existing.id,
                contentType: existing.contentType,
                createdAt: Date(),
                isPinned: existing.isPinned,
                textContent: existing.textContent,
                imageData: existing.imageData ?? item.imageData,
                filePaths: existing.filePaths,
                colorHex: existing.colorHex,
                sourceAppBundleId: item.sourceAppBundleId,
                sourceAppName: item.sourceAppName
            )
            items.remove(at: existingIndex)
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)

            // 如果是图片，保存到磁盘
            if item.contentType == .image, let imageData = item.imageData {
                saveImageToDisk(id: item.id, data: imageData)
            }
        }

        // 执行清理策略
        applyRetentionPolicy()

        // 保存
        saveItems()
        updateTotalSize()

        // 发送通知
        NotificationCenter.default.post(
            name: NSNotification.Name("ClipboardItemsDidChange"), object: nil)
    }

    /// 查找重复项
    private func findDuplicateIndex(for item: ClipboardItem) -> Int? {
        return items.firstIndex { existing in
            switch (existing.contentType, item.contentType) {
            case (.text, .text), (.link, .link):
                return existing.textContent == item.textContent
            case (.color, .color):
                return existing.colorHex == item.colorHex
            case (.file, .file):
                return existing.filePaths == item.filePaths
            case (.image, .image):
                // 图片比较使用数据大小（简化处理）
                return existing.dataSize == item.dataSize
            default:
                return false
            }
        }
    }

    /// 删除项目
    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }

        // 删除图片文件
        if item.contentType == .image {
            deleteImageFromDisk(id: item.id)
        }

        saveItems()
        updateTotalSize()

        NotificationCenter.default.post(
            name: NSNotification.Name("ClipboardItemsDidChange"), object: nil)
    }

    /// 删除多个项目
    func removeItems(_ itemsToRemove: [ClipboardItem]) {
        for item in itemsToRemove {
            items.removeAll { $0.id == item.id }
            if item.contentType == .image {
                deleteImageFromDisk(id: item.id)
            }
        }

        saveItems()
        updateTotalSize()

        NotificationCenter.default.post(
            name: NSNotification.Name("ClipboardItemsDidChange"), object: nil)
    }

    /// 清空所有历史（保留固定项）
    func clearHistory() {
        let pinnedItems = items.filter { $0.isPinned }

        // 删除非固定项的图片
        for item in items where !item.isPinned && item.contentType == .image {
            deleteImageFromDisk(id: item.id)
        }

        items = pinnedItems
        saveItems()
        updateTotalSize()

        NotificationCenter.default.post(
            name: NSNotification.Name("ClipboardItemsDidChange"), object: nil)
    }

    /// 切换固定状态
    func togglePin(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned.toggle()
            saveItems()

            NotificationCenter.default.post(
                name: NSNotification.Name("ClipboardItemsDidChange"), object: nil)
        }
    }

    // MARK: - 粘贴功能

    /// 复制指定项目到剪贴板（保持原始格式）
    func copyToClipboard(_ item: ClipboardItem) {
        writeToClipboard(item, asPlainText: false)
        moveItemToFront(item)
    }

    /// 复制为纯文本到剪贴板
    func copyAsPlainText(_ item: ClipboardItem) {
        writeToClipboard(item, asPlainText: true)
        moveItemToFront(item)
    }

    /// 将项目移到最前面（LRU行为）
    private func moveItemToFront(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        // 如果已经在最前面，不需要移动
        if index == 0 { return }

        // 移除原位置，插入到最前面
        var movedItem = items.remove(at: index)
        // 更新时间
        movedItem = ClipboardItem(
            id: movedItem.id,
            contentType: movedItem.contentType,
            createdAt: Date(),
            isPinned: movedItem.isPinned,
            textContent: movedItem.textContent,
            imageData: movedItem.imageData,
            filePaths: movedItem.filePaths,
            colorHex: movedItem.colorHex,
            sourceAppBundleId: movedItem.sourceAppBundleId,
            sourceAppName: movedItem.sourceAppName
        )
        items.insert(movedItem, at: 0)

        // 保存并通知更新
        saveItems()
        NotificationCenter.default.post(
            name: NSNotification.Name("ClipboardItemsDidChange"), object: nil)
    }

    /// 粘贴指定项目（保持原始格式）
    func paste(_ item: ClipboardItem) {
        writeToClipboard(item, asPlainText: false)
        simulatePaste()
    }

    /// 粘贴为纯文本
    func pasteAsPlainText(_ item: ClipboardItem) {
        writeToClipboard(item, asPlainText: true)
        simulatePaste()
    }

    /// 写入剪贴板
    private func writeToClipboard(_ item: ClipboardItem, asPlainText: Bool) {
        pasteboard.clearContents()

        switch item.contentType {
        case .text, .link:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .color:
            if let hex = item.colorHex {
                pasteboard.setString(hex, forType: .string)
            }
        case .image:
            if asPlainText {
                // 纯文本模式下不粘贴图片
                return
            }
            if let data = item.imageData ?? loadImageFromDisk(id: item.id) {
                pasteboard.setData(data, forType: .png)
            }
        case .file:
            if asPlainText {
                // 纯文本模式粘贴文件路径
                if let paths = item.filePaths {
                    pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
                }
            } else {
                if let paths = item.filePaths {
                    let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                    pasteboard.writeObjects(urls)
                }
            }
        }

        // 更新 changeCount 避免重复记录
        lastChangeCount = pasteboard.changeCount
    }

    /// 模拟 Cmd+V 粘贴（公开方法）
    func simulatePasteCommand() {
        simulatePaste()
    }

    /// 模拟 Cmd+V 粘贴
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // V key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - 搜索

    /// 搜索剪贴板历史
    func search(query: String, filter: ClipboardContentType? = nil) -> [ClipboardItem] {
        var results = items

        // 类型过滤
        if let filter = filter {
            results = results.filter { $0.contentType == filter }
        }

        // 关键词搜索
        if !query.isEmpty {
            let lowercased = query.lowercased()
            results = results.filter { item in
                switch item.contentType {
                case .text, .link:
                    return item.textContent?.lowercased().contains(lowercased) ?? false
                case .color:
                    return item.colorHex?.lowercased().contains(lowercased) ?? false
                case .file:
                    return item.filePaths?.contains { $0.lowercased().contains(lowercased) }
                        ?? false
                case .image:
                    return false  // 图片不支持文本搜索
                }
            }
        }

        return results
    }

    // MARK: - 清理策略

    private func applyRetentionPolicy() {
        let settings = ClipboardSettings.load()

        // 1. 时间限制
        if settings.retentionDays != .forever {
            let cutoffDate = Calendar.current.date(
                byAdding: .day, value: -settings.retentionDays.rawValue, to: Date())!
            let expiredItems = items.filter { !$0.isPinned && $0.createdAt < cutoffDate }
            for item in expiredItems {
                items.removeAll { $0.id == item.id }
                if item.contentType == .image {
                    deleteImageFromDisk(id: item.id)
                }
            }
        }

        // 2. 条数限制
        if settings.historyLimit != .unlimited {
            let limit = settings.historyLimit.rawValue
            let nonPinnedItems = items.filter { !$0.isPinned }

            if nonPinnedItems.count > limit {
                let itemsToRemove = Array(nonPinnedItems.suffix(nonPinnedItems.count - limit))
                for item in itemsToRemove {
                    items.removeAll { $0.id == item.id }
                    if item.contentType == .image {
                        deleteImageFromDisk(id: item.id)
                    }
                }
            }
        }

        // 3. 容量限制
        updateTotalSize()
        while totalSize > settings.capacityLimit.rawValue {
            // 删除最旧的非固定项
            if let oldest = items.last(where: { !$0.isPinned }) {
                items.removeAll { $0.id == oldest.id }
                if oldest.contentType == .image {
                    deleteImageFromDisk(id: oldest.id)
                }
                updateTotalSize()
            } else {
                break
            }
        }
    }

    // MARK: - 持久化

    private func loadItems() {
        guard let data = try? Data(contentsOf: itemsFileURL),
            var loadedItems = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else {
            return
        }

        // 加载图片数据
        for i in 0..<loadedItems.count {
            if loadedItems[i].contentType == .image {
                loadedItems[i].imageData = loadImageFromDisk(id: loadedItems[i].id)
            }
        }

        items = loadedItems
        updateTotalSize()
    }

    private func saveItems() {
        // 保存时不包含图片数据（图片单独存储）
        var itemsToSave = items
        for i in 0..<itemsToSave.count {
            if itemsToSave[i].contentType == .image {
                itemsToSave[i].imageData = nil
            }
        }

        if let data = try? JSONEncoder().encode(itemsToSave) {
            try? data.write(to: itemsFileURL)
        }
    }

    private func saveImageToDisk(id: UUID, data: Data) {
        let imageURL = imagesDir.appendingPathComponent("\(id.uuidString).png")
        try? data.write(to: imageURL)
    }

    private func loadImageFromDisk(id: UUID) -> Data? {
        let imageURL = imagesDir.appendingPathComponent("\(id.uuidString).png")
        return try? Data(contentsOf: imageURL)
    }

    private func deleteImageFromDisk(id: UUID) {
        let imageURL = imagesDir.appendingPathComponent("\(id.uuidString).png")
        try? FileManager.default.removeItem(at: imageURL)
    }

    private func updateTotalSize() {
        totalSize = items.reduce(0) { $0 + $1.dataSize }
    }

    // MARK: - 统计信息

    /// 获取各类型的数量
    func getTypeCounts() -> [ClipboardContentType: Int] {
        var counts: [ClipboardContentType: Int] = [:]
        for type in ClipboardContentType.allCases {
            counts[type] = items.filter { $0.contentType == type }.count
        }
        return counts
    }
}
