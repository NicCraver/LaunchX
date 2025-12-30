import Foundation

// MARK: - LRU 缓存节点（双向链表）

private final class LRUNode<Key: Hashable, Value> {
    let key: Key
    var value: Value
    var prev: LRUNode?
    var next: LRUNode?

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

// MARK: - 通用 LRU 缓存（哈希表 + 双向链表，O(1) 操作）

private final class LRUCache<Key: Hashable, Value> {
    private var cache: [Key: LRUNode<Key, Value>] = [:]
    private var head: LRUNode<Key, Value>?  // 最近使用
    private var tail: LRUNode<Key, Value>?  // 最久未使用
    private let capacity: Int

    var count: Int { cache.count }

    init(capacity: Int) {
        self.capacity = capacity
    }

    /// 获取值（O(1)）
    func get(_ key: Key) -> Value? {
        guard let node = cache[key] else { return nil }
        moveToHead(node)
        return node.value
    }

    /// 插入或更新值（O(1)）
    func put(_ key: Key, value: Value) {
        if let node = cache[key] {
            // 已存在，更新值并移到头部
            node.value = value
            moveToHead(node)
        } else {
            // 新节点
            let newNode = LRUNode(key: key, value: value)
            cache[key] = newNode
            addToHead(newNode)

            // 超过容量则移除尾部节点
            if cache.count > capacity {
                if let tailNode = removeTail() {
                    cache.removeValue(forKey: tailNode.key)
                }
            }
        }
    }

    /// 移除指定 key（O(1)）
    func remove(_ key: Key) {
        guard let node = cache[key] else { return }
        removeNode(node)
        cache.removeValue(forKey: key)
    }

    /// 检查是否包含 key（O(1)）
    func contains(_ key: Key) -> Bool {
        return cache[key] != nil
    }

    /// 获取所有 key（按 LRU 顺序，最近的在前）
    func allKeys() -> [Key] {
        var keys: [Key] = []
        var current = head
        while let node = current {
            keys.append(node.key)
            current = node.next
        }
        return keys
    }

    /// 清空缓存
    func clear() {
        cache.removeAll()
        head = nil
        tail = nil
    }

    // MARK: - 双向链表操作

    private func addToHead(_ node: LRUNode<Key, Value>) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func removeNode(_ node: LRUNode<Key, Value>) {
        let prev = node.prev
        let next = node.next

        if let prev = prev {
            prev.next = next
        } else {
            head = next
        }

        if let next = next {
            next.prev = prev
        } else {
            tail = prev
        }

        node.prev = nil
        node.next = nil
    }

    private func moveToHead(_ node: LRUNode<Key, Value>) {
        guard node !== head else { return }
        removeNode(node)
        addToHead(node)
    }

    private func removeTail() -> LRUNode<Key, Value>? {
        guard let tailNode = tail else { return nil }
        removeNode(tailNode)
        return tailNode
    }
}

// MARK: - 最近使用项目类型

enum RecentItemType: String, Codable {
    case app  // 应用
    case webLink  // 网页直达
    case utility  // 实用工具
    case systemCommand  // 系统命令
}

// MARK: - 最近使用项目

struct RecentItem: Codable, Equatable {
    let type: RecentItemType
    let identifier: String  // app: path, webLink: url, utility: extensionIdentifier, systemCommand: command
    let name: String
    let timestamp: Date

    /// 唯一标识符（用于 LRU 的 key）
    var uniqueKey: String {
        "\(type.rawValue):\(identifier)"
    }

    static func == (lhs: RecentItem, rhs: RecentItem) -> Bool {
        lhs.uniqueKey == rhs.uniqueKey
    }
}

// MARK: - 最近使用管理器（支持所有工具类型）

final class RecentAppsManager {
    static let shared = RecentAppsManager()

    private let userDefaultsKey = "recentItems_v2"  // 新版本 key，支持所有类型
    private let legacyKey = "recentAppPaths"  // 旧版本 key，用于迁移
    private let maxCapacity = 30  // 最多记录 30 个项目

    // 内存中的 LRU 缓存（O(1) 操作）
    private var lruCache: LRUCache<String, RecentItem>
    private let queue = DispatchQueue(label: "com.launchx.recentmanager", qos: .userInitiated)

