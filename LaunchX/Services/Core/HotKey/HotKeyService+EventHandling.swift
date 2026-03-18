import Carbon
import Cocoa

// MARK: - 事件处理方法

extension HotKeyService {
    // MARK: - 冲突检测

    /// 检查快捷键是否冲突
    /// - Parameters:
    ///   - keyCode: 按键代码
    ///   - modifiers: 修饰键
    ///   - excludingItemId: 排除的项目 ID（用于编辑时排除自身）
    ///   - excludingIsExtension: 排除的快捷键类型
    ///   - excludingMainHotKey: 是否排除主快捷键检测
    /// - Returns: 冲突的描述，nil 表示无冲突
    func checkConflict(
        keyCode: UInt32, modifiers: UInt32, excludingItemId: UUID? = nil,
        excludingIsExtension: Bool? = nil, excludingMainHotKey: Bool = false
    ) -> String? {
        // 检查与主快捷键的冲突（除非排除）
        if !excludingMainHotKey && keyCode == currentKeyCode && modifiers == currentModifiers
            && !useDoubleTapModifier
        {
            return "启动快捷键"
        }

        // 直接从 ToolsConfig 读取所有已配置的快捷键进行冲突检测
        let toolsConfig = ToolsConfig.load()
        for tool in toolsConfig.tools {
            // 检查主快捷键
            if let hotKey = tool.hotKey,
                hotKey.keyCode == keyCode && hotKey.modifiers == modifiers
            {
                // 如果是同一个项目的同类型快捷键，跳过
                if let excludeId = excludingItemId,
                    let excludeIsExt = excludingIsExtension,
                    tool.id == excludeId && !excludeIsExt
                {
                    continue
                }
                return tool.name + " (打开)"
            }

            // 检查扩展快捷键（IDE、网页直达 Query、实用工具）
            // ⚠️ 重要：修改快捷键相关功能时，必须确保所有支持扩展的工具类型都被检测！
            if tool.supportsExtension, let extKey = tool.extensionHotKey,
                extKey.keyCode == keyCode && extKey.modifiers == modifiers
            {
                // 如果是同一个项目的同类型快捷键，跳过
                if let excludeId = excludingItemId,
                    let excludeIsExt = excludingIsExtension,
                    tool.id == excludeId && excludeIsExt
                {
                    continue
                }
                return tool.name + " (进入扩展)"
            }
        }

        // 回退检查 CustomItemsConfig（兼容旧数据）
        let itemsConfig = CustomItemsConfig.load()
        for item in itemsConfig.customItems {
            // 检查打开快捷键
            if let openKey = item.openHotKey,
                openKey.keyCode == keyCode && openKey.modifiers == modifiers
            {
                if let excludeId = excludingItemId,
                    let excludeIsExt = excludingIsExtension,
                    item.id == excludeId && !excludeIsExt
                {
                    continue
                }
                return item.name + " (打开)"
            }

            // 检查扩展快捷键
            if let extKey = item.extensionHotKey,
                extKey.keyCode == keyCode && extKey.modifiers == modifiers
            {
                if let excludeId = excludingItemId,
                    let excludeIsExt = excludingIsExtension,
                    item.id == excludeId && excludeIsExt
                {
                    continue
                }
                return item.name + " (进入扩展)"
            }
        }

        return nil
    }

    /// 检查快捷键冲突（用于高级扩展设置）
    /// - Parameters:
    ///   - keyCode: 按键码
    ///   - modifiers: 修饰键
    ///   - excludeType: 排除的类型（"bookmark" 或 "2fa"）
    /// - Returns: 冲突的描述，nil 表示无冲突
    func checkHotKeyConflict(keyCode: UInt32, modifiers: UInt32, excludeType: String?) -> String? {
        // 检查与主快捷键的冲突
        if keyCode == currentKeyCode && modifiers == currentModifiers && !useDoubleTapModifier {
            return "启动快捷键"
        }

        // 检查与书签快捷键的冲突
        if excludeType != "bookmark" {
            let bookmarkSettings = BookmarkSettings.load()
            if bookmarkSettings.hotKeyCode == keyCode
                && bookmarkSettings.hotKeyModifiers == modifiers
            {
                return "搜索书签"
            }
        }

        // 检查与 2FA 快捷键的冲突
        if excludeType != "2fa" {
            let twoFASettings = TwoFactorAuthSettings.load()
            if twoFASettings.hotKeyCode == keyCode && twoFASettings.hotKeyModifiers == modifiers {
                return "2FA 短信"
            }
        }

        // 检查与剪贴板快捷键的冲突
        if excludeType != "clipboard" {
            let clipboardSettings = ClipboardSettings.load()
            if clipboardSettings.hotKeyCode == keyCode
                && clipboardSettings.hotKeyModifiers == modifiers
            {
                return "剪贴板"
            }
        }

        // 检查与纯文本粘贴快捷键的冲突
        if excludeType != "plainTextPaste" {
            let clipboardSettings = ClipboardSettings.load()
            if clipboardSettings.plainTextHotKeyCode == keyCode
                && clipboardSettings.plainTextHotKeyModifiers == modifiers
            {
                return "纯文本粘贴"
            }
        }

        // 检查与选词翻译快捷键的冲突
        if excludeType != "translateSelection" {
            let translateSettings = AITranslateSettings.load()
            if translateSettings.selectionHotKeyCode == keyCode
                && translateSettings.selectionHotKeyModifiers == modifiers
            {
                return "选词翻译"
            }
        }

        // 检查与输入翻译快捷键的冲突
        if excludeType != "translateInput" {
            let translateSettings = AITranslateSettings.load()
            if translateSettings.inputHotKeyCode == keyCode
                && translateSettings.inputHotKeyModifiers == modifiers
            {
                return "输入翻译"
            }
        }

        // 检查与工具快捷键的冲突
        let toolsConfig = ToolsConfig.load()
        for tool in toolsConfig.tools {
            if let hotKey = tool.hotKey,
                hotKey.keyCode == keyCode && hotKey.modifiers == modifiers
            {
                return tool.name
            }
            if tool.supportsExtension, let extKey = tool.extensionHotKey,
                extKey.keyCode == keyCode && extKey.modifiers == modifiers
            {
                return tool.name + " (进入扩展)"
            }
        }

        return nil
    }

}
