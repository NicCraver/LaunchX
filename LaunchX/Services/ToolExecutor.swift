import AppKit
import Foundation

/// 工具执行服务
/// 负责执行不同类型的工具（打开应用、打开网页、执行命令等）
class ToolExecutor {
    static let shared = ToolExecutor()

    private init() {}

    // MARK: - 执行工具

    /// 执行工具
    /// - Parameters:
    ///   - tool: 要执行的工具
    ///   - isExtension: 是否为扩展模式（仅 IDE 应用有效）
    func execute(_ tool: ToolItem, isExtension: Bool = false) {
        guard tool.isEnabled else {
            print("[ToolExecutor] Tool '\(tool.name)' is disabled, skipping execution")
            return
        }

        switch tool.type {
        case .app:
            executeApp(tool, isExtension: isExtension)

        case .webLink:
            executeWebLink(tool)

        case .utility:
            executeUtility(tool)

        case .systemCommand:
            executeSystemCommand(tool)
        }
    }

    // MARK: - 应用执行

    private func executeApp(_ tool: ToolItem, isExtension: Bool) {
        guard let path = tool.path else {
            print("[ToolExecutor] App tool '\(tool.name)' has no path")
            return
        }

        if isExtension, let ideType = tool.ideType {
            // 进入 IDE 项目模式
            print("[ToolExecutor] Opening IDE mode for '\(tool.name)'")
            PanelManager.shared.showPanelInIDEMode(idePath: path, ideType: ideType)
        } else {
            // 直接打开应用或文件夹
            print("[ToolExecutor] Opening app/folder: \(path)")
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 网页直达执行

    private func executeWebLink(_ tool: ToolItem) {
        guard let urlString = tool.url else {
            print("[ToolExecutor] WebLink tool '\(tool.name)' has no URL")
            return
        }

        // 确保 URL 有协议前缀
        var normalizedURL = urlString
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }

        guard let url = URL(string: normalizedURL) else {
            print("[ToolExecutor] Invalid URL: \(normalizedURL)")
            return
        }

        print("[ToolExecutor] Opening URL: \(url)")
        NSWorkspace.shared.open(url)
    }

    // MARK: - 实用工具执行（预留）

    private func executeUtility(_ tool: ToolItem) {
        guard let identifier = tool.extensionIdentifier else {
            print("[ToolExecutor] Utility tool '\(tool.name)' has no extension identifier")
            return
        }

        print("[ToolExecutor] Executing utility: \(identifier)")
        // TODO: 实现实用工具执行逻辑
        // 可能需要根据 identifier 调用不同的扩展处理器
    }

    // MARK: - 系统命令执行（预留）

    private func executeSystemCommand(_ tool: ToolItem) {
        guard let command = tool.command else {
            print("[ToolExecutor] SystemCommand tool '\(tool.name)' has no command")
            return
        }

        print("[ToolExecutor] Executing system command: \(command)")
        // TODO: 实现系统命令执行逻辑
        // 需要考虑安全性，可能需要沙盒限制
    }

    // MARK: - 便捷方法

    /// 通过工具 ID 执行
    func execute(toolId: UUID, isExtension: Bool = false) {
        let config = ToolsConfig.load()
        guard let tool = config.tool(byId: toolId) else {
            print("[ToolExecutor] Tool not found: \(toolId)")
            return
        }
        execute(tool, isExtension: isExtension)
    }

    /// 通过别名执行
    func execute(alias: String) {
        let config = ToolsConfig.load()
        guard let tool = config.tool(byAlias: alias) else {
            print("[ToolExecutor] Tool not found for alias: \(alias)")
            return
        }
        execute(tool)
    }
}
