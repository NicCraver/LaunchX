import Cocoa

/// AI 翻译浮动面板
class AITranslatePanel: NSPanel {

    /// 圆角半径
    private let cornerRadius: CGFloat = 12

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: backingStoreType,
            defer: flag
        )

        // 窗口层级
        self.level = .floating

        // 收集行为配置
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
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
        self.isMovableByWindowBackground = true
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
}
