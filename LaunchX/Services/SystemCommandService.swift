import AppKit
import Foundation

/// 系统命令服务
/// 负责执行各种系统命令（切换设置、系统操作等）
class SystemCommandService {
    static let shared = SystemCommandService()

    private init() {}

    // MARK: - 命令标识符

    enum Identifier: String, CaseIterable {
        case toggleDockAutohide = "toggle_dock_autohide"
        case toggleMenubarAutohide = "toggle_menubar_autohide"
        case toggleHiddenFiles = "toggle_hidden_files"
        case toggleDarkMode = "toggle_dark_mode"
        case toggleNightShift = "toggle_night_shift"
        case ejectAllDisks = "eject_all_disks"
        case emptyTrash = "empty_trash"
        case lockScreen = "lock_screen"
        case shutdown = "shutdown"
        case restart = "restart"

        /// 基础名称（静态）
        var baseName: String {
            switch self {
            case .toggleDockAutohide: return "自动隐藏程序坞"
            case .toggleMenubarAutohide: return "自动隐藏菜单栏"
            case .toggleHiddenFiles: return "切换隐藏文件显示"
            case .toggleDarkMode: return "切换深色模式"
            case .toggleNightShift: return "切换夜览"
            case .ejectAllDisks: return "推出所有磁盘"
            case .emptyTrash: return "清空废纸篓"
            case .lockScreen: return "锁屏"
            case .shutdown: return "关机"
            case .restart: return "重启电脑"
            }
        }

        /// 命令描述（用于确认弹窗）
        var description: String {
            switch self {
            case .toggleDockAutohide: return "切换程序坞的自动隐藏设置"
            case .toggleMenubarAutohide: return "切换菜单栏的自动隐藏设置"
            case .toggleHiddenFiles: return "切换 Finder 中隐藏文件的显示状态"
            case .toggleDarkMode: return "切换系统深色/浅色外观"
            case .toggleNightShift: return "切换夜览（护眼模式）"
            case .ejectAllDisks: return "安全推出所有外部磁盘"
            case .emptyTrash: return "永久删除废纸篓中的所有文件"
            case .lockScreen: return "锁定屏幕"
            case .shutdown: return "关闭电脑"
            case .restart: return "重新启动电脑"
            }
        }

        /// 是否需要二次确认
        var requiresDoubleConfirmation: Bool {
            switch self {
            case .ejectAllDisks, .emptyTrash, .shutdown, .restart:
                return true
            default:
                return false
            }
        }

        /// SF Symbol 图标名称
        var iconName: String {
            switch self {
            case .toggleDockAutohide: return "dock.rectangle"
            case .toggleMenubarAutohide: return "menubar.rectangle"
            case .toggleHiddenFiles: return "eye.slash"
            case .toggleDarkMode: return "moon.fill"
            case .toggleNightShift: return "sun.max.fill"
            case .ejectAllDisks: return "eject.fill"
            case .emptyTrash: return "trash.fill"
            case .lockScreen: return "lock.fill"
            case .shutdown: return "power"
            case .restart: return "arrow.clockwise"
            }
        }
    }

    // MARK: - 动态名称

    /// 获取命令的动态显示名称
    func getDynamicName(for identifier: String) -> String {
        guard let id = Identifier(rawValue: identifier) else {
            return identifier
        }
        return id.baseName
    }

    // MARK: - 状态查询

    /// 检查 Dock 自动隐藏是否启用
    func isDockAutoHideEnabled() -> Bool {
        return readDefaultsBool(domain: "com.apple.dock", key: "autohide")
    }

    /// 检查菜单栏自动隐藏是否启用
    func isMenuBarAutoHideEnabled() -> Bool {
        // 优先检查新版 macOS 的设置键
        let newKey = readDefaultsString(
            domain: "com.apple.dock", key: "autohide-menubar-in-fullscreen")
        if newKey != nil {
            return readDefaultsBool(domain: "com.apple.dock", key: "autohide-menubar-in-fullscreen")
        }
        // 回退到旧版设置键
        return readDefaultsBool(domain: "NSGlobalDomain", key: "_HIHideMenuBar")
    }

