import Cocoa

/// 提醒事项快捷跳转面板代理
protocol ReminderActionViewDelegate: AnyObject {
    func reminderActionViewDidRequestOpenURL(_ view: ReminderActionView)
    func reminderActionViewDidRequestOpenApp(_ view: ReminderActionView)
    func reminderActionViewDidRequestDismiss(_ view: ReminderActionView)
}

/// 专门用于提醒事项链接跳转的简洁面板
class ReminderActionView: NSView {

    // MARK: - Properties

    weak var delegate: ReminderActionViewDelegate?

    private let containerView = NSVisualEffectView()
    private let stackView = NSStackView()

    // 跳转链接按钮
    private let jumpButton = NSView()
    private let jumpLabel = NSTextField(labelWithString: "前往跳转")

    // 打开应用按钮
    private let appButton = NSView()
    private let appLabel = NSTextField(labelWithString: "在应用中打开")

    private let iconView = NSImageView()

    private var containerHeightConstraint: NSLayoutConstraint?

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
        containerView.layer?.cornerCurve = .continuous
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // 2. StackView 布局容器
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .centerX
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)

        // 3. 装饰图标
        iconView.image = NSImage(systemSymbolName: "safari.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 32).isActive = true

        // 4. 跳转按钮
        jumpButton.wantsLayer = true
        jumpButton.layer?.cornerRadius = 8
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        jumpButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        jumpButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        jumpLabel.font = .systemFont(ofSize: 14, weight: .bold)
        jumpLabel.alignment = .center
        jumpLabel.translatesAutoresizingMaskIntoConstraints = false
        jumpButton.addSubview(jumpLabel)

        NSLayoutConstraint.activate([
            jumpLabel.centerXAnchor.constraint(equalTo: jumpButton.centerXAnchor),
            jumpLabel.centerYAnchor.constraint(equalTo: jumpButton.centerYAnchor)
        ])

        // 5. 打开应用按钮
        appButton.wantsLayer = true
        appButton.layer?.cornerRadius = 8
        appButton.translatesAutoresizingMaskIntoConstraints = false
        appButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        appButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        appLabel.alignment = .center
        appLabel.translatesAutoresizingMaskIntoConstraints = false
        appButton.addSubview(appLabel)

        NSLayoutConstraint.activate([
            appLabel.centerXAnchor.constraint(equalTo: appButton.centerXAnchor),
            appLabel.centerYAnchor.constraint(equalTo: appButton.centerYAnchor)
        ])

        // 约束设置
        containerHeightConstraint = heightAnchor.constraint(equalToConstant: 165)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            widthAnchor.constraint(equalToConstant: 180),
            containerHeightConstraint!,

            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])

        // 添加阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 12

        // 添加点击手势
        let jumpGesture = NSClickGestureRecognizer(target: self, action: #selector(handleJump))
        jumpButton.addGestureRecognizer(jumpGesture)

        let appGesture = NSClickGestureRecognizer(target: self, action: #selector(handleOpenApp))
        appButton.addGestureRecognizer(appGesture)
    }

    @objc private func handleJump() {
        delegate?.reminderActionViewDidRequestOpenURL(self)
    }

    @objc private func handleOpenApp() {
        delegate?.reminderActionViewDidRequestOpenApp(self)
    }

    // MARK: - Logic

    func updateUI(hasURL: Bool) {
        // 清理并重新填充 StackView
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if hasURL {
            // 有链接模式
            stackView.addArrangedSubview(iconView)
            stackView.setCustomSpacing(12, after: iconView)
            stackView.addArrangedSubview(jumpButton)
            stackView.addArrangedSubview(appButton)

            jumpButton.isHidden = false
            iconView.isHidden = false

            // 跳转按钮为主按钮（黄色）
            jumpButton.layer?.backgroundColor = NSColor.systemYellow.cgColor
            jumpLabel.stringValue = "前往跳转"
            jumpLabel.textColor = .black
            jumpLabel.font = .systemFont(ofSize: 14, weight: .bold)

            // 应用按钮为次按钮（灰色）
            appButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
            appLabel.stringValue = "在应用中打开"
            appLabel.textColor = .labelColor
            appLabel.font = .systemFont(ofSize: 14, weight: .medium)

            containerHeightConstraint?.constant = 165
        } else {
            // 无链接模式
            stackView.addArrangedSubview(appButton)

            jumpButton.isHidden = true
            iconView.isHidden = true

            // 应用按钮变为主按钮（黄色）
            appButton.layer?.backgroundColor = NSColor.systemYellow.cgColor
            appLabel.stringValue = "在应用中打开"
            appLabel.textColor = .black
            appLabel.font = .systemFont(ofSize: 14, weight: .bold)

            containerHeightConstraint?.constant = 70
        }
    }

    // MARK: - Event Handling

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 36:  // Return
            if !jumpButton.isHidden {
                handleJump()
            } else {
                handleOpenApp()
            }
        case 53:  // Escape
            delegate?.reminderActionViewDidRequestDismiss(self)
        default:
            super.keyDown(with: event)
        }
    }
}
