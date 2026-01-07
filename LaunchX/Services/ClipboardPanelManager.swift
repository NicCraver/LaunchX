import Cocoa

/// 剪贴板面板管理器
class ClipboardPanelManager: NSObject, NSWindowDelegate {
    static let shared = ClipboardPanelManager()

    private var panel: ClipboardPanel?
    private var viewController: ClipboardPanelViewController?
    private(set) var isPinned: Bool = false
    private(set) var isPanelVisible: Bool = false

    /// 记住打开面板前的前台应用，用于粘贴后恢复焦点
    private var previousApp: NSRunningApplication?

    private override init() {
        super.init()
    }

    // MARK: - 面板控制

    /// 显示面板（在光标附近）
    func showPanel() {
        // 记住当前前台应用（在激活 LaunchX 之前）
        // 注意：如果当前前台应用是 LaunchX 自己，我们仍然要记录它
        // 因为用户可能想要粘贴到 LaunchX 的设置窗口中
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            // 即使是 LaunchX 自己，也记录下来，这样粘贴时可以正确返回到设置窗口
            previousApp = frontApp
        }

        if panel == nil {
            setupPanel()
        }

        guard let panel = panel else { return }

        // 计算位置（光标附近，确保不超出屏幕）
        let mouseLocation = NSEvent.mouseLocation
        let settings = ClipboardSettings.load()
        let panelSize = NSSize(width: settings.panelWidth, height: settings.panelHeight)

        // 获取鼠标所在的屏幕（全屏应用时更准确）
        let currentScreen =
            NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        let screenFrame = currentScreen?.visibleFrame ?? .zero

        var origin = NSPoint(
            x: mouseLocation.x - panelSize.width / 2,
            y: mouseLocation.y - panelSize.height - 20  // 在光标下方
        )

        // 确保不超出屏幕边界
        // 左边界
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX + 10
        }
        // 右边界
        if origin.x + panelSize.width > screenFrame.maxX {
            origin.x = screenFrame.maxX - panelSize.width - 10
        }
        // 下边界（如果下方空间不足，显示在光标上方）
        if origin.y < screenFrame.minY {
            origin.y = mouseLocation.y + 20
        }
        // 上边界
        if origin.y + panelSize.height > screenFrame.maxY {
            origin.y = screenFrame.maxY - panelSize.height - 10
        }

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)

        // 确保面板移动到当前空间（不能同时使用 canJoinAllSpaces 和 moveToActiveSpace）
        panel.collectionBehavior = [
            .moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle,
        ]

        panel.makeKeyAndOrderFront(nil)

        isPanelVisible = true
        viewController?.focus()
        viewController?.reloadData()
    }

    /// 隐藏面板
    func hidePanel() {
        guard !isPinned else { return }  // 固定时不隐藏
        panel?.orderOut(nil)
        isPanelVisible = false
    }

    /// 强制隐藏面板（忽略固定状态）
    func forceHidePanel() {
        panel?.orderOut(nil)
        isPanelVisible = false
    }

    /// 隐藏面板并激活之前的应用（用于粘贴）
    func hidePanelAndActivatePreviousApp() {
        panel?.orderOut(nil)
        isPanelVisible = false
    }

    /// 切换面板显示
    func togglePanel() {
        if panel?.isVisible == true && isPanelVisible && panel?.isKeyWindow == true {
            if isPinned {
                forceHidePanel()
            } else {
                hidePanel()
            }
        } else {
            showPanel()
        }
    }

    /// 切换固定状态
    func togglePinned() {
        isPinned.toggle()
        viewController?.updatePinnedState(isPinned)
    }

    /// 设置固定状态
    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        viewController?.updatePinnedState(isPinned)
    }

    // MARK: - 设置

    private func setupPanel() {
        let settings = ClipboardSettings.load()
        let rect = NSRect(x: 0, y: 0, width: settings.panelWidth, height: settings.panelHeight)

        panel = ClipboardPanel(contentRect: rect)
        panel?.delegate = self

        viewController = ClipboardPanelViewController()
        panel?.contentView = viewController?.view
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        if !isPinned {
            hidePanel()
        }
    }

    // MARK: - 外部访问

    /// 获取当前选中的项目
    func getSelectedItems() -> [ClipboardItem] {
        return viewController?.getSelectedItems() ?? []
    }

    /// 粘贴当前选中项为纯文本
    func pasteSelectedAsPlainText() {
        guard let items = viewController?.getSelectedItems(), let first = items.first else {
            return
        }
        ClipboardService.shared.pasteAsPlainText(first)
        if !isPinned {
            hidePanel()
        }
    }
}
