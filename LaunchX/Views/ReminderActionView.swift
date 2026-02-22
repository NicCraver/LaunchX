import Cocoa

/// 提醒事项快捷跳转面板代理
protocol ReminderActionViewDelegate: AnyObject {
    func reminderActionViewDidRequestOpenURL(_ view: ReminderActionView)
    func reminderActionViewDidRequestDismiss(_ view: ReminderActionView)
}

/// 专门用于提醒事项链接跳转的简洁面板
class ReminderActionView: NSView {

    // MARK: - Properties

    weak var delegate: ReminderActionViewDelegate?

    private let containerView = NSVisualEffectView()
    private let jumpButton = NSView()
    private let jumpLabel = NSTextField(labelWithString: "前往跳转")
    private let iconView = NSImageView()

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        wantsLayer = true

        // 1. 毛玻璃容器
        containerView.material = .menu
        containerView.blendingMode = .behindWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // 2. 跳转按钮 (黄色高亮块)
        jumpButton.wantsLayer = true
        jumpButton.layer?.cornerRadius = 8
        jumpButton.layer?.backgroundColor = NSColor.systemYellow.cgColor
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(jumpButton)

        // 3. 按钮文字
        jumpLabel.font = .systemFont(ofSize: 14, weight: .bold)
        jumpLabel.textColor = .black
        jumpLabel.alignment = .center
        jumpLabel.translatesAutoresizingMaskIntoConstraints = false
        jumpButton.addSubview(jumpLabel)

        // 4. 装饰图标 (Safari 图标)
        iconView.image = NSImage(systemSymbolName: "safari.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconView)

        // 约束设置
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 容器固定大小
            widthAnchor.constraint(equalToConstant: 180),
            heightAnchor.constraint(equalToConstant: 120),

            // 图标居中靠上
            iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            // 跳转按钮位于下方
            jumpButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            jumpButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15),
            jumpButton.widthAnchor.constraint(equalToConstant: 140),
            jumpButton.heightAnchor.constraint(equalToConstant: 40),

            // 文字居中
            jumpLabel.centerXAnchor.constraint(equalTo: jumpButton.centerXAnchor),
            jumpLabel.centerYAnchor.constraint(equalTo: jumpButton.centerYAnchor),
        ])

        // 添加阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 12

        // 添加点击手势
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleJump))
        jumpButton.addGestureRecognizer(clickGesture)
    }

    @objc private func handleJump() {
        delegate?.reminderActionViewDidRequestOpenURL(self)
    }

    // MARK: - Event Handling

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 36:  // Return
            handleJump()
        case 53:  // Escape
            delegate?.reminderActionViewDidRequestDismiss(self)
        default:
            super.keyDown(with: event)
        }
    }
}
