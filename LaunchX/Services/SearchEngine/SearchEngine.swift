import Cocoa
import Combine
import Foundation

/// Main search engine that coordinates all components
/// Replaces NSMetadataQuery-based search with custom implementation
final class SearchEngine: ObservableObject {
    static let shared = SearchEngine()

    // MARK: - Published State (MainActor)

    @MainActor @Published private(set) var isIndexing = false
    @MainActor @Published private(set) var indexProgress: (count: Int, path: String) = (0, "")
    @MainActor @Published private(set) var isReady = false

    // Statistics
    @MainActor @Published private(set) var appsCount: Int = 0
    @MainActor @Published private(set) var filesCount: Int = 0
    @MainActor @Published private(set) var totalCount: Int = 0
    @MainActor @Published private(set) var indexingDuration: TimeInterval = 0
    @MainActor @Published private(set) var lastIndexTime: Date?

    // MARK: - Components

    private let database = IndexDatabase.shared
    private let indexer = FileIndexer()
    private let memoryIndex = MemoryIndex()
    private let fsMonitor = FSEventsMonitor()
    private let searchCache = SearchCache()
    private let performanceMonitor = SearchPerformanceMonitor.shared

    // MARK: - Thread-safe Configuration

    private let configLock = NSLock()
    private var _searchConfig: SearchConfig = SearchConfig.load()

    private var searchConfig: SearchConfig {
        get {
            configLock.lock()
            defer { configLock.unlock() }
            return _searchConfig
        }
        set {
            configLock.lock()
            _searchConfig = newValue
            configLock.unlock()
        }
    }

