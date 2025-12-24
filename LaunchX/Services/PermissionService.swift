import Cocoa
import Combine
import SwiftUI

class PermissionService: ObservableObject {
    static let shared = PermissionService()

    @Published var isAccessibilityGranted: Bool = false
    @Published var isScreenRecordingGranted: Bool = false
    @Published var isFullDiskAccessGranted: Bool = false

    private var refreshTimer: Timer?

    private init() {
        checkAllPermissions()
        startPeriodicCheck()
    }

    private func startPeriodicCheck() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAllPermissions()
        }
    }

    func checkAllPermissions() {
        // 在后台线程统一检查所有权限，然后一次性更新 UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let accessibility = AXIsProcessTrusted()
            let screenRecording = self.checkScreenRecordingSync()
            let fullDiskAccess = self.checkFullDiskAccessSync()

            DispatchQueue.main.async {
                // 一次性更新所有状态，避免竞争
                if self.isAccessibilityGranted != accessibility {
                    self.isAccessibilityGranted = accessibility
                }
                if self.isScreenRecordingGranted != screenRecording {
                    self.isScreenRecordingGranted = screenRecording
                }
                if self.isFullDiskAccessGranted != fullDiskAccess {
                    self.isFullDiskAccessGranted = fullDiskAccess
                }
            }
        }
    }

    // MARK: - Screen Recording

    private func checkScreenRecordingSync() -> Bool {
        // CGPreflightScreenCaptureAccess 不可靠，改用实际测试
        // 尝试获取其他应用窗口的名称，这需要屏幕录制权限
        guard
            let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                ownerPID != currentPID
            else {
                continue
            }

            // 如果能获取到其他应用窗口的名称，说明有屏幕录制权限
            if let windowName = window[kCGWindowName as String] as? String,
                !windowName.isEmpty
            {
                return true
            }
        }

        // 没有找到带名称的窗口，再用 CGPreflightScreenCaptureAccess 作为后备
        return CGPreflightScreenCaptureAccess()
    }

    // MARK: - Accessibility

    func requestAccessibility() {
        // 只调用系统API显示权限弹窗，不自动打开设置
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        openSystemSettings(pane: "Privacy_Accessibility")
    }

    // MARK: - Screen Recording

    func requestScreenRecording() {
        // 只调用系统API显示权限弹窗，不自动打开设置
        CGRequestScreenCaptureAccess()
    }

    func openScreenRecordingSettings() {
        openSystemSettings(pane: "Privacy_ScreenCapture")
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
        return isAccessibilityGranted && isScreenRecordingGranted && isFullDiskAccessGranted
    }

    // MARK: - Helper

    private func openSystemSettings(pane: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
