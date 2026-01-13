import Foundation

/// 应用配置备份模型，包含核心用户自定义设置和数据（排除设备相关的路径配置，如自定义项目和搜索范围）
struct BackupModel: Codable {
    /// 备份元数据
    struct Metadata: Codable {
        let version: String
        let exportDate: Date
        let appVersion: String?
        let deviceName: String?
    }

    let metadata: Metadata

    // 1. 基础设置 (UserDefaults)
    let generalSettings: GeneralSettings

    // 2. 高级扩展 - Snippets (SnippetSettings & [SnippetItem])
    let snippetSettings: SnippetSettings
    let snippets: [SnippetItem]

    // 3. 高级扩展 - AI 翻译 (AITranslateSettings)
    let aiTranslateSettings: AITranslateSettings

    struct GeneralSettings: Codable {
        let defaultWindowMode: String
        let hotKeyKeyCode: Int?
        let hotKeyModifiers: Int?
        let hotKeyUseDoubleTap: Bool
        let hotKeyDoubleTapModifier: String?
    }
}

extension BackupModel {
    /// 创建当前配置的备份
    static func createCurrent() -> BackupModel {
        let defaults = UserDefaults.standard

        let general = GeneralSettings(
            defaultWindowMode: defaults.string(forKey: "defaultWindowMode") ?? "full",
            hotKeyKeyCode: defaults.object(forKey: "hotKeyKeyCode") as? Int,
            hotKeyModifiers: defaults.object(forKey: "hotKeyModifiers") as? Int,
            hotKeyUseDoubleTap: defaults.bool(forKey: "hotKeyUseDoubleTap"),
            hotKeyDoubleTapModifier: defaults.string(forKey: "hotKeyDoubleTapModifier")
        )

        return BackupModel(
            metadata: Metadata(
                version: "1.1",
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                deviceName: Host.current().localizedName
            ),
            generalSettings: general,
            snippetSettings: SnippetSettings.load(),
            snippets: SnippetService.shared.snippets,
            aiTranslateSettings: AITranslateSettings.load()
        )
    }

    /// 将备份应用到当前系统
    func apply() throws {
        let defaults = UserDefaults.standard

        // 1. 还原基础设置
        defaults.set(generalSettings.defaultWindowMode, forKey: "defaultWindowMode")
        if let keyCode = generalSettings.hotKeyKeyCode {
            defaults.set(keyCode, forKey: "hotKeyKeyCode")
        }
        if let modifiers = generalSettings.hotKeyModifiers {
            defaults.set(modifiers, forKey: "hotKeyModifiers")
        }
        defaults.set(generalSettings.hotKeyUseDoubleTap, forKey: "hotKeyUseDoubleTap")
        if let doubleTapMod = generalSettings.hotKeyDoubleTapModifier {
            defaults.set(doubleTapMod, forKey: "hotKeyDoubleTapModifier")
        }

        // 2. 还原 Snippets
        snippetSettings.save()

        // 保存 snippets 数组到文件
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let snippetsDir = appSupport.appendingPathComponent("LaunchX/Snippets", isDirectory: true)
        try? FileManager.default.createDirectory(at: snippetsDir, withIntermediateDirectories: true)
        let snippetsURL = snippetsDir.appendingPathComponent("snippets.json")

        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: snippetsURL)
        }

        // 3. 还原 AI 翻译 (包含模型和别名设置)
        aiTranslateSettings.save()

        // 4. 触发全局刷新通知（如 HotKeyService 会重新加载快捷键）
        NotificationCenter.default.post(
            name: NSNotification.Name("AppConfigDidImport"), object: nil)
    }
}
