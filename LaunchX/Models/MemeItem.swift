import Foundation

/// 表情包搜索结果项
struct MemeItem: Identifiable, Equatable {
    let id: UUID
    let imageURL: String  // 图片 URL
    let description: String  // 描述文字
    let isGif: Bool  // 是否为 GIF

    init(imageURL: String, description: String, isGif: Bool) {
        self.id = UUID()
        self.imageURL = imageURL
        self.description = description
        self.isGif = isGif
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