    private init() {
        lruCache = LRUCache(capacity: maxCapacity)
        loadFromDisk()
        migrateLegacyData()
    }

    // MARK: - 公开 API

    /// 记录项目被使用（O(1)）
    func recordUsage(type: RecentItemType, identifier: String, name: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let item = RecentItem(
                type: type,
                identifier: identifier,
                name: name,
                timestamp: Date()
            )

            self.lruCache.put(item.uniqueKey, value: item)
            self.saveToDisk()
        }
    }

    /// 记录应用被打开（兼容旧 API）
    func recordAppOpen(path: String) {
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        recordUsage(type: .app, identifier: path, name: name)
    }

    /// 记录网页直达被使用
    func recordWebLinkOpen(url: String, name: String) {
        recordUsage(type: .webLink, identifier: url, name: name)
    }

    /// 记录实用工具被使用
    func recordUtilityOpen(identifier: String, name: String) {
        recordUsage(type: .utility, identifier: identifier, name: name)
    }

    /// 记录系统命令被执行
    func recordSystemCommandOpen(command: String, name: String) {
        recordUsage(type: .systemCommand, identifier: command, name: name)
    }

    /// 获取最近使用的项目（按 LRU 顺序）
    func getRecentItems(limit: Int = 5, types: Set<RecentItemType>? = nil) -> [RecentItem] {
        var result: [RecentItem] = []

        queue.sync {
            let allKeys = lruCache.allKeys()

            for key in allKeys {
                guard result.count < limit else { break }

                if let item = lruCache.get(key) {
                    // 如果指定了类型过滤
                    if let types = types, !types.contains(item.type) {
                        continue
                    }

                    // 验证项目仍然有效
                    if isItemValid(item) {
                        result.append(item)
                    }
                }
            }
        }

        return result
    }

    /// 获取最近使用的应用路径（兼容旧 API）
    func getRecentApps(limit: Int = 8) -> [String] {
        let items = getRecentItems(limit: limit, types: [.app])
        return items.map { $0.identifier }
    }

    /// 清空历史
    func clearHistory() {
        queue.async { [weak self] in
            self?.lruCache.clear()
            self?.saveToDisk()
        }
    }

    // MARK: - 私有方法

    /// 验证项目是否仍然有效
    private func isItemValid(_ item: RecentItem) -> Bool {
        switch item.type {
        case .app:
            // 检查应用是否存在
            return FileManager.default.fileExists(atPath: item.identifier)
        case .webLink:
            // 网页直达始终有效（URL 可能已在配置中删除，但这里不做检查）
            return true
        case .utility:
            // 实用工具始终有效
            return true
        case .systemCommand:
            // 系统命令始终有效
            return true
        }
    }

    /// 从磁盘加载
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let items = try? JSONDecoder().decode([RecentItem].self, from: data)
        else {
            return
        }

        // 按时间倒序重建 LRU 缓存（最旧的先插入，最新的后插入）
        let sortedItems = items.sorted { $0.timestamp < $1.timestamp }
        for item in sortedItems {
            lruCache.put(item.uniqueKey, value: item)
        }
    }

    /// 保存到磁盘
    private func saveToDisk() {
        let keys = lruCache.allKeys()
        var items: [RecentItem] = []

        for key in keys {
            if let item = lruCache.get(key) {
                items.append(item)
            }
        }

        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// 迁移旧版数据
    private func migrateLegacyData() {
        guard let legacyPaths = UserDefaults.standard.stringArray(forKey: legacyKey),
            !legacyPaths.isEmpty
        else {
            return
        }

        // 只在新数据为空时迁移
        guard lruCache.count == 0 else { return }

        // 倒序插入，保持 LRU 顺序
        for path in legacyPaths.reversed() {
            let name = (path as NSString).lastPathComponent.replacingOccurrences(
                of: ".app", with: "")
            let item = RecentItem(
                type: .app,
                identifier: path,
                name: name,
                timestamp: Date()
            )
            lruCache.put(item.uniqueKey, value: item)
        }

        saveToDisk()

        // 清除旧数据
        UserDefaults.standard.removeObject(forKey: legacyKey)
        print("[RecentAppsManager] Migrated \(legacyPaths.count) legacy app paths")
    }
}
