import Cocoa

// MARK: - 搜索框键盘导航代理协议

protocol ClipboardSearchFieldNavigationDelegate: AnyObject {
    func searchFieldDidPressUpArrow()
    func searchFieldDidPressDownArrow()
    func searchFieldDidPressReturn(withCommand: Bool)
    func searchFieldDidPressEscape()
    func searchFieldDidPressControlN()
    func searchFieldDidPressControlP()
}

// MARK: - 自定义搜索框（支持键盘导航）

class ClipboardSearchField: NSTextField {
    weak var navigationDelegate: ClipboardSearchFieldNavigationDelegate?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘+Return: 粘贴为纯文本
        if event.keyCode == 36 && flags.contains(.command) {
            navigationDelegate?.searchFieldDidPressReturn(withCommand: true)
            return true
        }

        // Ctrl+P: 向上移动
        if event.keyCode == 35 && flags.contains(.control) {
            navigationDelegate?.searchFieldDidPressControlP()
            return true
        }

        // Ctrl+N: 向下移动
        if event.keyCode == 45 && flags.contains(.control) {
            navigationDelegate?.searchFieldDidPressControlN()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}

/// 剪贴板面板视图控制器
class ClipboardPanelViewController: NSViewController {

    // MARK: - UI 组件

    private var searchField: ClipboardSearchField!
    private let filterButton = NSButton()
    private let filterMenu = NSMenu()
    private let clearButton = NSButton()
    private let pinButton = NSButton()
    private let dragArea = DraggableView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField()
    private let shortcutHintView = ShortcutHintView()

    // MARK: - 状态

    private var items: [ClipboardItem] = []
    private var filteredItems: [ClipboardItem] = []
    private var selectedFilter: ClipboardContentType? = nil
    private var selectedIndices: Set<Int> = []
    private var clickMode: ClipboardClickMode = .doubleClick

    // MARK: - 常量

    private let rowHeight: CGFloat = 44

    // MARK: - 生命周期

    override func loadView() {
        // 创建可调整大小的容器视图
        let containerView = ResizableContainerView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true

        // 创建毛玻璃效果视图
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
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

        // 搜索框（使用自定义子类支持键盘导航）
        searchField = ClipboardSearchField()
        searchField.placeholderString = "输入关键词搜索"
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 14)
        searchField.delegate = self
        searchField.navigationDelegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        // 过滤按钮（图标样式）
        setupFilterButton()

        // 清空按钮（扫把图标）
        clearButton.image = NSImage(
            systemSymbolName: "trash", accessibilityDescription: "清空")
        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.target = self
        clearButton.action = #selector(clearHistory)
        clearButton.toolTip = "清空剪贴板历史"
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clearButton)