    /// 检查隐藏文件是否显示
    func isHiddenFilesVisible() -> Bool {
        return readDefaultsBool(domain: "com.apple.finder", key: "AppleShowAllFiles")
    }

    /// 检查深色模式是否启用
    func isDarkModeEnabled() -> Bool {
        let result = readDefaultsString(domain: "-g", key: "AppleInterfaceStyle")
        return result?.lowercased() == "dark"
    }

    // MARK: - 命令执行

    /// 执行系统命令
    /// - Parameters:
    ///   - identifier: 命令标识符
    ///   - completion: 完成回调，参数为是否执行成功
    func execute(identifier: String, completion: @escaping (Bool) -> Void) {
        guard let id = Identifier(rawValue: identifier) else {
            print("[SystemCommandService] Unknown identifier: \(identifier)")
            completion(false)
            return
        }

        // 检查是否需要二次确认
        if id.requiresDoubleConfirmation {
            showDoubleConfirmation(for: id) { confirmed in
                if confirmed {
                    self.performCommand(id, completion: completion)
                } else {
                    completion(false)
                }
            }
        } else {
            performCommand(id, completion: completion)
        }
    }

    /// 执行具体命令
    private func performCommand(_ id: Identifier, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success: Bool

            switch id {
            case .toggleDockAutohide:
                success = self.toggleDockAutohide()
            case .toggleMenubarAutohide:
                success = self.toggleMenuBarAutohide()
            case .toggleHiddenFiles:
                success = self.toggleHiddenFiles()
            case .toggleDarkMode:
                success = self.toggleDarkMode()
            case .toggleNightShift:
                success = self.toggleNightShift()
            case .ejectAllDisks:
                success = self.ejectAllDisks()
            case .emptyTrash:
                success = self.emptyTrash()
            case .lockScreen:
                success = self.lockScreen()
            case .shutdown:
                success = self.shutdown()
            case .restart:
                success = self.restart()
            }

            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: - 具体命令实现

    /// 切换 Dock 自动隐藏
    private func toggleDockAutohide() -> Bool {
        // 使用 AppleScript 切换 Dock 自动隐藏，避免 killall Dock 导致的屏幕闪烁
        let script = """
            tell application "System Events"
                tell dock preferences
                    set autohide to not autohide
                end tell
            end tell
            """
        return runAppleScript(script)
    }

    /// 切换菜单栏自动隐藏
    private func toggleMenuBarAutohide() -> Bool {
        // 使用 AppleScript 通过 System Events 切换菜单栏自动隐藏
        let script = """
            tell application "System Events"
                tell dock preferences
                    set autohide menu bar to not autohide menu bar
                end tell
            end tell
            """
        return runAppleScript(script)
    }

    /// 切换隐藏文件显示
    private func toggleHiddenFiles() -> Bool {
        let currentValue = isHiddenFilesVisible()
        let newValue = !currentValue

        let success = writeDefaultsBool(
            domain: "com.apple.finder", key: "AppleShowAllFiles", value: newValue)
        if success {
            // 重启 Finder 使设置生效
            runShellCommand("/usr/bin/killall", arguments: ["Finder"])
        }
        return success
    }

    /// 切换深色模式
    private func toggleDarkMode() -> Bool {
        let script =
            "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        return runAppleScript(script)
    }

    /// 切换夜览
    private func toggleNightShift() -> Bool {
        // 使用 AppleScript 调用 CoreBrightness 私有框架切换夜览
        let script = """
            use framework "CoreBrightness"

            set client to current application's CBBlueLightClient's alloc()'s init()
            set {theResult, theProps} to client's getBlueLightStatus:(reference)

            set isEnabled to item 2 of theProps

            if isEnabled then
                client's setEnabled:false
            else
                client's setEnabled:true
            end if
            """
        return runAppleScript(script)
    }

    /// 推出所有磁盘
    private func ejectAllDisks() -> Bool {
        let script = """
            tell application "Finder"
                eject (every disk whose ejectable is true)
            end tell
            """
        return runAppleScript(script)
    }

    /// 清空废纸篓
    private func emptyTrash() -> Bool {
        let script = """
            tell application "Finder"
                empty the trash
            end tell
            """
        return runAppleScript(script)
    }

    /// 锁屏
    private func lockScreen() -> Bool {
        // 使用 pmset 命令锁屏（更可靠的方式）
        let script = """
            tell application "System Events" to keystroke "q" using {control down, command down}
            """
        return runAppleScript(script)
    }

    /// 关机
    private func shutdown() -> Bool {
        let script = """
            tell application "System Events"
                shut down
            end tell
            """
        return runAppleScript(script)
    }

    /// 重启
    private func restart() -> Bool {
        let script = """
            tell application "System Events"
                restart
            end tell
            """
        return runAppleScript(script)
    }

    // MARK: - 确认弹窗

    /// 显示二次确认弹窗
    private func showDoubleConfirmation(for id: Identifier, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // 第一次确认
            let alert1 = NSAlert()
            alert1.messageText = "确认\(id.baseName)？"
            alert1.informativeText = id.description
            alert1.alertStyle = .warning

            // 设置图标
            if let icon = NSImage(systemSymbolName: id.iconName, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .medium)
                alert1.icon = icon.withSymbolConfiguration(config)
            }

            alert1.addButton(withTitle: "继续")
            alert1.addButton(withTitle: "取消")

            let response1 = alert1.runModal()
            guard response1 == .alertFirstButtonReturn else {
                completion(false)
                return
            }

            // 短暂延迟，让用户有时间思考
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 第二次确认 - 更严重的警告
                let alert2 = NSAlert()
                alert2.messageText = "再次确认"
                alert2.informativeText = "您确定要\(id.baseName)吗？此操作无法撤销。"
                alert2.alertStyle = .critical

                // 设置图标
                if let icon = NSImage(
                    systemSymbolName: "exclamationmark.triangle.fill",
                    accessibilityDescription: nil)
                {
                    let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .medium)
                    alert2.icon = icon.withSymbolConfiguration(config)
                }

