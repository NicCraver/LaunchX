import AppKit
import Foundation

/// AI 翻译面板管理器
class AITranslatePanelManager: NSObject, NSWindowDelegate {
    static let shared = AITranslatePanelManager()

    private var panel: AITranslatePanel?
    private var viewController: AITranslatePanelViewController?
    private(set) var isPanelVisible: Bool = false
    private var isPinned: Bool = false
    private var previousApp: NSRunningApplication?

    private override init() {
        super.init()
    }

    // MARK: - 面板控制

    /// 显示面板（输入翻译模式）
    func showPanel(withText text: String? = nil) {
        // 记录之前的应用
        if let frontApp = NSWorkspace.shared.frontmostApplication,
            frontApp.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            previousApp = frontApp
        }

        if panel == nil {
            setupPanel()
        }

        guard let panel = panel else { return }

        // 刷新设置
        viewController?.reloadSettings()

        // 重置面板状态（清空上次的输入和翻译结果），但只在没有初始文本时重置
        if text == nil || text?.isEmpty == true {
            viewController?.resetPanelState()
            // 重置历史导航索引
            AITranslateService.shared.resetHistoryNavigation()
        }

        // 获取鼠标所在的屏幕（全屏应用时更准确）
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen =
            NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        let screenFrame = currentScreen?.visibleFrame ?? .zero
        let panelSize = panel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY + 50  // 稍微偏上

        panel.setFrameOrigin(NSPoint(x: x, y: y))

        // 确保面板移动到当前空间（不能同时使用 canJoinAllSpaces 和 moveToActiveSpace）
        panel.collectionBehavior = [
            .moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle,
        ]

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isPanelVisible = true

        // 如果有初始文本，设置并翻译
        if let text = text, !text.isEmpty {
            viewController?.setInputText(text)
            viewController?.performTranslation()
        } else {
            viewController?.focusInput()
        }
    }

    /// 显示面板（选词翻译模式）
    func showPanelWithSelection() {
        // 使用异步版本获取选中文本，避免阻塞主线程
        AITranslateService.shared.getSelectedText { [weak self] selectedText in
            guard let self = self else { return }

            if let text = selectedText,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                self.showPanelNearCursor(withText: text)
            } else {
                // 没有选中文本，显示空面板
                self.showPanel()
            }
        }
    }

    /// 在光标附近显示面板
    func showPanelNearCursor(withText text: String) {
        // 记录之前的应用
        if let frontApp = NSWorkspace.shared.frontmostApplication,
            frontApp.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            previousApp = frontApp
        }

        if panel == nil {
            setupPanel()
        }

        guard let panel = panel else { return }

        // 刷新设置
        viewController?.reloadSettings()

        // 获取鼠标所在的屏幕（全屏应用时更准确）
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen =
            NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        let screenFrame = currentScreen?.visibleFrame ?? .zero
        let panelSize = panel.frame.size

        // 默认在光标下方
        var x = mouseLocation.x - panelSize.width / 2
        var y = mouseLocation.y - panelSize.height - 20

        // 确保不超出屏幕边界
        x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - panelSize.width - 10))

        // 如果下方空间不足，显示在上方
        if y < screenFrame.minY + 10 {
            y = mouseLocation.y + 20
        }
        y = max(screenFrame.minY + 10, min(y, screenFrame.maxY - panelSize.height - 10))

        panel.setFrameOrigin(NSPoint(x: x, y: y))

        // 确保面板移动到当前空间（不能同时使用 canJoinAllSpaces 和 moveToActiveSpace）
        panel.collectionBehavior = [
            .moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle,
        ]

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isPanelVisible = true

        // 设置文本并翻译
        viewController?.setInputText(text)
        viewController?.performTranslation()
    }

    /// 隐藏面板
    func hidePanel() {
        guard !isPinned else { return }
        forceHidePanel()
    }

    /// 强制隐藏面板（忽略固定状态）
    func forceHidePanel() {
        guard isPanelVisible else { return }
        isPanelVisible = false
        panel?.orderOut(nil)
    }

    /// 隐藏并激活之前的应用
    func hidePanelAndActivatePreviousApp() {
        forceHidePanel()
        if let app = previousApp {
            app.activate()
        }
    }

    /// 切换面板显示
    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    /// 切换固定状态
    func togglePinned() {
        isPinned.toggle()
        viewController?.updatePinnedState(isPinned)
    }

    var panelIsPinned: Bool {
        return isPinned
    }

    // MARK: - 面板设置

    private func setupPanel() {
        let settings = AITranslateSettings.load()

        // 初始使用紧凑高度（只显示输入框和语言栏）
        let compactHeight: CGFloat = 180
        let contentRect = NSRect(
            x: 0, y: 0,
            width: settings.panelWidth,
            height: compactHeight
        )

        panel = AITranslatePanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        guard let panel = panel else { return }

        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor(named: "PanelBackground") ?? NSColor.windowBackgroundColor

        // 设置最小和最大尺寸 - 只限制宽度，高度自适应
        panel.minSize = NSSize(width: 400, height: 180)
        panel.maxSize = NSSize(width: 900, height: 800)

        // 创建视图控制器
        viewController = AITranslatePanelViewController()
        viewController?.onContentHeightChanged = { [weak self] newHeight in
            self?.adjustPanelHeight(to: newHeight)
        }
        panel.contentViewController = viewController
    }

    /// 调整面板高度
    private func adjustPanelHeight(to contentHeight: CGFloat) {
        guard let panel = panel else { return }

        let minHeight: CGFloat = 180
        let maxHeight: CGFloat = 800
        let targetHeight = max(minHeight, min(contentHeight, maxHeight))

        var frame = panel.frame
        let heightDiff = targetHeight - frame.height
        frame.origin.y -= heightDiff  // 向下扩展
        frame.size.height = targetHeight

        panel.setFrame(frame, display: true, animate: true)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        if !isPinned {
            hidePanel()
        }
    }

    func windowWillClose(_ notification: Notification) {
        isPanelVisible = false
    }

    func windowDidResize(_ notification: Notification) {
        // 保存面板尺寸
        guard let panel = panel else { return }
        var settings = AITranslateSettings.load()
        settings.panelWidth = panel.frame.width
        settings.panelHeight = panel.frame.height
        settings.save()
    }
}
