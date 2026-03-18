import AppKit

/// 翻译结果单元格视图
/// 用于显示单个翻译服务的结果，包括服务名称、图标、内容和复制按钮
class TranslateCellView: NSView {

    // MARK: - Properties

    private let service: TranslateServiceConfig
    private let isLoading: Bool
    private let content: String?
    private let isError: Bool
    private var onCopy: ((String) -> Void)?

    private var headerView: NSView!
    private var contentLabel: NSTextField?
    private var copyButton: NSButton!

    // MARK: - Initialization

    init(service: TranslateServiceConfig, isLoading: Bool, content: String?, isError: Bool = false, onCopy: ((String) -> Void)? = nil) {
        self.service = service
        self.isLoading = isLoading
        self.content = content
        self.isError = isError
        self.onCopy = onCopy

        super.init(frame: .zero)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.identifier = NSUserInterfaceItemIdentifier("service_\(service.id)")

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        // 头部容器 - 包含图标和服务名
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)

        // 左侧 stack - 图标和服务名
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.spacing = 6
        leftStack.alignment = .centerY
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(leftStack)

        // 图标
        let iconView = NSImageView()
        iconView.image = NSImage(
            systemSymbolName: service.serviceType.iconName, accessibilityDescription: nil)
        iconView.contentTintColor = .systemTeal
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])
        leftStack.addArrangedSubview(iconView)

        // 服务名
        let nameLabel = NSTextField(labelWithString: service.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        leftStack.addArrangedSubview(nameLabel)

        // 头部布局约束
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            leftStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])

        // 内容区域
        if let content = content {
            let label = NSTextField(wrappingLabelWithString: content)
            label.font = NSFont.systemFont(ofSize: 14)
            label.textColor = isError ? NSColor.systemRed : NSColor.labelColor
            label.isEditable = false
            label.isSelectable = true
            label.focusRingType = .none
            label.drawsBackground = false
            label.isBordered = false
            label.allowsEditingTextAttributes = true
            label.translatesAutoresizingMaskIntoConstraints = false
            label.identifier = NSUserInterfaceItemIdentifier("content_\(service.id)")
            addSubview(label)
            contentLabel = label
        } else if isLoading {
            let loadingLabel = NSTextField(labelWithString: "翻译中...")
            loadingLabel.font = NSFont.systemFont(ofSize: 13)
            loadingLabel.textColor = NSColor.secondaryLabelColor
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(loadingLabel)
            contentLabel = loadingLabel
        }

        // 复制按钮 - 最后添加确保在最上层
        copyButton = NSButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        copyButton.bezelStyle = .accessoryBarAction
        copyButton.isBordered = false
        copyButton.imagePosition = .imageOnly
        copyButton.contentTintColor = .secondaryLabelColor
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.target = self
        copyButton.action = #selector(handleCopyButtonClick)
        addSubview(copyButton)

        // 布局约束
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -56),
            headerView.heightAnchor.constraint(equalToConstant: 24),

            copyButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            copyButton.widthAnchor.constraint(equalToConstant: 24),
            copyButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        if let label = contentLabel {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            ])
        } else {
            NSLayoutConstraint.activate([
                headerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
            ])
        }

        // 让视图可以水平拉伸填满父容器
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: - Actions

    @objc private func handleCopyButtonClick() {
        guard let label = contentLabel, !label.stringValue.isEmpty else { return }

        let text = label.stringValue
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // 调用回调
        onCopy?(text)

        // 视觉反馈 - 短暂改变图标为勾选
        let originalImage = copyButton.image
        copyButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "已复制")
        copyButton.contentTintColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.copyButton.image = originalImage
            self?.copyButton.contentTintColor = .secondaryLabelColor
        }
    }
}
