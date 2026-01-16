import Cocoa

/// 快捷操作类型
enum QuickActionType: CaseIterable {
    case openInTerminal  // cd 至此
    case showInFinder  // 在 Finder 中显示
    case copyPath  // 复制路径
    case airDrop  // 隔空投送
    case delete  // 删除

    var title: String {
        switch self {
        case .openInTerminal: return "cd 至此"
        case .showInFinder: return "在 Finder 中显示"
        case .copyPath: return "复制路径"
        case .airDrop: return "隔空投送"
        case .delete: return "删除"
        }
    }

    var icon: NSImage? {
        let symbolName: String
        switch self {
        case .openInTerminal: symbolName = "terminal"
        case .showInFinder: symbolName = "folder"
        case .copyPath: symbolName = "doc.on.doc"
        case .airDrop: symbolName = "airplayaudio"
        case .delete: symbolName = "trash"
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    var isDestructive: Bool {
        return self == .delete
    }
}

/// 快捷操作面板代理
protocol QuickActionsViewDelegate: AnyObject {
    func quickActionsView(_ view: QuickActionsView, didSelectAction action: QuickActionType)
    func quickActionsViewDidRequestDismiss(_ view: QuickActionsView)
}

/// 单个操作行视图
private class QuickActionRowView: NSView {
    let action: QuickActionType
    let index: Int

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let backgroundLayer = CALayer()

    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    init(action: QuickActionType, index: Int) {
        self.action = action
        self.index = index
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true

        // 背景层
        backgroundLayer.cornerRadius = 6
        layer?.addSublayer(backgroundLayer)

        // 图标
        iconView.image = action.icon
        iconView.imageScaling = .scaleProportionallyDown
        if action.isDestructive {
            iconView.contentTintColor = .systemRed
        } else {
            iconView.contentTintColor = .secondaryLabelColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // 标题
        titleLabel.stringValue = action.title
        titleLabel.font = NSFont.systemFont(ofSize: 13)
        titleLabel.textColor = action.isDestructive ? .systemRed : .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }

    private func updateAppearance() {
        if isSelected {
            backgroundLayer.backgroundColor =
                NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        } else {
            backgroundLayer.backgroundColor = NSColor.clear.cgColor
        }
    }
}

/// 快捷操作面板视图
class QuickActionsView: NSView {

    // MARK: - Properties

    weak var delegate: QuickActionsViewDelegate?

    private var selectedIndex: Int = 0 {
        didSet {
            updateSelection()
        }
    }

    private let actions: [QuickActionType] = QuickActionType.allCases
    private var rowViews: [QuickActionRowView] = []

    private let rowHeight: CGFloat = 28
    private let horizontalPadding: CGFloat = 6
    private let verticalPadding: CGFloat = 6
    private let separatorHeight: CGFloat = 1

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

        // 设置毛玻璃背景
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10
        visualEffectView.layer?.masksToBounds = true

        // 添加边框
        visualEffectView.layer?.borderWidth = 0.5
        visualEffectView.layer?.borderColor = NSColor.separatorColor.cgColor

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // 创建操作行
        var yOffset: CGFloat = verticalPadding

        for (index, action) in actions.enumerated() {
            // 在删除按钮前添加分隔线
            if action == .delete {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                visualEffectView.addSubview(separator)

                NSLayoutConstraint.activate([
                    separator.leadingAnchor.constraint(
                        equalTo: visualEffectView.leadingAnchor, constant: horizontalPadding + 4),
                    separator.trailingAnchor.constraint(
                        equalTo: visualEffectView.trailingAnchor, constant: -horizontalPadding - 4),
                    separator.topAnchor.constraint(
                        equalTo: visualEffectView.topAnchor, constant: yOffset),
                    separator.heightAnchor.constraint(equalToConstant: separatorHeight),
                ])

                yOffset += separatorHeight + 6
            }

            let rowView = QuickActionRowView(action: action, index: index)
            rowView.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.addSubview(rowView)

            // 添加点击手势
            let clickGesture = NSClickGestureRecognizer(
                target: self, action: #selector(rowClicked(_:)))
            rowView.addGestureRecognizer(clickGesture)

            // 添加追踪区域用于鼠标悬停
            let trackingArea = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: ["index": index]
            )
            rowView.addTrackingArea(trackingArea)

            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(
                    equalTo: visualEffectView.leadingAnchor, constant: horizontalPadding),
                rowView.trailingAnchor.constraint(
                    equalTo: visualEffectView.trailingAnchor, constant: -horizontalPadding),
                rowView.topAnchor.constraint(
                    equalTo: visualEffectView.topAnchor, constant: yOffset),
                rowView.heightAnchor.constraint(equalToConstant: rowHeight),
            ])

            rowViews.append(rowView)
            yOffset += rowHeight + 2
        }

        yOffset += verticalPadding - 2

        // 设置视图大小
        let viewWidth: CGFloat = 170
        let viewHeight: CGFloat = yOffset

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: viewWidth),
            heightAnchor.constraint(equalToConstant: viewHeight),
        ])

        // 添加阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.25
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 10

        // 初始选中状态
        updateSelection()
    }

    // MARK: - Selection

    private func updateSelection() {
        for (index, rowView) in rowViews.enumerated() {
            rowView.isSelected = (index == selectedIndex)
        }
    }

    // MARK: - Actions

    @objc private func rowClicked(_ gesture: NSClickGestureRecognizer) {
        guard let rowView = gesture.view as? QuickActionRowView else { return }
        selectedIndex = rowView.index
        delegate?.quickActionsView(self, didSelectAction: rowView.action)
    }

    // MARK: - Keyboard Navigation

    func moveSelectionUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func moveSelectionDown() {
        if selectedIndex < actions.count - 1 {
            selectedIndex += 1
        }
    }

    func executeSelectedAction() {
        guard selectedIndex >= 0 && selectedIndex < actions.count else { return }
        delegate?.quickActionsView(self, didSelectAction: actions[selectedIndex])
    }

    // MARK: - Mouse Tracking

    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
            let index = userInfo["index"] as? Int
        {
            selectedIndex = index
        }
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 126:  // Up arrow
            moveSelectionUp()
        case 125:  // Down arrow
            moveSelectionDown()
        case 36:  // Return
            executeSelectedAction()
        case 53:  // Escape
            delegate?.quickActionsViewDidRequestDismiss(self)
        default:
            super.keyDown(with: event)
        }
    }
}
