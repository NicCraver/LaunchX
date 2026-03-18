import Carbon
import Cocoa

// MARK: - 暂停/恢复、冲突检测方法

extension HotKeyService {
    // MARK: - 暂停/恢复快捷键（用于录制时）

    /// 暂停所有快捷键（录制时使用）
    func suspendAllHotKeys() {
        isSuspended = true

        // 暂停主快捷键
        if let ref = mainHotKeyRef {
            UnregisterEventHotKey(ref)
            mainHotKeyRef = nil
            print("HotKeyService: Suspended main hotkey")
        }

        // 暂停双击修饰键监听
        stopDoubleTapMonitoring()

        // 暂停所有自定义快捷键
        for (hotKeyId, ref) in customHotKeyRefs {
            UnregisterEventHotKey(ref)
            print("HotKeyService: Suspended custom hotkey (ID: \(hotKeyId))")
        }
        // 注意：不清除 customHotKeyActions 和 customHotKeyConfigs，以便恢复时使用
        customHotKeyRefs.removeAll()

        print("HotKeyService: All hotkeys suspended")
    }

    /// 恢复所有快捷键
    func resumeAllHotKeys() {
        isSuspended = false
        // 恢复主快捷键或双击修饰键
        if useDoubleTapModifier {
            startDoubleTapMonitoring()
            print("HotKeyService: Resumed double-tap modifier")
        } else if currentKeyCode != 0 && currentModifiers != 0 {
            // 使用 registerMainHotKey 方法来确保正确处理旧引用
            registerMainHotKey(keyCode: currentKeyCode, modifiers: currentModifiers)
            print("HotKeyService: Resumed main hotkey")
        }

        // 优先使用新的 ToolsConfig，如果没有数据则回退到 CustomItemsConfig
        let toolsConfig = ToolsConfig.load()
        if !toolsConfig.tools.isEmpty {
            reloadToolHotKeys(from: toolsConfig)
        } else {
            let config = CustomItemsConfig.load()
            reloadCustomHotKeys(from: config)
        }

        print("HotKeyService: All hotkeys resumed")
    }

    /// 从配置重新加载所有自定义快捷键（旧版本，兼容 CustomItemsConfig）
    func reloadCustomHotKeys(from config: CustomItemsConfig) {
        // 如果处于暂停状态（录制模式），不重新加载快捷键
        guard !isSuspended else {
            print("HotKeyService: Skipping reload - currently suspended")
            return
        }

        // 先注销所有现有的自定义快捷键
        unregisterAllCustomHotKeys()

        // 重新注册
        for item in config.customItems {
            if let openKey = item.openHotKey {
                registerCustomHotKey(
                    keyCode: openKey.keyCode,
                    modifiers: openKey.modifiers,
                    itemId: item.id,
                    isExtension: false
                )
            }
            if let extKey = item.extensionHotKey {
                registerCustomHotKey(
                    keyCode: extKey.keyCode,
                    modifiers: extKey.modifiers,
                    itemId: item.id,
                    isExtension: true
                )
            }
        }

        print(
            "HotKeyService: Reloaded \(customHotKeyRefs.count) custom hotkeys from CustomItemsConfig"
        )
    }

    /// 从 ToolsConfig 重新加载所有工具快捷键
    func reloadToolHotKeys(from config: ToolsConfig) {
        // 如果处于暂停状态（录制模式），不重新加载快捷键
        guard !isSuspended else {
            print("HotKeyService: Skipping reload - currently suspended")
            return
        }

        // 先注销所有现有的自定义快捷键
        unregisterAllCustomHotKeys()

        // 只为已启用的工具注册快捷键
        for tool in config.enabledTools {
            // 注册主快捷键
            if let hotKey = tool.hotKey {
                registerCustomHotKey(
                    keyCode: hotKey.keyCode,
                    modifiers: hotKey.modifiers,
                    itemId: tool.id,
                    isExtension: false
                )
            }

            // 注册扩展快捷键（IDE、网页直达 Query、实用工具）
            // ⚠️ 重要：修改快捷键相关功能时，必须确保所有支持扩展的工具类型都被注册！
            if tool.supportsExtension, let extKey = tool.extensionHotKey {
                registerCustomHotKey(
                    keyCode: extKey.keyCode,
                    modifiers: extKey.modifiers,
                    itemId: tool.id,
                    isExtension: true
                )
            }
        }

        print("HotKeyService: Reloaded \(customHotKeyRefs.count) tool hotkeys from ToolsConfig")
    }

}
