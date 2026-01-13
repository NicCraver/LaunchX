import Foundation

/// 应用配置备份模型，包含所有用户自定义设置和数据
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

    // 2. 搜索配置 (SearchConfig)
    let searchConfig: SearchConfig

    // 3. 自定义项目和工具 (CustomItemsConfig & ToolsConfig)
    let customItemsConfig: CustomItemsConfig
    let toolsConfig: ToolsConfig

    // 4. 高级扩展 - Snippets (SnippetSettings & [SnippetItem])
    let snippetSettings: SnippetSettings
    let snippets: [SnippetItem]

    // 5. 高级扩展 - AI 翻译 (AITranslateSettings)
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
                version: "1.0",
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                deviceName: Host.current().localizedName
            ),
            generalSettings: general,
            searchConfig: SearchConfig.load(),
            customItemsConfig: CustomItemsConfig.load(),
            toolsConfig: ToolsConfig.load(),
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

        // 2. 还原搜索配置
        searchConfig.save()

        // 3. 还原项目和工具
        customItemsConfig.save()
        toolsConfig.save()

        // 4. 还原 Snippets
        snippetSettings.save()
        // 这里需要通过 Service 来批量添加/替换，确保触发通知和文件保存
        // 我们假设 SnippetService 有能力直接保存这一组 snippets
        // 实际上 SnippetService.shared 目前没有批量设置的方法，我们需要稍后在 Service 中添加
        // 先手动保存到文件以保持一致性
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let snippetsURL = appSupport.appendingPathComponent("LaunchX/Snippets/snippets.json")
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: snippetsURL)
        }

        // 5. 还原 AI 翻译
        aiTranslateSettings.save()

        // 6. 触发全局刷新通知
        NotificationCenter.default.post(
            name: NSNotification.Name("AppConfigDidImport"), object: nil)
    }
}