        // 固定按钮
        pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "固定")
        pinButton.bezelStyle = .inline
        pinButton.isBordered = false
        pinButton.target = self
        pinButton.action = #selector(togglePin)
        pinButton.toolTip = "固定窗口"
        pinButton.contentTintColor = .secondaryLabelColor
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

        // 快捷键提示
        shortcutHintView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shortcutHintView)

        // 布局约束
        setupConstraints()
    }

    private func setupFilterButton() {
        // 使用普通按钮 + 菜单，避免下拉箭头
        filterButton.bezelStyle = .inline
        filterButton.isBordered = false
        filterButton.image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "过滤")
        filterButton.target = self
        filterButton.action = #selector(showFilterMenu)
        filterButton.contentTintColor = .secondaryLabelColor
        filterButton.translatesAutoresizingMaskIntoConstraints = false

        // 设置菜单
        let allItem = NSMenuItem(
            title: "全部", action: #selector(selectFilter(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.tag = -1
        allItem.state = .on
        filterMenu.addItem(allItem)

        filterMenu.addItem(NSMenuItem.separator())

        for (index, type) in ClipboardContentType.allCases.enumerated() {
            let item = NSMenuItem(
                title: type.displayName, action: #selector(selectFilter(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.image = NSImage(systemSymbolName: type.iconName, accessibilityDescription: nil)
            item.image?.size = NSSize(width: 14, height: 14)
            filterMenu.addItem(item)
        }

        view.addSubview(filterButton)
    }

    @objc private func showFilterMenu() {
        let buttonFrame = filterButton.convert(filterButton.bounds, to: nil)
        let screenPoint =
            view.window?.convertPoint(toScreen: NSPoint(x: buttonFrame.minX, y: buttonFrame.minY))
            ?? .zero
        filterMenu.popUp(positioning: nil, at: NSPoint(x: screenPoint.x, y: screenPoint.y), in: nil)
    }

    private func setupTableView() {
        // 配置表格视图
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = true
        tableView.action = #selector(tableViewClicked)
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

            // 过滤按钮（图标样式）
            filterButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            filterButton.trailingAnchor.constraint(
                equalTo: clearButton.leadingAnchor, constant: -4),
            filterButton.widthAnchor.constraint(equalToConstant: 32),

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

            // 快捷键提示
            shortcutHintView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            shortcutHintView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
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
        pinButton.contentTintColor = isPinned ? .systemBlue : .secondaryLabelColor
    }

    func getSelectedItems() -> [ClipboardItem] {
        return tableView.selectedRowIndexes.compactMap { index in
            guard index < filteredItems.count else { return nil }
            return filteredItems[index]
        }
    }

    // MARK: - 事件处理

    @objc private func selectFilter(_ sender: NSMenuItem) {
        // 更新菜单项状态
        for item in filterMenu.items {
            item.state = .off
        }
        sender.state = .on

        // 设置过滤器
        let tag = sender.tag
        if tag == -1 {
            selectedFilter = nil
            filterButton.contentTintColor = .secondaryLabelColor
        } else if tag >= 0 && tag < ClipboardContentType.allCases.count {
            selectedFilter = ClipboardContentType.allCases[tag]
            filterButton.contentTintColor = .systemBlue
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

    @objc private func tableViewClicked() {
        // 单击模式下，点击即粘贴
        if clickMode == .singleClick {
            let clickedRow = tableView.clickedRow
            guard clickedRow >= 0, clickedRow < filteredItems.count else { return }
            let item = filteredItems[clickedRow]
            pasteItem(item)
        }
    }

    @objc private func tableViewDoubleClicked() {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0, clickedRow < filteredItems.count else { return }

        let item = filteredItems[clickedRow]

        // 双击粘贴
        if clickMode == .doubleClick {
            pasteItem(item)
        }
    }

    // MARK: - 键盘事件

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘+Return: 粘贴为纯文本
        if event.keyCode == 36 && flags.contains(.command) {
            if let selectedRow = tableView.selectedRowIndexes.first,
                selectedRow < filteredItems.count
            {
                let item = filteredItems[selectedRow]
                pasteItemAsPlainText(item)
            }
            return
        }

        // Return: 粘贴原始格式
        if event.keyCode == 36 {
            if let selectedRow = tableView.selectedRowIndexes.first,
                selectedRow < filteredItems.count
            {
                let item = filteredItems[selectedRow]
                pasteItem(item)
            }
            return
        }

        // Escape: 关闭面板
        if event.keyCode == 53 {
            ClipboardPanelManager.shared.forceHidePanel()
            return
        }

        // Delete: 删除选中项
        if event.keyCode == 51 {
            let selectedItems = getSelectedItems()
            if !selectedItems.isEmpty {
                ClipboardService.shared.removeItems(selectedItems)
            }
            return
        }

        // 上箭头 或 Ctrl+P: 向上移动
        if event.keyCode == 126 || (event.keyCode == 35 && flags.contains(.control)) {
            moveSelection(by: -1)
            return
        }

        // 下箭头 或 Ctrl+N: 向下移动
        if event.keyCode == 125 || (event.keyCode == 45 && flags.contains(.control)) {
            moveSelection(by: 1)
            return
        }

        super.keyDown(with: event)
    }

    private func moveSelection(by delta: Int) {
        guard !filteredItems.isEmpty else { return }

        let currentIndex = tableView.selectedRow
        var newIndex: Int

        if currentIndex == -1 {
            // 没有选中项，选择第一项或最后一项
            newIndex = delta > 0 ? 0 : filteredItems.count - 1
        } else {
            newIndex = currentIndex + delta
            // 边界处理
            if newIndex < 0 {
                newIndex = 0
            } else if newIndex >= filteredItems.count {
                newIndex = filteredItems.count - 1
            }
        }

        tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        scrollToKeepSelectionCentered()
    }

    /// 滚动使选中行保持在中间位置（参考主搜索列表实现）
    private func scrollToKeepSelectionCentered() {
        let visibleRect = scrollView.contentView.bounds
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        // 计算可视区域能显示多少行
        let visibleRows = Int(visibleRect.height / rowHeight)
        let middleOffset = visibleRows / 2

        // 计算目标滚动位置，使选中行在中间
        let targetRow = max(0, selectedRow - middleOffset)
        let targetRect = tableView.rect(ofRow: targetRow)

        // 如果选中行在前几行，不需要居中（保持在顶部）
        if selectedRow < middleOffset {
            tableView.scrollRowToVisible(0)
        }
        // 如果选中行在最后几行，不需要居中（保持在底部）
        else if selectedRow >= filteredItems.count - middleOffset {
            tableView.scrollRowToVisible(filteredItems.count - 1)
        }
        // 否则滚动使选中行居中
        else {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetRect.origin.y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    // MARK: - 粘贴功能

    /// 粘贴项目（保持原始格式）
    private func pasteItem(_ item: ClipboardItem) {
        // 先写入剪贴板
        ClipboardService.shared.copyToClipboard(item)

        // 隐藏面板并激活之前的应用
        if !ClipboardPanelManager.shared.isPinned {
            ClipboardPanelManager.shared.hidePanelAndActivatePreviousApp()
        }

        // 延迟执行粘贴，等待目标窗口获得焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performPaste()
        }
    }

    /// 粘贴项目为纯文本
    private func pasteItemAsPlainText(_ item: ClipboardItem) {
        // 先写入剪贴板（纯文本）
        ClipboardService.shared.copyAsPlainText(item)

        // 隐藏面板并激活之前的应用
        if !ClipboardPanelManager.shared.isPinned {
            ClipboardPanelManager.shared.hidePanelAndActivatePreviousApp()
        }

        // 延迟执行粘贴，等待目标窗口获得焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performPaste()
        }
    }

    /// 执行粘贴操作
    private func performPaste() {
        // 使用 AppleScript 来执行粘贴，更可靠
        let script = """
            tell application "System Events"
                keystroke "v" using command down
            end tell
            """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("[ClipboardService] AppleScript error: \(error)")
                // 如果 AppleScript 失败，尝试使用 CGEvent
                ClipboardService.shared.simulatePasteCommand()
            }
        }
    }
}