                // 添加按钮 - 确认按钮在前
                let confirmButton = alert2.addButton(withTitle: "确认\(id.baseName)")
                confirmButton.hasDestructiveAction = true  // 标记为危险操作（macOS 11+）
                alert2.addButton(withTitle: "取消")

                let response2 = alert2.runModal()
                completion(response2 == .alertFirstButtonReturn)
            }
        }
    }

    // MARK: - 辅助方法

    /// 读取 defaults 布尔值
    private func readDefaultsBool(domain: String, key: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", domain, key]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output =
                String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines) ?? ""

            // defaults 返回 "1" 或 "true" 表示 true
            return output == "1" || output.lowercased() == "true"
        } catch {
            print("[SystemCommandService] Failed to read defaults: \(error)")
            return false
        }
    }

    /// 读取 defaults 字符串值
    private func readDefaultsString(domain: String, key: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", domain, key]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)
        } catch {
            print("[SystemCommandService] Failed to read defaults: \(error)")
            return nil
        }
    }

    /// 写入 defaults 布尔值
    private func writeDefaultsBool(domain: String, key: String, value: Bool) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", domain, key, "-bool", value ? "true" : "false"]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("[SystemCommandService] Failed to write defaults: \(error)")
            return false
        }
    }

    /// 运行 Shell 命令
    @discardableResult
    private func runShellCommand(_ path: String, arguments: [String] = []) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("[SystemCommandService] Failed to run shell command: \(error)")
            return false
        }
    }

    /// 运行 AppleScript
    private func runAppleScript(_ script: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("[SystemCommandService] Failed to run AppleScript: \(error)")
            return false
        }
    }
}
