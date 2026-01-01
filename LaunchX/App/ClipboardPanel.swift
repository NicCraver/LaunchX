import Cocoa

/// 剪贴板浮动面板（支持拖拽调整大小）
class ClipboardPanel: NSPanel {

    /// 可拖拽边缘的宽度
    private let resizeEdgeWidth: CGFloat = 8

    /// 最小/最大尺寸
    private let panelMinSize = NSSize(width: 280, height: 300)
    private let panelMaxSize = NSSize(width: 600, height: 800)

    /// 拖拽状态
    private var isResizing = false
    private var resizeEdge: ResizeEdge = .none
    private var initialFrame: NSRect = .zero
    private var initialMouseLocation: NSPoint = .zero

    enum ResizeEdge {
        case none, left, right
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        // 窗口层级
        self.level = .floating

        // 收集行为配置
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        // 视觉配置
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // 性能配置
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = false
        self.animationBehavior = .none
        self.isRestorable = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: - 拖拽调整大小

    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow

        // 检查是否在边缘
        if location.x < resizeEdgeWidth {
            resizeEdge = .left
            isResizing = true
        } else if location.x > frame.width - resizeEdgeWidth {
            resizeEdge = .right
            isResizing = true
        } else {
            resizeEdge = .none
            isResizing = false
        }

        if isResizing {
            initialFrame = frame
            initialMouseLocation = NSEvent.mouseLocation
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isResizing else {
            super.mouseDragged(with: event)
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - initialMouseLocation.x

        var newFrame = initialFrame

        switch resizeEdge {
        case .left:
            newFrame.origin.x = initialFrame.origin.x + deltaX
            newFrame.size.width = initialFrame.width - deltaX
        case .right:
            newFrame.size.width = initialFrame.width + deltaX
        case .none:
            break
        }

        // 应用尺寸限制
        newFrame.size.width = max(panelMinSize.width, min(panelMaxSize.width, newFrame.size.width))

        setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            resizeEdge = .none

            // 保存新尺寸
            var settings = ClipboardSettings.load()
            settings.panelWidth = frame.width
            settings.panelHeight = frame.height
            settings.save()

            // 恢复光标
            NSCursor.arrow.set()
        } else {
            super.mouseUp(with: event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = event.locationInWindow

        // 检查是否在边缘，更新光标
        if location.x < resizeEdgeWidth || location.x > frame.width - resizeEdgeWidth {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }

        super.mouseMoved(with: event)
    }
}
