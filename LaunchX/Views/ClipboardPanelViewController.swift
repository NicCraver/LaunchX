import Cocoa

/// 剪贴板面板视图控制器
class ClipboardPanelViewController: NSViewController {

    // MARK: - UI 组件

    private let searchField = NSTextField()
    private let filterButton = NSPopUpButton()
    private let clearButton = NSButton()
    private let pinButton = NSButton()
    private let dragArea = DraggableView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField()

    // MARK: - 状态

    private var items: [ClipboardItem] = []
    private var filteredItems: [ClipboardItem] = []
    private var selectedFilter: ClipboardContentType? = nil
    private var selectedIndices: Set<Int> = []
    private var clickMode: ClipboardClickMode = .doubleClick

    // MARK: - 常量

    private let rowHeight: CGFloat = 56

    // MARK: - 生命周期

    override func loadView() {
        // 创建可调整大小的容器视图
        let containerView = ResizableContainerView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true

        // 创建毛玻璃效果视图
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(visualEffectView)

        // 让毛玻璃视图填充容器
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        self.view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        loadSettings()
        loadItems()
    }

    // MARK: - UI 设置

    private func setupUI() {
        // 可拖拽区域（顶部居中，热区比可见横杠大）
        dragArea.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dragArea)

        // 搜索框
        searchField.placeholderString = "输入关键词搜索"
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 14)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        // 过滤按钮
        setupFilterButton()

        // 清空按钮（扫把图标）
        clearButton.image = NSImage(
            systemSymbolName: "paintbrush.pointed", accessibilityDescription: "清空")
        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.target = self
        clearButton.action = #selector(clearHistory)
        clearButton.toolTip = "清空剪贴板历史"
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clearButton)

        // 固定按钮
        pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "固定")
        pinButton.bezelStyle = .inline
        pinButton.isBordered = false
        pinButton.target = self
        pinButton.action = #selector(togglePin)
        pinButton.toolTip = "固定窗口"
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pinButton)

        // 表格视图
        setupTableView()

        // 状态标签
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // 布局约束
        setupConstraints()
    }

    private func setupFilterButton() {
        filterButton.bezelStyle = .inline
        filterButton.isBordered = false
        filterButton.pullsDown = false
        filterButton.target = self
        filterButton.action = #selector(filterChanged(_:))
        filterButton.translatesAutoresizingMaskIntoConstraints = false

        // 添加菜单项
        filterButton.removeAllItems()
        filterButton.addItem(withTitle: "全部")
        filterButton.menu?.addItem(NSMenuItem.separator())

        for type in ClipboardContentType.allCases {
            let item = NSMenuItem(title: type.displayName, action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: type.iconName, accessibilityDescription: nil)
            item.image?.size = NSSize(width: 14, height: 14)
            filterButton.menu?.addItem(item)
        }

        view.addSubview(filterButton)
    }

    private func setupTableView() {
        // 配置表格视图
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(tableViewDoubleClicked)
        tableView.target = self
        tableView.backgroundColor = .clear
        tableView.usesAutomaticRowHeights = false

        // 添加列（自动调整宽度）
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        // 让表格列宽跟随表格宽度
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.sizeLastColumnToFit()

        // 配置滚动视图
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 拖拽区域（增大热区方便拖拽）
            dragArea.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            dragArea.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragArea.widthAnchor.constraint(equalToConstant: 48),
            dragArea.heightAnchor.constraint(equalToConstant: 16),

            // 搜索框
            searchField.topAnchor.constraint(equalTo: dragArea.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(
                equalTo: filterButton.leadingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 24),

            // 过滤按钮（增加宽度以显示完整文本）
            filterButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            filterButton.trailingAnchor.constraint(
                equalTo: clearButton.leadingAnchor, constant: -4),
            filterButton.widthAnchor.constraint(equalToConstant: 72),

            // 清空按钮
            clearButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            clearButton.trailingAnchor.constraint(
                equalTo: pinButton.leadingAnchor, constant: -4),
            clearButton.widthAnchor.constraint(equalToConstant: 24),

            // 固定按钮
            pinButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            pinButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            pinButton.widthAnchor.constraint(equalToConstant: 24),

            // 列表
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            // 状态标签
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])
    }

    // MARK: - 数据绑定

    private func setupBindings() {
        // 监听剪贴板服务的变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardChange),
            name: NSNotification.Name("ClipboardItemsDidChange"),
            object: nil
        )
    }

    // MARK: - 加载数据

    private func loadSettings() {
        let settings = ClipboardSettings.load()
        clickMode = settings.clickMode
    }

    func loadItems() {
        items = ClipboardService.shared.items
        applyFilter()
    }

    func reloadData() {
        loadSettings()
        loadItems()
    }

    private func applyFilter() {
        let query = searchField.stringValue
        filteredItems = ClipboardService.shared.search(query: query, filter: selectedFilter)
        tableView.reloadData()
        updateStatusLabel()
    }

    private func updateStatusLabel() {
        let selected = tableView.selectedRowIndexes.count
        let total = filteredItems.count
        if selected > 0 {
            statusLabel.stringValue = "已选 \(selected) 项，总共 \(total) 项"
        } else {
            statusLabel.stringValue = "总共 \(total) 项"
        }
    }

    // MARK: - 公开方法

    func focus() {
        view.window?.makeFirstResponder(searchField)
    }

    func updatePinnedState(_ isPinned: Bool) {
        let iconName = isPinned ? "pin.fill" : "pin"
        pinButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "固定")
    }

    func getSelectedItems() -> [ClipboardItem] {
        return tableView.selectedRowIndexes.compactMap { index in
            guard index < filteredItems.count else { return nil }
            return filteredItems[index]
        }
    }

    // MARK: - 事件处理

    @objc private func filterChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        if index == 0 {
            selectedFilter = nil
        } else if index >= 2 {
            // 跳过分隔符
            let typeIndex = index - 2
            if typeIndex < ClipboardContentType.allCases.count {
                selectedFilter = ClipboardContentType.allCases[typeIndex]
            }
        }
        applyFilter()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "清空剪贴板历史"
        alert.informativeText = "确定要清空所有剪贴板历史吗？固定的项目不会被删除。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardService.shared.clearHistory()
        }
    }

    @objc private func togglePin() {
        ClipboardPanelManager.shared.togglePinned()
    }

    @objc private func handleClipboardChange() {
        loadItems()
    }

    @objc private func tableViewDoubleClicked() {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0, clickedRow < filteredItems.count else { return }

        let item = filteredItems[clickedRow]

        // 双击粘贴
        if clickMode == .doubleClick {
            ClipboardService.shared.paste(item)
            if !ClipboardPanelManager.shared.isPinned {
                ClipboardPanelManager.shared.hidePanel()
            }
        }
    }

    // MARK: - 键盘事件

    override func keyDown(with event: NSEvent) {
        // Enter 键粘贴
        if event.keyCode == 36 {
            // Return key
            if let selectedRow = tableView.selectedRowIndexes.first,
                selectedRow < filteredItems.count
            {
                let item = filteredItems[selectedRow]
                ClipboardService.shared.paste(item)
                if !ClipboardPanelManager.shared.isPinned {
                    ClipboardPanelManager.shared.hidePanel()
                }
            }
            return
        }

        // Escape 键关闭
        if event.keyCode == 53 {
            ClipboardPanelManager.shared.forceHidePanel()
            return
        }

        // Delete 键删除选中项
        if event.keyCode == 51 {
            let selectedItems = getSelectedItems()
            if !selectedItems.isEmpty {
                ClipboardService.shared.removeItems(selectedItems)
            }
            return
        }

        super.keyDown(with: event)
    }
}