// MARK: - NSTextFieldDelegate

extension ClipboardPanelViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    // 处理搜索框中的特殊按键
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        // Escape: 关闭面板
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            ClipboardPanelManager.shared.forceHidePanel()
            return true
        }

        // 上箭头: 向上移动
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            moveSelection(by: -1)
            return true
        }

        // 下箭头: 向下移动
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            moveSelection(by: 1)
            return true
        }

        // Return: 粘贴
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let selectedRow = tableView.selectedRowIndexes.first,
                selectedRow < filteredItems.count
            {
                let item = filteredItems[selectedRow]
                pasteItem(item)
                return true
            }
        }

        return false
    }
}

// MARK: - ClipboardSearchFieldNavigationDelegate

extension ClipboardPanelViewController: ClipboardSearchFieldNavigationDelegate {
    func searchFieldDidPressUpArrow() {
        moveSelection(by: -1)
    }

    func searchFieldDidPressDownArrow() {
        moveSelection(by: 1)
    }

    func searchFieldDidPressControlP() {
        moveSelection(by: -1)
    }

    func searchFieldDidPressControlN() {
        moveSelection(by: 1)
    }

    func searchFieldDidPressReturn(withCommand: Bool) {
        guard let selectedRow = tableView.selectedRowIndexes.first,
            selectedRow < filteredItems.count
        else { return }

        let item = filteredItems[selectedRow]

        if withCommand {
            pasteItemAsPlainText(item)
        } else {
            pasteItem(item)
        }
    }

    func searchFieldDidPressEscape() {
        ClipboardPanelManager.shared.forceHidePanel()
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

        // 文本类型根据内容行数计算高度
        if item.contentType == .text || item.contentType == .link {
            if let text = item.textContent {
                let lineCount = min(text.components(separatedBy: .newlines).count, 4)
                if lineCount > 1 {
                    // 每行约 17pt (13pt 字体 + 行间距)，上下各 8pt padding
                    let height = CGFloat(lineCount) * 17 + 16
                    return max(rowHeight, height)
                }
            }
        }

        return rowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        // 使用自定义 rowView，始终保持蓝色高亮（即使窗口不是 key window）
        let rowView = EmphasizedTableRowView()
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateStatusLabel()

        // 注意：单击模式的粘贴由 tableView 的 action 处理，而不是 selectionDidChange
        // 这样可以避免键盘导航时意外触发粘贴
    }
}

