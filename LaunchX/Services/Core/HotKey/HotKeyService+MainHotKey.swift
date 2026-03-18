import Carbon
import Cocoa
import Combine

// MARK: - 主快捷键和双击修饰键方法

extension HotKeyService {
    // MARK: - 主快捷键方法

    func setupGlobalHotKey() {
        // Install event handler only once
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            print("HotKeyService: Failed to install event handler. Status: \(status)")
            return
        }

        // Load saved configuration
        loadHotKeySettings()
    }

    /// 加载保存的快捷键设置
    func loadHotKeySettings() {
        // 检查是否使用双击修饰键模式
        let savedUseDoubleTap = UserDefaults.standard.bool(forKey: "hotKeyUseDoubleTap")

        if savedUseDoubleTap {
            // 加载双击修饰键设置
            if let savedModifier = UserDefaults.standard.string(forKey: "hotKeyDoubleTapModifier"),
                let modifier = DoubleTapModifier(rawValue: savedModifier)
            {
                enableDoubleTapModifier(modifier)
            } else {
                enableDoubleTapModifier(.command)
            }
        } else {
            // 加载传统快捷键设置
            let savedKeyCode = UserDefaults.standard.object(forKey: "hotKeyKeyCode") as? Int
            let savedModifiers = UserDefaults.standard.object(forKey: "hotKeyModifiers") as? Int

            if let key = savedKeyCode, let mods = savedModifiers {
                registerMainHotKey(keyCode: UInt32(key), modifiers: UInt32(mods))
            } else {
                registerMainHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
            }
        }
    }

    /// 注册主快捷键（打开搜索面板）
    func registerMainHotKey(keyCode: UInt32, modifiers: UInt32) {
        // 先禁用双击修饰键模式
        disableDoubleTapModifier()

        // Unregister existing if any
        if let ref = mainHotKeyRef {
            UnregisterEventHotKey(ref)
            mainHotKeyRef = nil
        }

        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
        self.useDoubleTapModifier = false

        // Save persistence
        UserDefaults.standard.set(Int(keyCode), forKey: "hotKeyKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "hotKeyModifiers")
        UserDefaults.standard.set(false, forKey: "hotKeyUseDoubleTap")

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: mainHotKeyId)

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &mainHotKeyRef
        )

        if registerStatus != noErr {
            print("HotKeyService: Failed to register main hotkey. Status: \(registerStatus)")
        } else {
            print("HotKeyService: Registered Main HotKey (Code: \(keyCode), Mods: \(modifiers))")
        }
    }

    /// 兼容旧的方法名
    func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        registerMainHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    /// 清除主快捷键
    func clearHotKey() {
        // 清除传统快捷键
        if let ref = mainHotKeyRef {
            UnregisterEventHotKey(ref)
            mainHotKeyRef = nil
        }

        // 清除双击修饰键监听
        disableDoubleTapModifier()

        currentKeyCode = 0
        currentModifiers = 0
        useDoubleTapModifier = false

        UserDefaults.standard.removeObject(forKey: "hotKeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "hotKeyModifiers")
        UserDefaults.standard.removeObject(forKey: "hotKeyUseDoubleTap")
        UserDefaults.standard.removeObject(forKey: "hotKeyDoubleTapModifier")
        print("HotKeyService: Cleared Main HotKey")
    }

}