// MARK: - NSTextFieldDelegate

extension ClipboardPanelViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension ClipboardPanelViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        guard row < filteredItems.count else { return nil }

        let item = filteredItems[row]

        // 创建或复用单元格
        let cellIdentifier = NSUserInterfaceItemIdentifier("ClipboardCell")
        var cell =
            tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? ClipboardCellView

        if cell == nil {
            cell = ClipboardCellView()
            cell?.identifier = cellIdentifier
        }

        cell?.configure(with: item)
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < filteredItems.count else { return rowHeight }

        let item = filteredItems[row]
        // 图片类型使用更大的高度
        if item.contentType == .image {
            return 80
        }
        return rowHeight
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateStatusLabel()

        // 单击模式下，选中即粘贴
        if clickMode == .singleClick {
            if let selectedRow = tableView.selectedRowIndexes.first,
                selectedRow < filteredItems.count
            {
                let item = filteredItems[selectedRow]
                ClipboardService.shared.paste(item)
                if !ClipboardPanelManager.shared.isPinned {
                    ClipboardPanelManager.shared.hidePanel()
                }
            }
        }
    }
}

// MARK: - 剪贴板单元格视图

class ClipboardCellView: NSTableCellView {

    private let iconView = NSImageView()
    private let titleLabel = NSTextField()
    private let subtitleLabel = NSTextField()
    private let pinIndicator = NSImageView()
    private let previewImageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // 图标
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // 标题
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // 副标题
        subtitleLabel.isEditable = false
        subtitleLabel.isBordered = false
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // 固定指示器
        pinIndicator.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "已固定")
        pinIndicator.contentTintColor = .systemOrange
        pinIndicator.translatesAutoresizingMaskIntoConstraints = false
        pinIndicator.isHidden = true
        addSubview(pinIndicator)

        // 图片预览
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 4
        previewImageView.layer?.masksToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.isHidden = true
        addSubview(previewImageView)

        // 布局
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: pinIndicator.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            pinIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pinIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinIndicator.widthAnchor.constraint(equalToConstant: 14),
            pinIndicator.heightAnchor.constraint(equalToConstant: 14),

            previewImageView.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor, constant: 10),
            previewImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            previewImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            previewImageView.widthAnchor.constraint(equalTo: previewImageView.heightAnchor),
        ])
    }

    func configure(with item: ClipboardItem) {
        // 重置状态
        previewImageView.isHidden = true
        titleLabel.isHidden = false
        subtitleLabel.isHidden = false
        iconView.isHidden = false

        // 固定指示器
        pinIndicator.isHidden = !item.isPinned

        // 根据类型配置
        switch item.contentType {
        case .image:
            // 图片类型显示预览
            if let data = item.imageData, let image = NSImage(data: data) {
                previewImageView.image = image
                previewImageView.isHidden = false
                titleLabel.isHidden = true
                iconView.isHidden = true
                subtitleLabel.stringValue = item.displaySubtitle
            } else {
                iconView.image = item.icon
                titleLabel.stringValue = item.displayTitle
                subtitleLabel.stringValue = item.displaySubtitle
            }

        case .color:
            // 颜色类型显示颜色块
            if let hex = item.colorHex, let color = NSColor(hex: hex) {
                let colorImage = NSImage(size: NSSize(width: 32, height: 32))
                colorImage.lockFocus()
                color.drawSwatch(in: NSRect(x: 0, y: 0, width: 32, height: 32))
                colorImage.unlockFocus()
                iconView.image = colorImage
            } else {
                iconView.image = item.icon
            }
            titleLabel.stringValue = item.displayTitle
            subtitleLabel.stringValue = item.displaySubtitle

        default:
            iconView.image = item.icon
            titleLabel.stringValue = item.displayTitle
            subtitleLabel.stringValue = item.displaySubtitle
        }
    }
}