    private var configObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?
    private var customItemsConfigObserver: NSObjectProtocol?
    private var toolsConfigObserver: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        setupConfigObserver()
        setupCustomItemsConfigObserver()
        loadIndexOnStartup()
    }

    private func setupConfigObserver() {
        // Listen for config updates (no reindex needed)
        configObserver = NotificationCenter.default.addObserver(
            forName: .searchConfigDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let config = notification.object as? SearchConfig {
                self?.searchConfig = config
            }
        }

        // Listen for config changes that need reindex
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .searchConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let newConfig = notification.object as? SearchConfig {
                // 更新当前配置
                self.searchConfig = newConfig

                Task { @MainActor [weak self] in
                    self?.rebuildIndex()
                }
            }
        }
    }

    /// 监听自定义项目配置变化（别名更新）
    private func setupCustomItemsConfigObserver() {
        // 监听旧的 CustomItemsConfig 变化（向后兼容）
        customItemsConfigObserver = NotificationCenter.default.addObserver(
            forName: .customItemsConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadAliasMap()
        }

        // 监听新的 ToolsConfig 变化
        toolsConfigObserver = NotificationCenter.default.addObserver(
            forName: .toolsConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadAliasMap()
        }

        // 初始加载别名
        loadAliasMap()
    }

    /// 加载别名映射到内存索引
    private func loadAliasMap() {
        // 配置发生变化时，清除搜索缓存，确保别名和启用状态立即生效
        searchCache.clear()

        // 优先使用新的 ToolsConfig
        let toolsConfig = ToolsConfig.load()
        if !toolsConfig.tools.isEmpty {
            // 构建带工具信息的别名映射（仅有别名的工具）
            var aliasTools: [String: MemoryIndex.AliasToolInfo] = [:]
            // 构建所有工具列表（用于名称搜索，包括没有别名的）
            var allToolsList: [MemoryIndex.AliasToolInfo] = []

            for tool in toolsConfig.enabledTools {
                let hasAlias = tool.alias != nil && !tool.alias!.isEmpty

                switch tool.type {
                case .app:
                    if let path = tool.path {
                        let info = MemoryIndex.AliasToolInfo(
                            name: tool.name,
                            path: path,
                            isWebLink: false,
                            isUtility: false,
                            iconData: nil,
                            alias: tool.alias,
                            supportsQuery: false,
                            defaultUrl: nil
                        )
                        if hasAlias {
                            aliasTools[tool.alias!] = info
                        }
                        // 应用类型不需要加入 allToolsList，因为已经在 apps 中
                    }
                case .webLink:
                    if let url = tool.url {
                        let info = MemoryIndex.AliasToolInfo(
                            name: tool.name,
                            path: url,
                            isWebLink: true,
                            isUtility: false,
                            iconData: tool.iconData,
                            alias: tool.alias,
                            supportsQuery: tool.supportsQueryExtension,
                            defaultUrl: tool.defaultUrl
                        )
                        if hasAlias {
                            aliasTools[tool.alias!] = info
                        }
                        // 网页直达需要加入列表以支持名称搜索
                        allToolsList.append(info)
                    }
                case .utility:
                    if let identifier = tool.extensionIdentifier {
                        let info = MemoryIndex.AliasToolInfo(
                            name: tool.name,
                            path: identifier,
                            isWebLink: false,
                            isUtility: true,
                            iconData: tool.iconData,
                            alias: tool.alias,
                            supportsQuery: true,
                            defaultUrl: nil
                        )
                        if hasAlias {
                            aliasTools[tool.alias!] = info
                        }
                        allToolsList.append(info)
                    }
                case .systemCommand:
                    if let command = tool.command {
                        let info = MemoryIndex.AliasToolInfo(
                            name: tool.displayName,  // 使用动态名称
                            path: command,
                            isWebLink: false,
                            isUtility: false,
                            isSystemCommand: true,
                            iconData: nil,
                            alias: tool.alias,
                            supportsQuery: false,
                            defaultUrl: nil
                        )
                        if hasAlias {
                            aliasTools[tool.alias!] = info
                        }
                        allToolsList.append(info)
                    }
                }
            }

            memoryIndex.setAliasMapWithTools(aliasTools)
            // 设置所有工具列表（用于名称搜索）
            memoryIndex.setToolsList(allToolsList)
            print(
                "SearchEngine: Loaded \(aliasTools.count) aliases, \(allToolsList.count) tools from ToolsConfig"
            )
            return
        }

        // 回退到旧的 CustomItemsConfig
        let customConfig = CustomItemsConfig.load()
        let aliasMap = customConfig.aliasMap()
        memoryIndex.setAliasMap(aliasMap)
        print("SearchEngine: Loaded \(aliasMap.count) aliases from CustomItemsConfig")
    }

    // MARK: - Startup

    private func loadIndexOnStartup() {
        let startTime = Date()

        // Check if we have existing index
        let stats = database.getStatistics()

        if stats.totalCount > 0 {
            print("SearchEngine: Found existing index with \(stats.totalCount) items, loading...")

            // Optimized: Load in batches for better performance with large datasets
            loadIndexInBatches(startTime: startTime)
        } else {
            print("SearchEngine: No existing index, building fresh...")
            Task { @MainActor [weak self] in
                self?.buildFreshIndex()
            }
        }
    }

    /// Optimized batch loading for large datasets (600k+ files)
    /// 分批加载索引，优化大数据集的启动性能
    private func loadIndexInBatches(startTime: Date) {
        let batchSize = 10000  // Load 10k records at a time

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Get total count first
            let stats = self.database.getStatistics()
            var allRecords: [FileRecord] = []
            allRecords.reserveCapacity(stats.totalCount)

            // Load all records in batches
            var offset = 0
            while offset < stats.totalCount {
                let batch = self.database.loadBatch(offset: offset, limit: batchSize)
                allRecords.append(contentsOf: batch)
                offset += batch.count

                print("SearchEngine: Loaded \(offset)/\(stats.totalCount) records...")
            }

            // All records loaded, build memory index
            print("SearchEngine: Loaded all \(allRecords.count) records, building memory index...")

            self.memoryIndex.build(from: allRecords) { [weak self] in
                guard let self = self else { return }

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.appsCount = self.memoryIndex.appsCount
                    self.filesCount = self.memoryIndex.filesCount
                    self.totalCount = self.memoryIndex.totalCount
                    self.indexingDuration = Date().timeIntervalSince(startTime)
                    self.lastIndexTime = Date()
                    self.isReady = true

                    print(
                        "SearchEngine: Loaded index in \(String(format: "%.3f", self.indexingDuration))s"
                    )
                }

                // Start file system monitoring
                self.startMonitoring()
            }
        }
    }

    // MARK: - Index Building

    /// Build index from scratch
    @MainActor
    func buildFreshIndex() {
        guard !isIndexing else { return }

        isIndexing = true
        isReady = false
        let startTime = Date()

        // Clear existing data
        database.deleteAll { [weak self] _ in
            guard let self = self else { return }

            // Get app scopes from config
            let config = self.searchConfig

            // First, quickly scan applications
            self.indexer.scanApplications(paths: config.appScopes) { count, path in
                Task { @MainActor [weak self] in
                    self?.indexProgress = (count, path)
                }
            } completion: { [weak self] appCount, _ in
                guard let self = self else { return }

                // Then scan document directories
                let config = self.searchConfig

                self.indexer.scan(
                    paths: config.documentScopes,
                    excludedPaths: config.excludedPaths,
                    excludedNames: Set(config.excludedFolderNames),
                    excludedExtensions: Set(config.excludedExtensions),
                    progress: { count, path in
                        Task { @MainActor [weak self] in
                            self?.indexProgress = (appCount + count, path)
                        }
                    },
                    completion: { [weak self] fileCount, duration in
                        guard let self = self else { return }

                        // Load everything into memory index
                        let records = self.database.loadAllSync()
                        self.memoryIndex.build(from: records) { [weak self] in
                            guard let self = self else { return }

                            Task { @MainActor [weak self] in
                                guard let self = self else { return }
                                self.appsCount = self.memoryIndex.appsCount
                                self.filesCount = self.memoryIndex.filesCount
                                self.totalCount = self.memoryIndex.totalCount
                                self.indexingDuration = Date().timeIntervalSince(startTime)
                                self.lastIndexTime = Date()
                                self.isIndexing = false
                                self.isReady = true

                                print(
                                    "SearchEngine: Index built. Apps: \(self.appsCount), Files: \(self.filesCount), Duration: \(String(format: "%.2f", self.indexingDuration))s"
                                )
                            }

                            // Start monitoring
                            self.startMonitoring()
                        }
                    }
                )
            }
        }
    }

    /// Rebuild index (called when search scope changes)
    /// 直接使用全量重建，简单可靠
    @MainActor
    func rebuildIndex() {
        indexer.cancel()
        fsMonitor.stop()
        buildFreshIndex()
    }

    // MARK: - File System Monitoring

    private func startMonitoring() {
        let config = searchConfig
        let pathsToMonitor = config.appScopes + config.documentScopes

        fsMonitor.start(paths: pathsToMonitor) { [weak self] events in
            self?.handleFSEvents(events)
        }
    }

    private func handleFSEvents(_ events: [FSEventsMonitor.FSEvent]) {
        for event in events {
            switch event.type {
            case .created:
                addToIndex(path: event.path)
            case .deleted:
                removeFromIndex(path: event.path)
            case .modified:
                // For modifications, we could update metadata
                // For now, just re-add
                removeFromIndex(path: event.path)
                addToIndex(path: event.path)
            case .renamed:
                // Handled as create/delete
                break
            }
        }
    }

    private func addToIndex(path: String) {
        let url = URL(fileURLWithPath: path)

        // Skip if excluded
        let config = searchConfig
        if config.excludedPaths.contains(where: { path.hasPrefix($0) }) { return }

        let fileName = url.lastPathComponent
        if config.excludedFolderNames.contains(fileName) { return }

        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && config.excludedExtensions.contains(ext) { return }

        // Create record
        guard
            let resourceValues = try? url.resourceValues(forKeys: [
                .isDirectoryKey, .contentModificationDateKey,
            ])
        else { return }

        let name = url.deletingPathExtension().lastPathComponent
        let isApp = ext == "app"
        let isDir = resourceValues.isDirectory ?? false

        var pinyinFull: String? = nil
        var pinyinAcronym: String? = nil
        if name.hasMultiByteCharacters {
            pinyinFull = name.pinyin.lowercased().replacingOccurrences(of: " ", with: "")
            pinyinAcronym = name.pinyinAcronym.lowercased()
        }

        let record = FileRecord(
            name: name,
            path: path,
            extension: ext,
            isApp: isApp,
            isDirectory: isDir,
            pinyinFull: pinyinFull,
            pinyinAcronym: pinyinAcronym,
            modifiedDate: resourceValues.contentModificationDate
        )

        database.insert(record)
        memoryIndex.add(record)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.totalCount = self.memoryIndex.totalCount
            if isApp {
                self.appsCount = self.memoryIndex.appsCount
            } else {
                self.filesCount = self.memoryIndex.filesCount
            }
        }
    }

    private func removeFromIndex(path: String) {
        database.delete(path: path)
        memoryIndex.remove(path: path)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.totalCount = self.memoryIndex.totalCount
            self.appsCount = self.memoryIndex.appsCount
            self.filesCount = self.memoryIndex.filesCount
        }
    }

    // MARK: - Search

    /// Optimized synchronous search with caching and performance monitoring
    /// This is the main search API, called on every keystroke
    func searchSync(text: String) -> [SearchResult] {
        guard !text.isEmpty else { return [] }

        // Check cache first for frequently accessed queries
        if let cachedResults = searchCache.getCachedResults(for: text) {
            searchCache.recordAccess(for: text)  // Record access for learning
            return performanceMonitor.measureSearch(
                query: text,
                cacheHit: true
            ) { cachedResults }
        }

        return performanceMonitor.measureSearch(query: text, cacheHit: false) {
            let config = searchConfig

            // Use optimized search
            let items = memoryIndex.search(
                query: text,
                excludedApps: config.excludedApps,
                excludedPaths: config.excludedPaths,
                excludedExtensions: Set(config.excludedExtensions),
                excludedFolderNames: Set(config.excludedFolderNames)
            )

            var results = items.map { $0.toSearchResult() }

            // 添加书签搜索结果
            let bookmarkResults = searchBookmarks(query: text)
            results.append(contentsOf: bookmarkResults)

            // Cache results if beneficial
            searchCache.cacheResults(results, for: text, accessCount: 1)

            return results
        }
    }

    // MARK: - 书签搜索

    /// 搜索书签
    private func searchBookmarks(query: String) -> [SearchResult] {
        let settings = BookmarkSettings.load()
        guard settings.isEnabled else { return [] }

        let bookmarks = BookmarkService.shared.search(query: query)
        return bookmarks.prefix(10).map { bookmark in
            SearchResult(
                name: bookmark.title,
                path: bookmark.url,
                icon: bookmark.source.icon,
                isDirectory: false,
                isBookmark: true,
                bookmarkSource: bookmark.source.rawValue
            )
        }
    }

    // MARK: - 默认搜索网页直达

    /// 获取设置为默认显示在搜索面板的网页直达列表
    /// 仅返回已启用、支持 query 扩展且设置了 showInSearchPanel 的网页直达
    func getDefaultSearchWebLinks() -> [SearchResult] {
        let toolsConfig = ToolsConfig.load()
        var results: [SearchResult] = []

        for tool in toolsConfig.enabledTools {
            // 只处理网页直达
            guard tool.type == .webLink,
                let url = tool.url,
                tool.supportsQueryExtension,
                tool.showInSearchPanel == true
            else { continue }

            // 创建图标
            var icon: NSImage
            if let iconData = tool.iconData, let customIcon = NSImage(data: iconData) {
                customIcon.size = NSSize(width: 32, height: 32)
                icon = customIcon
            } else {
                icon =
                    NSImage(systemSymbolName: "globe", accessibilityDescription: "Web Link")
                    ?? NSImage()
                icon.size = NSSize(width: 32, height: 32)
            }

            let result = SearchResult(
                name: tool.name,
                path: url,
                icon: icon,
                isDirectory: false,
                displayAlias: tool.alias,
                isWebLink: true,
                supportsQueryExtension: true,
                defaultUrl: tool.defaultUrl
            )
            results.append(result)
        }

        return results
    }
}
