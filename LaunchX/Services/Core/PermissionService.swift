import Cocoa
import Combine
import SwiftUI

class PermissionService: ObservableObject {
    static let shared = PermissionService()

    @Published var isAccessibilityGranted: Bool = false
    @Published var isFullDiskAccessGranted: Bool = false

    private var refreshTimer: Timer?
    private var isChecking = false

    private init() {
        checkAllPermissions()
        startPeriodicCheck()
    }

    func startPeriodicCheck() {
        guard refreshTimer == nil else { return }
        // 每 5 秒检查一次权限状态（权限变化不频繁，无需高频轮询）
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAllPermissions()
        }
    }

    func stopPeriodicCheck() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func checkAllPermissions() {
        // 防止重复检查
        guard !isChecking else { return }
        isChecking = true

        // 在后台线程统一检查所有权限，然后一次性更新 UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let accessibility = AXIsProcessTrusted()
            let fullDiskAccess = self.checkFullDiskAccessSync()

            DispatchQueue.main.async {
                // 一次性更新所有状态，避免竞争
                if self.isAccessibilityGranted != accessibility {
                    self.isAccessibilityGranted = accessibility
                }
                if self.isFullDiskAccessGranted != fullDiskAccess {
                    self.isFullDiskAccessGranted = fullDiskAccess
                }
                self.isChecking = false

                // 所有权限都已授予后，停止轮询以节省 CPU
                if self.allPermissionsGranted {
                    self.stopPeriodicCheck()
                    print("[PermissionService] All permissions granted, stopped periodic check")
                }
            }
        }
    }

    /// 同步检查辅助功能权限（用于启动时快速检查）
    func checkAccessibilitySync() -> Bool {
        return AXIsProcessTrusted()
    }

    // MARK: - Accessibility

    func requestAccessibility() {
        // 先调用系统 API 将应用添加到辅助功能列表（prompt: false 不显示弹窗）
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ]
        AXIsProcessTrustedWithOptions(options)

        // 然后直接打开系统设置
        openAccessibilitySettings()

        // 延迟检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAllPermissions()
        }
    }

    func openAccessibilitySettings() {
        openSystemSettings(pane: "Privacy_Accessibility")
    }

    // MARK: - Full Disk Access

    private func checkFullDiskAccessSync() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        // Check user's TCC database
        let userTCCPath = homeDir.appendingPathComponent(
            "Library/Application Support/com.apple.TCC/TCC.db")
        if (try? Data(contentsOf: userTCCPath, options: .mappedIfSafe)) != nil {
            return true
        }

        // Try system TCC
        if (try? Data(
            contentsOf: URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"),
            options: .mappedIfSafe)) != nil
        {
            return true
        }

        return false
    }

    func requestFullDiskAccess() {
        // Full Disk Access 没有系统弹窗，直接打开设置
        openSystemSettings(pane: "Privacy_AllFiles")
    }

    // MARK: - Helper

    var allPermissionsGranted: Bool {
        return isAccessibilityGranted && isFullDiskAccessGranted
    }

    /// 检查是否有基本功能所需的权限（辅助功能）
    var hasRequiredPermissions: Bool {
        return isAccessibilityGranted
    }

    // MARK: - Helper

    private func openSystemSettings(pane: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
