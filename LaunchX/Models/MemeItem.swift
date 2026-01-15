import Foundation

/// 表情包搜索结果项
struct MemeItem: Identifiable, Equatable {
    let id: UUID
    let imageURL: String  // 图片 URL
    let description: String  // 描述文字
    let isGif: Bool  // 是否为 GIF

    init(id: UUID = UUID(), imageURL: String, description: String, isGif: Bool) {
        self.id = id
        self.imageURL = imageURL
        self.description = description
        self.isGif = isGif
    }
}

/// 收藏的表情包项（包含本地存储的图片数据）
struct MemeFavoriteItem: Identifiable, Codable, Equatable {
    let id: UUID
    let imageFileName: String  // 本地存储的文件名
    let description: String  // 描述文字
    let searchKeyword: String  // 搜索时使用的关键词
    let isGif: Bool  // 是否为 GIF
    let createdAt: Date  // 收藏时间
    let originalURL: String  // 原始 URL（用于去重）

    init(
        id: UUID = UUID(),
        imageFileName: String,
        description: String,
        searchKeyword: String,
        isGif: Bool,
        originalURL: String
    ) {
        self.id = id
        self.imageFileName = imageFileName
        self.description = description
        self.searchKeyword = searchKeyword
        self.isGif = isGif
        self.createdAt = Date()
        self.originalURL = originalURL
    }

    /// 转换为 MemeItem（用于在 UI 中统一显示）
    func toMemeItem() -> MemeItem {
        return MemeItem(
            id: id,
            imageURL: imageFileName,  // 使用本地文件名
            description: description,
            isGif: isGif
        )
    }
}

/// 表情包搜索设置
struct MemeSearchSettings: Codable {
    var isEnabled: Bool = true
    var alias: String = "bqb"
    var hotKeyCode: UInt32 = 0
    var hotKeyModifiers: UInt32 = 0

    // MARK: - 持久化

    private static let userDefaultsKey = "MemeSearchSettings"

    static func load() -> MemeSearchSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let settings = try? JSONDecoder().decode(MemeSearchSettings.self, from: data)
        else {
            return MemeSearchSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: MemeSearchSettings.userDefaultsKey)
        }
    }
}

/// 表情包收藏设置
struct MemeFavoriteSettings: Codable {
    var isEnabled: Bool = true
    var alias: String = "sc"  // 收藏的别名
    var hotKeyCode: UInt32 = 0
    var hotKeyModifiers: UInt32 = 0
    var autoFavorite: Bool = true  // 复制时自动加入收藏

    // MARK: - 持久化

    private static let userDefaultsKey = "MemeFavoriteSettings"

    static func load() -> MemeFavoriteSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let settings = try? JSONDecoder().decode(MemeFavoriteSettings.self, from: data)
        else {
            return MemeFavoriteSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: MemeFavoriteSettings.userDefaultsKey)
        }
    }
}
