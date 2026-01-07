import Cocoa

/// AI 翻译浮动面板
class AITranslatePanel: NSPanel {

    /// 圆角半径
    private let cornerRadius: CGFloat = 12

    /// 标题栏高度（只有这个区域可以拖动）
    private let titleBarHeight: CGFloat = 44

    /// 拖动起始位置
    private var initialMouseLocation: NSPoint?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: backingStoreType,
            defer: flag
        )

        // 窗口层级 - 使用 screenSaver 级别以显示在全屏应用上方
        self.level = .screenSaver

        // 收集行为配置
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        // 视觉配置
        self.backgroundColor = NSColor(named: "PanelBackground") ?? NSColor.windowBackgroundColor
        self.isOpaque = false
        self.hasShadow = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        // 隐藏标题栏按钮
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        // 性能配置
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        // 关闭默认的背景拖动，我们自己控制
        self.isMovableByWindowBackground = false
        self.animationBehavior = .none
        self.isRestorable = false
    }

    override var contentView: NSView? {
        didSet {
            // 确保内容视图有圆角
            if let view = contentView {
                view.wantsLayer = true
                view.layer?.cornerRadius = cornerRadius
                view.layer?.masksToBounds = true
            }

            // 增强阴影效果
            self.hasShadow = true
            if let shadowView = contentView?.superview {
                shadowView.shadow = NSShadow()
                shadowView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.45)
                shadowView.shadow?.shadowOffset = NSSize(width: 0, height: -3)
                shadowView.shadow?.shadowBlurRadius = 12
            }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: - 只允许顶部标题栏拖动

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let locationInWindow = event.locationInWindow
            let windowHeight = self.frame.height

            // 只有点击顶部标题栏区域才开始拖动
            if locationInWindow.y > windowHeight - titleBarHeight {
                // 检查是否点击了按钮（如固定按钮）
                if let contentView = self.contentView,
                    let hitView = contentView.hitTest(
                        contentView.convert(locationInWindow, from: nil)),
                    hitView is NSButton
                {
                    // 点击的是按钮，正常处理
                    super.sendEvent(event)
                } else {
                    // 开始拖动
                    initialMouseLocation = NSEvent.mouseLocation
                }
            } else {
                super.sendEvent(event)
            }

        case .leftMouseDragged:
            if let initialLocation = initialMouseLocation {
                let currentLocation = NSEvent.mouseLocation
                let deltaX = currentLocation.x - initialLocation.x
                let deltaY = currentLocation.y - initialLocation.y

                var newOrigin = self.frame.origin
                newOrigin.x += deltaX
                newOrigin.y += deltaY

                self.setFrameOrigin(newOrigin)
                initialMouseLocation = currentLocation
            } else {
                super.sendEvent(event)
            }

        case .leftMouseUp:
            if initialMouseLocation != nil {
                initialMouseLocation = nil
            } else {
                super.sendEvent(event)
            }

        default:
            super.sendEvent(event)
        }
    }
}
