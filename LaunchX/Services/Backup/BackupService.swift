import AppKit
import Foundation
import UniformTypeIdentifiers

/// 备份服务 - 处理配置文件的导出和导入
final class BackupService {
    static let shared = BackupService()

    private init() {}

    /// 导出配置到文件
    func exportConfiguration() {
        let backup = BackupModel.createCurrent()

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "LaunchX_Backup_\(formatDate(Date())).json"
        savePanel.title = "导出配置备份"
        savePanel.message = "请选择备份文件的保存位置"

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(backup)
                    try data.write(to: url)

                    self.showAlert(title: "导出成功", message: "您的配置已成功备份至：\n\(url.lastPathComponent)")
                } catch {
                    self.showAlert(
                        title: "导出失败", message: "发生错误：\(error.localizedDescription)",
                        style: .critical)
                }
            }
        }
    }

    /// 从文件导入配置
    func importConfiguration() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "导入配置备份"
        openPanel.message = "请选择要导入的 LaunchX 备份文件 (.json)"

        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let backup = try decoder.decode(BackupModel.self, from: data)

                    // 确认弹窗
                    let alert = NSAlert()
                    alert.messageText = "确认导入配置？"
                    alert.informativeText = "导入备份将覆盖您当前的设置、自定义项目、Snippet 和 AI 模型配置。此操作不可撤销。"
                    alert.addButton(withTitle: "确认导入")
                    alert.addButton(withTitle: "取消")

                    if alert.runModal() == .alertFirstButtonReturn {
                        try backup.apply()

                        // 额外处理：让 SnippetService 重新加载内存数据
                        SnippetService.shared.reloadAfterImport()

                        // 提示用户可能需要重启应用以完全应用某些设置
                        self.showAlert(
                            title: "导入成功", message: "配置已恢复。建议重启 LaunchX 以确保所有快捷键和服务完全生效。")
                    }
                } catch {
                    self.showAlert(
                        title: "导入失败", message: "无效的备份文件或读取错误：\(error.localizedDescription)",
                        style: .critical)
                }
            }
        }
    }

    // MARK: - 私有辅助方法

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style = .informational) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }
}
