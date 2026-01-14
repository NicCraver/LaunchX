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
    private var isStatusItemSetup = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSettingsOpenerWindow()
        observeHotKeyChanges()

        // Activation policy and status item setup are handled in checkPermissionsAndSetup
        // 如果需要显示引导页，保持 regular 模式
        // 如果权限已全部授予，再切换到 accessory 模式

        // Disable automatic window tabbing (Sierra+)
        NSWindow.allowsAutomaticWindowTabbing = false

        // 1. Initialize the Search Panel (pure AppKit, no SwiftUI)
        PanelManager.shared.setup()

        // 拦截系统默认的 Cmd+Q 行为，防止其干扰菜单栏图标
        if let mainMenu = NSApp.mainMenu {
            for item in mainMenu.items {
                if let submenu = item.submenu {
                    for subItem in submenu.items {
                        if subItem.action == #selector(NSApplication.terminate(_:)) {
                            subItem.target = self
                            subItem.action = #selector(handleQuitMenuClick)
                        }
                    }
                }
            }
        }

        // 2. Check permissions first before setting up hotkey
        checkPermissionsAndSetup()

        // 3. 启动时静默检查更新 (不了不了，做一个不打扰的小朋友)
        // UpdateService.shared.checkForUpdates(manual: false)
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
        // 只有在辅助功能已授权且没有显示引导页时，才强制设为 accessory 模式
        if PermissionService.shared.isAccessibilityGranted && onboardingWindow == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if NSApp.activationPolicy() != .accessory {
                    print(
                        "LaunchX: Forcing accessory mode (current: \(NSApp.activationPolicy().rawValue))"
                    )
                    NSApp.setActivationPolicy(.accessory)
                    print(
                        "LaunchX: Accessory mode forced (new: \(NSApp.activationPolicy().rawValue))"
                    )
                }
            }
        }

        // 只有在权限未授予时才强制显示授权窗口
        // 避免在用户已授权后仍然弹出授权窗口
        if let window = onboardingWindow,
            !window.isKeyWindow,
            !PermissionService.shared.isAccessibilityGranted
        {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func checkPermissionsAndSetup() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        let didJustUpdate = UserDefaults.standard.bool(forKey: "didJustUpdateAndRelaunch")

        // 同步检查辅助功能权限（这是最重要的权限）
        let hasAccessibility = AXIsProcessTrusted()

        print(
            "LaunchX: isFirstLaunch=\(isFirstLaunch), hasAccessibility=\(hasAccessibility), didJustUpdate=\(didJustUpdate)"
        )

        // 异步更新其他权限状态（用于 UI 显示）
        PermissionService.shared.checkAllPermissions()

        // 如果是更新后重启，等待更长时间让系统重新验证签名和权限
        let delay: TimeInterval = didJustUpdate ? 2.0 : 0.5

        // 根据辅助功能权限状态设置初始运行模式
        // 如果没有权限，设为 regular 以便正确显示引导窗口；如果有权限，设为 accessory
        let initialPolicy: NSApplication.ActivationPolicy = hasAccessibility ? .accessory : .regular

        print(
            "LaunchX: Setting activation policy to \(initialPolicy == .accessory ? "accessory" : "regular") (current: \(NSApp.activationPolicy().rawValue))"
        )
        NSApp.setActivationPolicy(initialPolicy)
        print(
            "LaunchX: About to create status item immediately, resetting isStatusItemSetup from \(self.isStatusItemSetup)"
        )
        self.isStatusItemSetup = false
        self.setupStatusItem()
        print("LaunchX: Status item created immediately on app launch")

        // 清除更新标记
        if didJustUpdate {
            UserDefaults.standard.removeObject(forKey: "didJustUpdateAndRelaunch")
        }

        // 等待权限状态更新后检查是否所有权限都已授予
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
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
                    self.setupHotKeyAndShowPanel()
                } else {
                    print("LaunchX: First launch, opening onboarding")
                    self.openOnboarding()
                }
            } else if !accessibility {
                print("LaunchX: Accessibility not granted, opening onboarding")
                // 确保没有权限时处于 regular 模式，以便显示引导窗口
                NSApp.setActivationPolicy(.regular)
                self.openOnboarding()
            } else {
                // 权限已授予，确保处于 accessory 模式
                NSApp.setActivationPolicy(.accessory)
                print("LaunchX: Accessibility granted, showing panel")
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
                guard let self = self else { return }

                if isGranted {
                    // 权限被授予时立即设置 menubar 图标和热键
                    NSApp.setActivationPolicy(.accessory)
                    // 强制重置标志以确保 menubar 图标被创建
                    self.isStatusItemSetup = false
                    self.setupStatusItem()
                    self.setupHotKey()
                    // 不自动关闭授权窗口，让用户完成所有授权后手动点击"开始使用"
                    print("LaunchX: Accessibility granted, statusItem and hotkey setup complete")
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

        // 设置表情包快捷键回调
        HotKeyService.shared.onMemeHotKeyPressed = {
            let settings = MemeSearchSettings.load()
            guard settings.isEnabled else { return }
            PanelManager.shared.showPanelInMemeMode()
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

        // 加载表情包快捷键
        HotKeyService.shared.loadMemeHotKey()

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
                print("LaunchX: Onboarding onFinish callback called")

                // 1. 设置热键并显示面板
                self.setupHotKeyAndShowPanel()

                // 2. 关闭引导页窗口并清理引用
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                print("LaunchX: Onboarding window closed")
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
                styleMask: [.titled, .fullSizeContentView],  // 移除 .closable - 去掉关闭按钮
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
        print(
            "LaunchX: setupStatusItem called, isStatusItemSetup=\(isStatusItemSetup), statusItem!=nil=\(statusItem != nil)"
        )

        // Prevent multiple setups
        if isStatusItemSetup && statusItem != nil {
            print("LaunchX: StatusItem already setup, skipping")
            return
        }

        // Clean up existing status item if it exists
        if let existingItem = statusItem {
            NSStatusBar.system.removeStatusItem(existingItem)
            print("LaunchX: Removed existing status item")
        }

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

        let updateItem = NSMenuItem(
            title: "检查更新...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = true
        menu.addItem(updateItem)

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

        // Mark as properly setup
        isStatusItemSetup = true
    }

    @objc func togglePanel() {
        print("LaunchX: togglePanel called via menubar")
        PanelManager.shared.togglePanel()
    }

    @objc func handleQuitMenuClick() {
        print("LaunchX: Cmd+Q intercepted, hiding instead of quitting")
        PanelManager.shared.hidePanel()
    }

    @objc func openSettings() {
        PanelManager.shared.hidePanel()

        // 激活应用，确保设置窗口在当前活跃的空间/屏幕打开
        NSApp.activate(ignoringOtherApps: true)

        // 发送通知，让 SettingsOpenerView 通过 @Environment(\.openSettings) 打开设置
        // 不需要切换到 regular 模式，避免 Dock 图标出现
        NotificationCenter.default.post(name: .openSettingsNotification, object: nil)
    }

    @objc func explicitQuit() {
        // Clean up status item before quitting
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        isStatusItemSetup = false
        isQuitting = true
        NSApp.terminate(nil)
    }

    @objc func checkForUpdates() {
        UpdateService.shared.checkForUpdates(manual: true)
    }

    // Intercept termination request (Cmd+Q) to keep the app running in the background
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print(
            "LaunchX: applicationShouldTerminate called, isQuitting: \(isQuitting), isPreparingForUpdate: \(UpdateService.shared.isPreparingForUpdate)"
        )

        // 1. 明确点击“退出”菜单或正在更新，允许退出
        if isQuitting || UpdateService.shared.isPreparingForUpdate {
            print("LaunchX: Explicit quit or update, terminating now")
            return .terminateNow
        }

        // 2. 检查退出原因 (NSEvent.modifierFlags 无法在这里直接判断是否是 Cmd+Q)
        // 但我们可以根据 NSApp.currentEvent 来判断触发来源
        let currentEvent = NSApp.currentEvent
        let isCommandQ =
            currentEvent?.type == .keyDown && currentEvent?.modifierFlags.contains(.command) == true
            && currentEvent?.charactersIgnoringModifiers == "q"

        // 如果是 Cmd+Q 触发的，且当前已经授权（在后台运行模式），则拦截并隐藏
        // 这样可以避免 Xcode 调试中断，同时符合常驻工具的习惯
        if isCommandQ && PermissionService.shared.isAccessibilityGranted {
            print("LaunchX: Intercepting Cmd+Q, performing safe hide")
            DispatchQueue.main.async {
                PanelManager.shared.hidePanel()
                for window in NSApp.windows where window.isVisible {
                    window.close()
                }
                NSApp.hide(nil)
            }
            return .terminateCancel
        }

        // 3. 其他情况（如系统关机、重启、权限变更导致强制退出）允许退出
        // 这解决了之前“授权后重启图标消失”的问题
        print("LaunchX: System initiated termination, allowing...")
        return .terminateNow
    }
}
