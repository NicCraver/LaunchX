import Combine
import SwiftUI

// 用于触发打开设置的辅助视图
struct SettingsOpenerView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsNotification)) { _ in
                openSettings()
            }
    }
}

// 自定义通知
extension Notification.Name {
    static let openSettingsNotification = Notification.Name("openSettingsNotification")
}

@main
struct LaunchXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用 Settings scene 作为设置窗口
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var onboardingWindow: NSWindow?
    var settingsOpenerWindow: NSWindow?
    var isQuitting = false
    private var permissionObserver: AnyCancellable?
    private var hotKeyObservers: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupSettingsOpenerWindow()
        observeHotKeyChanges()

        // 先不设置 activation policy，等权限检查后决定
        // 如果需要显示引导页，保持 regular 模式
        // 如果权限已全部授予，再切换到 accessory 模式

        // Disable automatic window tabbing (Sierra+)
        NSWindow.allowsAutomaticWindowTabbing = false

        // 1. Initialize the Search Panel (pure AppKit, no SwiftUI)
        PanelManager.shared.setup()

        // 2. Check permissions first before setting up hotkey
        checkPermissionsAndSetup()
    }

    /// 创建隐藏窗口来承载 SettingsOpenerView
    private func setupSettingsOpenerWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: SettingsOpenerView())
        window.isReleasedWhenClosed = false
        window.orderOut(nil)  // 确保窗口不显示
        settingsOpenerWindow = window
    }

    /// 监听快捷键变化，更新菜单显示
    private func observeHotKeyChanges() {
        let hotKeyService = HotKeyService.shared

        // 监听 keyCode 变化
        hotKeyService.$currentKeyCode
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateStatusItemMenu()
            }
            .store(in: &hotKeyObservers)

        // 监听 modifiers 变化
        hotKeyService.$currentModifiers
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateStatusItemMenu()
            }
            .store(in: &hotKeyObservers)

        // 监听双击模式变化
        hotKeyService.$useDoubleTapModifier
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateStatusItemMenu()
            }
            .store(in: &hotKeyObservers)
    }

    /// 更新状态栏菜单的快捷键显示
    private func updateStatusItemMenu() {
        guard let menu = statusItem.menu,
            let openItem = menu.items.first(where: { $0.action == #selector(togglePanel) })
        else {
            return
        }

        let hotKeyService = HotKeyService.shared
        let keyCode = hotKeyService.currentKeyCode
        let modifiers = hotKeyService.currentModifiers
        let useDoubleTap = hotKeyService.useDoubleTapModifier

        if !useDoubleTap {
            let keyChar = DoubleTapModifier.keyCharacter(for: keyCode)
            openItem.keyEquivalent = keyChar
            openItem.keyEquivalentModifierMask = DoubleTapModifier.cocoaModifiers(from: modifiers)
        } else {
            // 双击模式不显示快捷键
            openItem.keyEquivalent = ""
            openItem.keyEquivalentModifierMask = []
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        print("LaunchX: applicationDidBecomeActive called")
        // 如果引导页窗口存在但不可见，强制显示
        if let window = onboardingWindow, !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func checkPermissionsAndSetup() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        // 同步检查辅助功能权限（这是最重要的权限）
        let hasAccessibility = AXIsProcessTrusted()

        print("LaunchX: isFirstLaunch=\(isFirstLaunch), hasAccessibility=\(hasAccessibility)")

        // 异步更新其他权限状态（用于 UI 显示）
        PermissionService.shared.checkAllPermissions()

        // 等待权限状态更新后检查是否所有权限都已授予
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let accessibility = PermissionService.shared.isAccessibilityGranted
            let fullDisk = PermissionService.shared.isFullDiskAccessGranted

            print(
                "LaunchX: accessibility=\(accessibility), fullDisk=\(fullDisk)"
            )

            if isFirstLaunch {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                if accessibility {
                    // 首次启动且辅助功能已授予，直接进入应用
                    print("LaunchX: First launch and accessibility granted, showing panel")
                    NSApp.setActivationPolicy(.accessory)
                    self.setupStatusItem()
                    self.setupHotKeyAndShowPanel()
                } else {
                    print("LaunchX: First launch, opening onboarding")
                    self.openOnboarding()
                }
            } else if !accessibility {
                print("LaunchX: Accessibility not granted, opening onboarding")
                self.openOnboarding()
            } else {
                print("LaunchX: Accessibility granted, showing panel")
                NSApp.setActivationPolicy(.accessory)
                self.setupStatusItem()
                self.setupHotKeyAndShowPanel()
            }

            // 监听权限变化，当辅助功能权限授予后设置热键
            self.observePermissionChanges()
        }
    }

    private func observePermissionChanges() {
        permissionObserver = PermissionService.shared.$isAccessibilityGranted
            .removeDuplicates()
            .sink { [weak self] isGranted in
                if isGranted {
                    self?.setupHotKey()
                }
            }
    }

    private func setupHotKey() {
        // 只有辅助功能权限授予后才设置热键
        guard AXIsProcessTrusted() else { return }

        // Setup Global HotKey (Option + Space)
        HotKeyService.shared.setupGlobalHotKey()

        // Bind HotKey Action
        HotKeyService.shared.onHotKeyPressed = {
            PanelManager.shared.togglePanel()
        }

        // 设置自定义快捷键回调
        setupCustomHotKeys()

        print("LaunchX: HotKey setup complete")
    }

    /// 设置自定义快捷键
    private func setupCustomHotKeys() {
        // 设置自定义快捷键触发回调（使用 ToolExecutor）
        HotKeyService.shared.onCustomHotKeyPressed = { toolId, isExtension in
            ToolExecutor.shared.execute(toolId: toolId, isExtension: isExtension)
        }

        // 设置书签快捷键回调
        HotKeyService.shared.onBookmarkHotKeyPressed = {
            // 检查书签功能是否启用
            let settings = BookmarkSettings.load()
            guard settings.isEnabled else { return }
            PanelManager.shared.showPanelInBookmarkMode()
        }

        // 设置 2FA 快捷键回调
        HotKeyService.shared.on2FAHotKeyPressed = {
            // 检查 2FA 功能是否启用
            let settings = TwoFactorAuthSettings.load()
            guard settings.isEnabled else { return }
            PanelManager.shared.showPanelIn2FAMode()
        }

        // 设置剪贴板快捷键回调
        HotKeyService.shared.onClipboardHotKeyPressed = {
            // 检查剪贴板功能是否启用
            let settings = ClipboardSettings.load()
            guard settings.isEnabled else { return }
            ClipboardPanelManager.shared.togglePanel()
        }

        // 设置纯文本粘贴快捷键回调
        HotKeyService.shared.onPlainTextPasteHotKeyPressed = {
            // 获取当前剪贴板面板选中项，粘贴为纯文本
            ClipboardPanelManager.shared.pasteSelectedAsPlainText()
        }

        // 设置选词翻译快捷键回调
        HotKeyService.shared.onTranslateSelectionHotKeyPressed = {
            let settings = AITranslateSettings.load()
            guard settings.isEnabled else { return }
            AITranslatePanelManager.shared.showPanelWithSelection()
        }

        // 设置输入翻译快捷键回调
        HotKeyService.shared.onTranslateInputHotKeyPressed = {
            let settings = AITranslateSettings.load()
            guard settings.isEnabled else { return }
            AITranslatePanelManager.shared.togglePanel()
        }

        // 优先从新的 ToolsConfig 加载，否则回退到 CustomItemsConfig
        let toolsConfig = ToolsConfig.load()
        if !toolsConfig.tools.isEmpty {
            HotKeyService.shared.reloadToolHotKeys(from: toolsConfig)
            print("LaunchX: Tool hotkeys loaded from ToolsConfig")
        } else {
            let config = CustomItemsConfig.load()
            HotKeyService.shared.reloadCustomHotKeys(from: config)
            print("LaunchX: Custom hotkeys loaded from CustomItemsConfig")
        }

        // 加载书签快捷键
        HotKeyService.shared.loadBookmarkHotKey()

        // 加载 2FA 快捷键
        HotKeyService.shared.load2FAHotKey()

        // 加载剪贴板快捷键
        HotKeyService.shared.loadClipboardHotKey()
        HotKeyService.shared.loadPlainTextPasteHotKey()

        // 加载翻译快捷键
        HotKeyService.shared.loadTranslateHotKeys()

        // 启动剪贴板监听
        ClipboardService.shared.startMonitoring()

        // 启动 Snippet 监听
        SnippetService.shared.startMonitoring()
    }

    private func setupHotKeyAndShowPanel() {
        setupHotKey()
        // 显示搜索面板
        PanelManager.shared.togglePanel()
    }

    func openOnboarding() {
        print("LaunchX: Opening onboarding window")

        if onboardingWindow == nil {
            let rootView = OnboardingView { [weak self] in
                guard let self = self else { return }
                // 1. 设置热键并显示面板
                self.setupHotKeyAndShowPanel()

                // 2. 关闭引导页窗口并清理引用
                self.onboardingWindow?.close()
                self.onboardingWindow = nil

                // 3. 切换为 accessory app (不在 Dock 显示)
                NSApp.setActivationPolicy(.accessory)

                // 4. 重新设置状态栏以确保在切换模式后正确显示
                self.setupStatusItem()
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: rootView)
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.title = "欢迎使用 LaunchX"

            // Hide zoom and minimize buttons for a cleaner look
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true

            onboardingWindow = window
        }

        // 启动时已经是 regular 模式，直接显示窗口
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()  // 强制到最前面
        NSApp.activate(ignoringOtherApps: true)

        print("LaunchX: Onboarding window frame: \(onboardingWindow?.frame ?? .zero)")
        print("LaunchX: Onboarding window isVisible: \(onboardingWindow?.isVisible ?? false)")
    }

    func setupStatusItem() {
        print("LaunchX: setupStatusItem called")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        print("LaunchX: statusItem created: \(statusItem != nil)")

        if let button = statusItem.button {
            // 尝试使用系统图标作为备选
            if let image = NSImage(named: NSImage.Name("StatusBarIcon")) {
                image.isTemplate = true
                button.image = image
                print("LaunchX: Using StatusBarIcon")
            } else {
                // 备选：使用系统图标
                button.image = NSImage(
                    systemSymbolName: "magnifyingglass", accessibilityDescription: "LaunchX")
                print("LaunchX: Using system icon as fallback")
            }
            print("LaunchX: button.image set: \(button.image != nil)")
        }

        // 创建并设置菜单
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 获取当前快捷键设置
        let hotKeyService = HotKeyService.shared
        let keyCode = hotKeyService.currentKeyCode
        let modifiers = hotKeyService.currentModifiers
        let useDoubleTap = hotKeyService.useDoubleTapModifier

        let openItem = NSMenuItem(
            title: "打开 LaunchX", action: #selector(togglePanel), keyEquivalent: "")
        openItem.target = self
        openItem.isEnabled = true

        // 设置快捷键显示
        if !useDoubleTap {
            // 传统快捷键模式：设置 keyEquivalent
            let keyChar = DoubleTapModifier.keyCharacter(for: keyCode)
            openItem.keyEquivalent = keyChar
            openItem.keyEquivalentModifierMask = DoubleTapModifier.cocoaModifiers(from: modifiers)
        }
        // 双击模式不显示快捷键（因为无法在菜单中表示）

        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(explicitQuit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.isVisible = true
        print("LaunchX: StatusItem menu set, items count: \(menu.items.count)")

        print(
            "LaunchX: StatusItem setup complete, button: \(statusItem.button != nil), menu: \(statusItem.menu != nil)"
        )
    }

    @objc func togglePanel() {
        PanelManager.shared.togglePanel()
    }

    @objc func openSettings() {
        PanelManager.shared.hidePanel()

        // 发送通知，让 SettingsOpenerView 通过 @Environment(\.openSettings) 打开设置
        // 不需要切换到 regular 模式，避免 Dock 图标出现
        NotificationCenter.default.post(name: .openSettingsNotification, object: nil)
    }

    @objc func explicitQuit() {
        isQuitting = true
        NSApp.terminate(nil)
    }

    // Intercept termination request (Cmd+Q) to keep the app running in the background
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isQuitting {
            return .terminateNow
        }

        // Close all windows (Settings, Onboarding, etc.) but keep the app running
        for window in NSApp.windows {
            window.close()
        }

        // Hide the application
        NSApp.hide(nil)

        return .terminateCancel
    }
}