// MARK: - 剪贴板单元格视图

class ClipboardCellView: NSTableCellView {

    private let appIconView = NSImageView()  // 来源App图标
    private let contentLabel = NSTextField()  // 内容文字
    private let colorCircleView = NSView()  // 颜色圆形显示
    private let pinIndicator = NSImageView()
    private let previewImageView = NSImageView()  // 图片预览

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // 来源App图标
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appIconView)

        // 内容文字
        contentLabel.isEditable = false
        contentLabel.isBordered = false
        contentLabel.backgroundColor = .clear
        contentLabel.font = .systemFont(ofSize: 13)
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.maximumNumberOfLines = 4
        contentLabel.cell?.wraps = true
        contentLabel.cell?.truncatesLastVisibleLine = true
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)

        // 颜色圆形（用于颜色类型）
        colorCircleView.wantsLayer = true
        colorCircleView.layer?.cornerRadius = 12  // 24/2
        colorCircleView.layer?.borderColor = NSColor.white.cgColor
        colorCircleView.layer?.borderWidth = 2
        colorCircleView.layer?.masksToBounds = true
        colorCircleView.translatesAutoresizingMaskIntoConstraints = false
        colorCircleView.isHidden = true
        addSubview(colorCircleView)

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
            // App图标（左侧）
            appIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            appIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 28),
            appIconView.heightAnchor.constraint(equalToConstant: 28),

            // 内容文字（垂直方向用 top/bottom 约束，允许多行扩展）
            contentLabel.leadingAnchor.constraint(
                equalTo: appIconView.trailingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(
                equalTo: pinIndicator.leadingAnchor, constant: -8),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),

            // 颜色圆形（替代App图标位置）
            colorCircleView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            colorCircleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorCircleView.widthAnchor.constraint(equalToConstant: 24),
            colorCircleView.heightAnchor.constraint(equalToConstant: 24),

            // 固定指示器（右侧）
            pinIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pinIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinIndicator.widthAnchor.constraint(equalToConstant: 14),
            pinIndicator.heightAnchor.constraint(equalToConstant: 14),

            // 图片预览
            previewImageView.leadingAnchor.constraint(
                equalTo: appIconView.trailingAnchor, constant: 10),
            previewImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            previewImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            previewImageView.widthAnchor.constraint(equalTo: previewImageView.heightAnchor),
        ])
    }

    func configure(with item: ClipboardItem) {
        // 重置状态
        previewImageView.isHidden = true
        contentLabel.isHidden = false
        appIconView.isHidden = false
        colorCircleView.isHidden = true

        // 固定指示器
        pinIndicator.isHidden = !item.isPinned

        // 设置来源App图标
        if let bundleId = item.sourceAppBundleId,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        {
            appIconView.image = NSWorkspace.shared.icon(forFile: appURL.path)
        } else {
            appIconView.image = item.icon
        }

        // 根据类型配置
        switch item.contentType {
        case .image:
            // 图片类型显示预览
            if let data = item.imageData, let image = NSImage(data: data) {
                previewImageView.image = image
                previewImageView.isHidden = false
                contentLabel.isHidden = true
            } else {
                contentLabel.stringValue = "图片"
            }

        case .color:
            // 颜色类型显示圆形颜色块
            if let hex = item.colorHex, let color = NSColor(hex: hex) {
                colorCircleView.layer?.backgroundColor = color.cgColor
                colorCircleView.isHidden = false
                appIconView.isHidden = true
                contentLabel.stringValue = hex.uppercased()
            } else {
                contentLabel.stringValue = item.displayTitle
            }

        case .text, .link:
            contentLabel.stringValue = item.textContent ?? ""

        case .file:
            if let paths = item.filePaths, let firstPath = paths.first {
                let fileName = (firstPath as NSString).lastPathComponent
                if paths.count > 1 {
                    contentLabel.stringValue = "\(fileName) 等 \(paths.count) 个文件"
                } else {
                    contentLabel.stringValue = fileName
                }
            } else {
                contentLabel.stringValue = item.displayTitle
            }
        }
    }
}

