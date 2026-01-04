import Cocoa

class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true)  // defer=true can reduce initial overhead

        // Level: use screenSaver level to appear above fullscreen apps
        self.level = .screenSaver

        // Collection Behavior:
        // - canJoinAllSpaces: appears on all spaces
        // - fullScreenAuxiliary: can appear over fullscreen apps
        // - ignoresCycle: not included in Cmd+` window cycling
        self.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle,
        ]

        // Visuals
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false  // No shadow to avoid corner issues

        // Behavior - all set to minimize system overhead
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = false
        self.animationBehavior = .none  // Disable window animations

        // Disable window restoration
        self.isRestorable = false

        self.center()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}
