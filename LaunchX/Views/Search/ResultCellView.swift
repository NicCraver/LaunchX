import AppKit

// MARK: - Result Cell View

class ResultCellView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let aliasLabel = NSTextField(labelWithString: "")  // 别名标签
    private let aliasBadgeView = NSView()  // 别名背景视图
    private let pathLabel = NSTextField(labelWithString: "")
    private let backgroundView = NSView()
    private let arrowIndicator = NSImageView()  // IDE 箭头指示器
    private let linkIndicator = NSImageView()  // 链接指示器

    // 进程统计信息（三列独立显示）
    private let portLabel = NSTextField(labelWithString: "")
    private let cpuIcon = NSImageView()
    private let cpuLabel = NSTextField(labelWithString: "")
    private let memoryIcon = NSImageView()
    private let memoryLabel = NSTextField(labelWithString: "")
    private let statsContainerView = NSStackView()  // 统计信息容器

    // 用于切换 nameLabel 位置的约束
    private var nameLabelTopConstraint: NSLayoutConstraint!
    private var nameLabelCenterYConstraint: NSLayoutConstraint!
    private var nameLabelTrailingToArrow: NSLayoutConstraint!
    private var nameLabelTrailingToEdge: NSLayoutConstraint!
    private var nameLabelTrailingToStats: NSLayoutConstraint!
    private var pathLabelTrailingToArrow: NSLayoutConstraint!
    private var pathLabelTrailingToEdge: NSLayoutConstraint!

    // 分组标题模式的约束
    private var nameLabelLeadingNormal: NSLayoutConstraint!
    var nameLabelLeadingHeader: NSLayoutConstraint!
    private var portLabelWidthConstraint: NSLayoutConstraint!
    var onIconClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    @objc private func iconClicked() {
        onIconClick?()
    }

    private func setupViews() {
        // Background
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 8
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconClickGesture = NSClickGestureRecognizer(
            target: self, action: #selector(iconClicked))
        iconView.addGestureRecognizer(iconClickGesture)
        addSubview(iconView)

        // Name
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        addSubview(nameLabel)

        // Alias badge background (圆角背景) - 紧跟在名称后面
        aliasBadgeView.wantsLayer = true
        aliasBadgeView.layer?.cornerRadius = 6
        aliasBadgeView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.25).cgColor
        aliasBadgeView.translatesAutoresizingMaskIntoConstraints = false
        aliasBadgeView.isHidden = true
        addSubview(aliasBadgeView)

        // Alias label
        aliasLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        aliasLabel.textColor = .secondaryLabelColor
        aliasLabel.translatesAutoresizingMaskIntoConstraints = false
        aliasLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(aliasLabel)

        // Path
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pathLabel)

        // Arrow indicator for IDE apps
        arrowIndicator.image = NSImage(
            systemSymbolName: "arrow.right.to.line",
            accessibilityDescription: "Tab to open projects")
        arrowIndicator.contentTintColor = .secondaryLabelColor
        arrowIndicator.translatesAutoresizingMaskIntoConstraints = false
        arrowIndicator.isHidden = true
        addSubview(arrowIndicator)

        // Link indicator
        // 链接指示器 (将作为 arranged subview 添加到 statsContainerView)
        linkIndicator.image = NSImage(
            systemSymbolName: "globe",
            accessibilityDescription: "Has URL")
        linkIndicator.contentTintColor = .systemBlue
        linkIndicator.translatesAutoresizingMaskIntoConstraints = false
        linkIndicator.isHidden = true
        linkIndicator.widthAnchor.constraint(equalToConstant: 13).isActive = true
        linkIndicator.heightAnchor.constraint(equalToConstant: 13).isActive = true

        // 进程统计信息容器
        // 进程统计信息容器 (StackView)
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.isHidden = true
        statsContainerView.orientation = .horizontal
        statsContainerView.spacing = 6
        statsContainerView.alignment = .centerY
        statsContainerView.distribution = .fill
        addSubview(statsContainerView)

        // 添加链接指示器作为第一个子视图
        statsContainerView.addArrangedSubview(linkIndicator)

        // 端口号标签
        portLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        portLabel.textColor = .secondaryLabelColor
        portLabel.alignment = .left
        portLabel.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addArrangedSubview(portLabel)

        // CPU 图标
        cpuIcon.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
        cpuIcon.contentTintColor = .secondaryLabelColor
        cpuIcon.translatesAutoresizingMaskIntoConstraints = false
        cpuIcon.widthAnchor.constraint(equalToConstant: 12).isActive = true
        cpuIcon.heightAnchor.constraint(equalToConstant: 12).isActive = true
        statsContainerView.addArrangedSubview(cpuIcon)

        // CPU 标签
        cpuLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cpuLabel.textColor = .secondaryLabelColor
        cpuLabel.alignment = .left
        cpuLabel.translatesAutoresizingMaskIntoConstraints = false
        cpuLabel.widthAnchor.constraint(equalToConstant: 45).isActive = true
        statsContainerView.addArrangedSubview(cpuLabel)

        // 内存图标
        memoryIcon.image = NSImage(
            systemSymbolName: "memorychip", accessibilityDescription: "Memory")
        memoryIcon.contentTintColor = .secondaryLabelColor
        memoryIcon.translatesAutoresizingMaskIntoConstraints = false
        memoryIcon.widthAnchor.constraint(equalToConstant: 12).isActive = true
        memoryIcon.heightAnchor.constraint(equalToConstant: 12).isActive = true
        statsContainerView.addArrangedSubview(memoryIcon)

        // 内存标签
        memoryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        memoryLabel.textColor = .secondaryLabelColor
        memoryLabel.alignment = .left
        memoryLabel.translatesAutoresizingMaskIntoConstraints = false
        memoryLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        statsContainerView.addArrangedSubview(memoryLabel)

        // 创建布局约束
        nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6)
        nameLabelCenterYConstraint = nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        // 名称的 trailing 约束（用于没有别名时限制宽度）
        nameLabelTrailingToArrow = nameLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: arrowIndicator.leadingAnchor, constant: -8)
        nameLabelTrailingToEdge = nameLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: trailingAnchor, constant: -20)
        nameLabelTrailingToStats = nameLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: statsContainerView.leadingAnchor, constant: -12)

        // 路径的 trailing 约束
        pathLabelTrailingToArrow = pathLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: arrowIndicator.leadingAnchor, constant: -8)
        pathLabelTrailingToEdge = pathLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: trailingAnchor, constant: -20)

        // 名称的 leading 约束
        nameLabelLeadingNormal = nameLabel.leadingAnchor.constraint(
            equalTo: iconView.trailingAnchor, constant: 12)
        nameLabelLeadingHeader = nameLabel.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: 16)  // 分组标题靠左对齐

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            backgroundView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameLabelLeadingNormal,
            nameLabelTopConstraint,

            // Alias badge - 紧跟在名称后面
            aliasBadgeView.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            aliasBadgeView.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            aliasLabel.leadingAnchor.constraint(equalTo: aliasBadgeView.leadingAnchor, constant: 6),
            aliasLabel.trailingAnchor.constraint(
                equalTo: aliasBadgeView.trailingAnchor, constant: -6),
            aliasLabel.topAnchor.constraint(equalTo: aliasBadgeView.topAnchor, constant: 2),
            aliasLabel.bottomAnchor.constraint(equalTo: aliasBadgeView.bottomAnchor, constant: -2),

            // Arrow indicator
            arrowIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            arrowIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowIndicator.widthAnchor.constraint(equalToConstant: 16),
            arrowIndicator.heightAnchor.constraint(equalToConstant: 16),

            // 统计信息容器（靠右）
            statsContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            statsContainerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            {
                portLabelWidthConstraint = portLabel.widthAnchor.constraint(equalToConstant: 50)
                return portLabelWidthConstraint
            }(),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])
    }

    func configure(with item: SearchResult, isSelected: Bool, hideArrow: Bool = false) {
        // 处理分组标题
        if item.isSectionHeader {
            configureSectionHeader(with: item)
            return
        }

        // 提醒事项特殊处理图标颜色和布局
        if item.isReminder {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            iconView.image = item.icon.withSymbolConfiguration(config)

            let reminderColor: NSColor = item.reminderColor ?? NSColor.systemOrange
            if isSelected {
                iconView.contentTintColor = NSColor.white
            } else {
                iconView.contentTintColor = reminderColor
            }

            // 确保标题拥有最高优先级，不被右侧日期挤压
            nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            // 提醒事项在右侧显示列表名称和截止日期（复用 statsContainer 区域）
            if let stats = item.processStats {
                portLabel.stringValue = stats
                portLabel.alignment = .right
                portLabel.lineBreakMode = .byTruncatingTail
                portLabel.textColor =
                    isSelected ? .white.withAlphaComponent(0.9) : .secondaryLabelColor
                portLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)

                // 日期和列表名设置为强制收缩，消除多余空白
                portLabel.setContentHuggingPriority(.required, for: .horizontal)
                portLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

                // 禁用固定的宽度约束，允许内容根据文字长度自动收缩，消除右侧留白
                portLabelWidthConstraint.isActive = false

                statsContainerView.isHidden = false
                cpuIcon.isHidden = true
                cpuLabel.isHidden = true
                memoryIcon.isHidden = true
                memoryLabel.isHidden = true
            }

            // 显示链接图标 (有 URL 时显示蓝色的 globe 图标)
            linkIndicator.isHidden = item.reminderURL == nil
            if isSelected {
                linkIndicator.contentTintColor = .white.withAlphaComponent(0.9)
            } else {
                linkIndicator.contentTintColor = .systemBlue
            }

            // 即使没有截止日期等统计信息，只要有链接也要显示右侧容器
            if !linkIndicator.isHidden {
                statsContainerView.isHidden = false
            }
        } else {
            linkIndicator.isHidden = true
            // 恢复普通模式布局
            portLabel.font = .systemFont(ofSize: 11)
            cpuIcon.isHidden = false
            cpuLabel.isHidden = false
            memoryIcon.isHidden = false
            memoryLabel.isHidden = false
            portLabel.alignment = .left
            portLabel.lineBreakMode = .byClipping
            nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

            // 重新启用宽度约束并恢复默认宽度
            portLabelWidthConstraint.isActive = true
            portLabelWidthConstraint.constant = 50
            iconView.image = item.icon
            iconView.contentTintColor = nil
        }
        iconView.isHidden = false
        nameLabel.stringValue = item.name

        // 显示别名标签（badge 样式，紧跟在名称后面）
        if let alias = item.displayAlias, !alias.isEmpty {
            aliasLabel.stringValue = alias
            aliasBadgeView.isHidden = false
        } else {
            aliasLabel.stringValue = ""
            aliasBadgeView.isHidden = true
        }

        // 显示进程统计信息（三列独立显示）
        let hasProcessStats = item.processStats != nil && !item.processStats!.isEmpty
        if hasProcessStats && !item.isReminder {
            // 恢复普通模式布局
            portLabel.alignment = .left
            portLabel.lineBreakMode = .byClipping
            portLabel.setContentHuggingPriority(.required, for: .horizontal)
            portLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            portLabelWidthConstraint.constant = 50

            // 解析 processStats: 格式为 "port|cpu|memory" 或 "|cpu|memory"（无端口）
            let stats = item.processStats!
            let parts = stats.components(separatedBy: "|")
            if parts.count >= 3 {
                portLabel.stringValue = parts[0]
                cpuLabel.stringValue = parts[1]
                memoryLabel.stringValue = parts[2]
            } else if parts.count == 2 {
                portLabel.stringValue = ""
                cpuLabel.stringValue = parts[0]
                memoryLabel.stringValue = parts[1]
            }
            statsContainerView.isHidden = false
        } else if !item.isReminder {
            portLabel.stringValue = ""
            cpuLabel.stringValue = ""
            memoryLabel.stringValue = ""
            statsContainerView.isHidden = true
        }

        // App、网页直达、实用工具、系统命令、书签入口、2FA 入口、表情包入口只显示名称（垂直居中、字体大），文件和文件夹显示路径
        let isApp = item.path.hasSuffix(".app")
        let isWebLink = item.isWebLink
        let isUtility = item.isUtility
        let isSystemCommand = item.isSystemCommand
        let isBookmarkEntry = item.isBookmarkEntry
        let is2FAEntry = item.is2FAEntry
        let isMemeEntry = item.isMemeEntry
        let isFavoriteEntry = item.isFavoriteEntry
        let isReminder = item.isReminder
        let showPathLabel =
            !isApp && !isWebLink && !isUtility && !isSystemCommand && !isBookmarkEntry
            && !is2FAEntry && !isMemeEntry && !isFavoriteEntry && !hasProcessStats && !isReminder
        pathLabel.isHidden = !showPathLabel
        pathLabel.stringValue = showPathLabel ? item.path : ""

        // 检测是否为支持的 IDE、文件夹、网页直达 Query 扩展、实用工具、书签入口、2FA 入口或表情包入口，显示箭头指示器
        // hideArrow 为 true 时强制隐藏（如文件夹打开模式下）
        // 有进程统计信息时也隐藏箭头
        let isIDE = IDEType.detect(from: item.path) != nil
        let isFolder = item.isDirectory && !isApp
        let isQueryWebLink = item.isWebLink && item.supportsQueryExtension
        let showArrow =
            !hideArrow && !hasProcessStats
            && (isIDE || isFolder || isQueryWebLink || isUtility || isBookmarkEntry || is2FAEntry
                || isMemeEntry || isFavoriteEntry)
        arrowIndicator.isHidden = !showArrow

        // 切换 nameLabel leading 约束（普通模式）
        nameLabelLeadingHeader.isActive = false
        nameLabelLeadingNormal.isActive = true

        // 切换 nameLabel trailing 约束
        nameLabelTrailingToEdge.isActive = false
        nameLabelTrailingToArrow.isActive = false
        nameLabelTrailingToStats.isActive = false

        if hasProcessStats {
            nameLabelTrailingToStats.isActive = true
        } else if showArrow {
            nameLabelTrailingToArrow.isActive = true
        } else {
            nameLabelTrailingToEdge.isActive = true
        }

        // 切换 pathLabel trailing 约束
        pathLabelTrailingToEdge.isActive = false
        pathLabelTrailingToArrow.isActive = false
        if showArrow {
            pathLabelTrailingToArrow.isActive = true
        } else {
            pathLabelTrailingToEdge.isActive = true
        }

        // 切换布局：App、网页直达、实用工具、系统命令、书签入口、2FA 入口、表情包入口、收藏入口、有进程统计的项、提醒事项垂直居中，其他顶部对齐
        if isApp || isWebLink || isUtility || isSystemCommand || isBookmarkEntry || is2FAEntry
            || isMemeEntry || isFavoriteEntry || hasProcessStats || isReminder
        {
            nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
            nameLabelTopConstraint.isActive = false
            nameLabelCenterYConstraint.isActive = true
        } else {
            nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
            nameLabelCenterYConstraint.isActive = false
            nameLabelTopConstraint.isActive = true
        }

        if isSelected {
            backgroundView.layer?.backgroundColor =
                NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
            nameLabel.textColor = .white
            pathLabel.textColor = .white.withAlphaComponent(0.8)
            arrowIndicator.contentTintColor = .white.withAlphaComponent(0.8)
            // 统计信息选中时的样式
            if item.isReminder {
                portLabel.textColor = .white.withAlphaComponent(0.8)
            } else {
                portLabel.textColor = .white.withAlphaComponent(0.9)
            }
            cpuIcon.contentTintColor = .white.withAlphaComponent(0.7)
            cpuLabel.textColor = .white.withAlphaComponent(0.8)
            memoryIcon.contentTintColor = .white.withAlphaComponent(0.7)
            memoryLabel.textColor = .white.withAlphaComponent(0.8)
            // 别名标签在选中时的样式
            aliasLabel.textColor = .white.withAlphaComponent(0.9)
            aliasBadgeView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        } else {
            backgroundView.layer?.backgroundColor = NSColor.clear.cgColor
            nameLabel.textColor = .labelColor
            pathLabel.textColor = .secondaryLabelColor
            arrowIndicator.contentTintColor = .secondaryLabelColor
            // 统计信息未选中时的样式
            portLabel.textColor = .secondaryLabelColor
            cpuIcon.contentTintColor = .tertiaryLabelColor
            cpuLabel.textColor = .secondaryLabelColor
            memoryIcon.contentTintColor = .tertiaryLabelColor
            memoryLabel.textColor = .secondaryLabelColor
            // 别名标签在未选中时的样式
            aliasLabel.textColor = .secondaryLabelColor
            aliasBadgeView.layer?.backgroundColor =
                NSColor.systemGray.withAlphaComponent(0.25).cgColor
        }
    }

    /// 配置分组标题样式
    private func configureSectionHeader(with item: SearchResult) {
        // 隐藏不需要的元素
        iconView.isHidden = true
        aliasBadgeView.isHidden = true
        aliasLabel.stringValue = ""
        pathLabel.isHidden = true
        arrowIndicator.isHidden = true
        statsContainerView.isHidden = true
        backgroundView.layer?.backgroundColor = NSColor.clear.cgColor

        // 设置标题样式
        nameLabel.stringValue = item.name
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor

        // 切换到标题布局（左对齐，无图标）
        nameLabelLeadingNormal.isActive = false
        nameLabelLeadingHeader.isActive = true
        nameLabelTopConstraint.isActive = false
        nameLabelCenterYConstraint.isActive = true

        // 清除其他约束
        nameLabelTrailingToEdge.isActive = false
        nameLabelTrailingToArrow.isActive = false
        nameLabelTrailingToStats.isActive = false
        nameLabelTrailingToEdge.isActive = true
    }
}