// MARK: - 自定义 TableRowView（始终保持蓝色高亮）

class EmphasizedTableRowView: NSTableRowView {
    // 重写 isEmphasized 属性，始终返回 true
    // 这样即使窗口不是 key window，选中高亮也会保持蓝色
    override var isEmphasized: Bool {
        get { return true }
        set {}
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
}

// MARK: - 可调整大小的容器视图（处理左右边缘拖拽）

class ResizableContainerView: NSView {

    private let resizeEdgeWidth: CGFloat = 10
    private let panelMinWidth: CGFloat = 430
    private let panelMaxWidth: CGFloat = 800

    private var isResizing = false
    private var resizeEdge: ResizeEdge = .none
    private var initialFrame: NSRect = .zero
    private var initialMouseLocation: NSPoint = .zero

    enum ResizeEdge {
        case none, left, right
    }

    // 重写 hitTest 让边缘区域的事件由自己处理
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 如果不在窗口内，不处理
        guard let window = window else { return super.hitTest(point) }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let localPoint = convert(windowPoint, from: nil)

        // 检查是否在视图范围内
        guard bounds.contains(localPoint) else { return nil }

        // 如果在左右边缘，返回自己来处理事件
        if localPoint.x < resizeEdgeWidth || localPoint.x > bounds.width - resizeEdgeWidth {
            return self
        }

        // 否则正常传递给子视图
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // 移除旧的追踪区域
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        // 左边缘追踪区域
        let leftEdgeRect = NSRect(x: 0, y: 0, width: resizeEdgeWidth, height: bounds.height)
        let leftOptions: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .activeAlways, .cursorUpdate,
        ]
        let leftTrackingArea = NSTrackingArea(
            rect: leftEdgeRect, options: leftOptions, owner: self, userInfo: ["edge": "left"])
        addTrackingArea(leftTrackingArea)

        // 右边缘追踪区域
        let rightEdgeRect = NSRect(
            x: bounds.width - resizeEdgeWidth, y: 0, width: resizeEdgeWidth, height: bounds.height)
        let rightTrackingArea = NSTrackingArea(
            rect: rightEdgeRect, options: leftOptions, owner: self, userInfo: ["edge": "right"])
        addTrackingArea(rightTrackingArea)
    }

    override func cursorUpdate(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if location.x < resizeEdgeWidth || location.x > bounds.width - resizeEdgeWidth {
            NSCursor.resizeLeftRight.set()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        if !isResizing {
            NSCursor.arrow.set()
        }
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
            var newWidth = initialFrame.width - deltaX
            // 限制在边界内
            newWidth = max(panelMinWidth, min(panelMaxWidth, newWidth))
            let actualDelta = initialFrame.width - newWidth
            newFrame.origin.x = initialFrame.origin.x + actualDelta
            newFrame.size.width = newWidth
        case .right:
            var newWidth = initialFrame.width + deltaX
            // 限制在边界内
            newWidth = max(panelMinWidth, min(panelMaxWidth, newWidth))
            newFrame.size.width = newWidth
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

// MARK: - 快捷键提示视图

class ShortcutHintView: NSView {

    private let stackView = NSStackView()
    private let keySize: CGFloat = 16

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // 改为水平布局，一行显示
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        // 粘贴选中行: ↵
        let pasteHint = createHintGroup(text: "粘贴", keys: ["↵"])
        stackView.addArrangedSubview(pasteHint)

        // 粘贴为纯文本: ⌘ ↵
        let plainTextHint = createHintGroup(text: "纯文本", keys: ["⌘", "↵"])
        stackView.addArrangedSubview(plainTextHint)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func createHintGroup(text: String, keys: [String]) -> NSView {
        let groupStack = NSStackView()
        groupStack.orientation = .horizontal
        groupStack.spacing = 3
        groupStack.alignment = .centerY

        // 文字标签
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10)
        label.textColor = .tertiaryLabelColor
        groupStack.addArrangedSubview(label)

        // 按键图标
        for key in keys {
            let keyView = createKeyView(key)
            groupStack.addArrangedSubview(keyView)
        }

        return groupStack
    }

    private func createKeyView(_ key: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        container.layer?.cornerRadius = 3

        let label = NSTextField(labelWithString: key)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: keySize),
            container.heightAnchor.constraint(equalToConstant: keySize),
        ])

        return container
    }
}