// MARK: - 可拖拽视图（用于窗口拖拽）

class DraggableView: NSView {

    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero
    private let handleView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupHandle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHandle()
    }

    private func setupHandle() {
        // 小横杠视觉指示器
        handleView.wantsLayer = true
        handleView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        handleView.layer?.cornerRadius = 2
        handleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(handleView)

        NSLayoutConstraint.activate([
            handleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            handleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y

        let newOrigin = NSPoint(
            x: initialWindowOrigin.x + deltaX,
            y: initialWindowOrigin.y + deltaY
        )

        window.setFrameOrigin(newOrigin)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
}

// MARK: - 可调整大小的容器视图（处理左右边缘拖拽）

class ResizableContainerView: NSView {

    private let resizeEdgeWidth: CGFloat = 8
    private let panelMinWidth: CGFloat = 280
    private let panelMaxWidth: CGFloat = 600

    private var isResizing = false
    private var resizeEdge: ResizeEdge = .none
    private var initialFrame: NSRect = .zero
    private var initialMouseLocation: NSPoint = .zero

    enum ResizeEdge {
        case none, left, right
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // 移除旧的追踪区域
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        // 添加新的追踪区域
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if location.x < resizeEdgeWidth || location.x > bounds.width - resizeEdgeWidth {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if location.x < resizeEdgeWidth {
            resizeEdge = .left
            isResizing = true
        } else if location.x > bounds.width - resizeEdgeWidth {
            resizeEdge = .right
            isResizing = true
        } else {
            resizeEdge = .none
            isResizing = false
            super.mouseDown(with: event)
            return
        }

        if isResizing {
            initialFrame = window?.frame ?? .zero
            initialMouseLocation = NSEvent.mouseLocation
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isResizing, let window = window else {
            super.mouseDragged(with: event)
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - initialMouseLocation.x

        var newFrame = initialFrame

        switch resizeEdge {
        case .left:
            let newWidth = initialFrame.width - deltaX
            if newWidth >= panelMinWidth && newWidth <= panelMaxWidth {
                newFrame.origin.x = initialFrame.origin.x + deltaX
                newFrame.size.width = newWidth
            }
        case .right:
            let newWidth = initialFrame.width + deltaX
            if newWidth >= panelMinWidth && newWidth <= panelMaxWidth {
                newFrame.size.width = newWidth
            }
        case .none:
            break
        }

        window.setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            resizeEdge = .none

            // 保存新尺寸
            if let window = window {
                var settings = ClipboardSettings.load()
                settings.panelWidth = window.frame.width
                settings.panelHeight = window.frame.height
                settings.save()
            }

            NSCursor.arrow.set()
        } else {
            super.mouseUp(with: event)
        }
    }
}
