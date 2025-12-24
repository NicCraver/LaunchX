import Combine
import SwiftUI

@main
struct LaunchXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use Settings to avoid creating a default WindowGroup window.
        // The actual main interface is managed by PanelManager.
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var onboardingWindow: NSWindow?
    var isQuitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Transform into an accessory app (hide Dock icon, show over full-screen apps)
        NSApp.setActivationPolicy(.accessory)

        // Disable automatic window tabbing (Sierra+)
        NSWindow.allowsAutomaticWindowTabbing = false

        // 1. Initialize the Search Panel (pure AppKit, no SwiftUI)
        PanelManager.shared.setup()

        // 2. Setup Global HotKey (Option + Space)
        HotKeyService.shared.setupGlobalHotKey()

        // 3. Bind HotKey Action
        HotKeyService.shared.onHotKeyPressed = {
            PanelManager.shared.togglePanel()
        }

        // setupStatusItem()  // 暂时隐藏菜单栏图标
        checkPermissions()
    }

    func checkPermissions() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        // 检查权限状态
        PermissionService.shared.checkAllPermissions()

        // 延迟检查，等待权限状态更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let allGranted = PermissionService.shared.allPermissionsGranted

            if isFirstLaunch {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                // 首次启动，打开引导页
                self.openOnboarding()
            } else if !allGranted {
                // 非首次启动但权限未完成，继续显示引导页
                self.openOnboarding()
            }
        }
    }

    func openOnboarding() {
        if onboardingWindow == nil {
            let rootView = OnboardingView { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                // Show the panel after onboarding is done
                PanelManager.shared.togglePanel()
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("OnboardingWindow")
            window.contentView = NSHostingView(rootView: rootView)
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.title = "Welcome to LaunchX"

            // Hide zoom and minimize buttons for a cleaner look
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true

            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "magnifyingglass", accessibilityDescription: "LaunchX")
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Open LaunchX", action: #selector(togglePanel), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(explicitQuit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func togglePanel() {
        PanelManager.shared.togglePanel()
    }

    @objc func openSettings() {
        PanelManager.shared.hidePanel(deactivateApp: false)
        // Send action to open the Settings window defined in the App struct
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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
