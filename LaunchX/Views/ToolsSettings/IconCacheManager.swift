import SwiftUI

// MARK: - 图标缓存管理器

class IconCacheManager {
    static let shared = IconCacheManager()
    private var cache: [UUID: NSImage] = [:]
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.launchx.iconcache", qos: .userInitiated)

    func getIcon(for tool: ToolItem) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[tool.id]
    }

    func loadIcon(for tool: ToolItem, completion: @escaping (NSImage) -> Void) {
        // 使用锁保护缓存读取，防止多线程竞争导致崩溃
        lock.lock()
        if let cached = cache[tool.id] {
            lock.unlock()
            completion(cached)
            return
        }
        lock.unlock()

        // 在后台加载图标
        queue.async { [weak self] in
            let icon = tool.icon

            if let self = self {
                // 使用锁保护缓存写入
                self.lock.lock()
                self.cache[tool.id] = icon
                self.lock.unlock()
            }

            DispatchQueue.main.async {
                completion(icon)
            }
        }
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}
