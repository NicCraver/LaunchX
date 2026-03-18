import Cocoa

import Cocoa

// MARK: - 搜索框键盘导航代理协议

protocol ClipboardSearchFieldNavigationDelegate: AnyObject {
    func searchFieldDidPressUpArrow()
    func searchFieldDidPressDownArrow()
    func searchFieldDidPressReturn(withCommand: Bool)
    func searchFieldDidPressEscape()
    func searchFieldDidPressControlN()
    func searchFieldDidPressControlP()
    func searchFieldDidSelectFilter(at index: Int)
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

        // ⌘+0...5: 筛选快捷键
        if flags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers, let char = chars.first {
                if char >= "0" && char <= "5" {
                    let index = Int(String(char)) ?? 0
                    navigationDelegate?.searchFieldDidSelectFilter(at: index)
                    return true
                }
            }
        }

        return super.performKeyEquivalent(with: event)
    }
}

/// 剪贴板面板视图控制器
class ClipboardPanelViewController: NSViewController {

    // MARK: - UI 组件

    var searchField: ClipboardSearchField!
    var visualEffectView: NSVisualEffectView?
    var glassEffectView: NSView?
    let filterButton = NSButton()
    let filterMenu = NSMenu()
    let clearButton = NSButton()
    let pinButton = NSButton()
    let dragArea = DraggableView()
    let tableView = NSTableView()
    let scrollView = NSScrollView()
    let statusLabel = NSTextField()
    let shortcutHintView = ShortcutHintView()

    // MARK: - 状态

    var items: [ClipboardItem] = []
    var filteredItems: [ClipboardItem] = []
    var selectedFilter: ClipboardContentType? = nil
    var selectedIndices: Set<Int> = []
    var clickMode: ClipboardClickMode = .doubleClick

    // MARK: - 常量

    let rowHeight: CGFloat = 44

    // MARK: - 生命周期

    override func loadView() {
        // 创建可调整大小的容器视图
        let containerView = ResizableContainerView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 28
        containerView.layer?.cornerCurve = .continuous
        containerView.layer?.masksToBounds = true

        // 1. 创建传统毛玻璃层
        let vev = NSVisualEffectView()
        vev.material = .hudWindow
        vev.blendingMode = .behindWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = 28
        vev.layer?.cornerCurve = .continuous
        vev.layer?.masksToBounds = true
        vev.layer?.borderWidth = 0
        vev.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(vev)
        self.visualEffectView = vev

        // 2. 在 macOS 26+ 上预创建液态玻璃层
        if #available(macOS 26.0, *) {
            let gev = NSGlassEffectView()
            gev.style = .clear
            gev.tintColor = NSColor(named: "PanelBackgroundColor")
            gev.wantsLayer = true
            gev.layer?.cornerRadius = 28
            gev.layer?.cornerCurve = .continuous
            gev.layer?.masksToBounds = true
            gev.layer?.borderWidth = 0
            gev.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(gev)
            self.glassEffectView = gev

            NSLayoutConstraint.activate([
                gev.topAnchor.constraint(equalTo: containerView.topAnchor),
                gev.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                gev.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                gev.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            vev.topAnchor.constraint(equalTo: containerView.topAnchor),
            vev.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            vev.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            vev.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        self.view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        loadSettings()
        loadItems()

        // 初始同步状态
        handleLiquidGlassSettingDidChange()

        // 监听液态玻璃设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiquidGlassSettingDidChange),
            name: NSNotification.Name("enableLiquidGlassDidChange"),
            object: nil
        )
    }

    /// 处理液态玻璃设置变化
    @objc func handleLiquidGlassSettingDidChange() {
        let useLiquidGlass =
            UserDefaults.standard.object(forKey: "enableLiquidGlass") as? Bool ?? true

        if #available(macOS 26.0, *) {
            glassEffectView?.isHidden = !useLiquidGlass
            visualEffectView?.isHidden = useLiquidGlass
            if !useLiquidGlass {
                visualEffectView?.material = .hudWindow
            }
        } else {
            // 旧版本系统：仅使用 VisualEffectView，通过切换材质模拟
            glassEffectView?.isHidden = true
            visualEffectView?.isHidden = false
            visualEffectView?.material = .hudWindow
        }
    }

    deinit {
        // 移除所有通知观察者
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 设置

    func setupUI() {
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

    func setupFilterButton() {
        // 使用普通按钮 + 菜单，避免下拉箭头
        filterButton.bezelStyle = .inline
        filterButton.isBordered = false
        filterButton.image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "过滤")
        filterButton.target = self
        filterButton.action = #selector(showFilterMenu)
        filterButton.contentTintColor = .secondaryLabelColor
        filterButton.toolTip = "内容过滤 (⌘0-⌘5)"
        filterButton.translatesAutoresizingMaskIntoConstraints = false

        // 设置菜单
        let allItem = NSMenuItem(
            title: "全部", action: #selector(selectFilter(_:)), keyEquivalent: "0")
        allItem.keyEquivalentModifierMask = .command
        allItem.target = self
        allItem.tag = -1
        allItem.state = .on
        // 添加图标使整体更协调
        allItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        allItem.image?.size = NSSize(width: 14, height: 14)
        filterMenu.addItem(allItem)

        for (index, type) in ClipboardContentType.allCases.enumerated() {
            let item = NSMenuItem(
                title: type.displayName, action: #selector(selectFilter(_:)),
                keyEquivalent: "\(index + 1)")
            item.keyEquivalentModifierMask = .command
            item.target = self
            item.tag = index
            item.image = NSImage(systemSymbolName: type.iconName, accessibilityDescription: nil)
            item.image?.size = NSSize(width: 14, height: 14)
            filterMenu.addItem(item)
        }

        view.addSubview(filterButton)
    }

    @objc func showFilterMenu() {
        // 在按钮下方弹出菜单，指定 in: filterButton 确保菜单在正确的层级显示
        let point = NSPoint(x: 0, y: filterButton.bounds.height + 4)
        filterMenu.popUp(positioning: nil, at: point, in: filterButton)
    }

    func setupTableView() {
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

    func setupConstraints() {
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

    func setupBindings() {
        // 监听剪贴板服务的变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardChange),
            name: NSNotification.Name("ClipboardItemsDidChange"),
            object: nil
        )
    }

    // MARK: - 加载数据

    func loadSettings() {
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

    func applyFilter() {
        let query = searchField.stringValue
        filteredItems = ClipboardService.shared.search(query: query, filter: selectedFilter)
        tableView.reloadData()
        updateStatusLabel()
    }

    func updateStatusLabel() {
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

    @objc func selectFilter(_ sender: NSMenuItem) {
        let tag = sender.tag
        let newFilter: ClipboardContentType? = (tag == -1) ? nil : ClipboardContentType.allCases[tag]

        // 如果点击的是当前已选中的过滤器（非“全部”），则切换回“全部”
        if tag != -1 && selectedFilter == newFilter {
            if let allItem = filterMenu.items.first(where: { $0.tag == -1 }) {
                selectFilter(allItem)
                return
            }
        }

        // 更新菜单项状态
        for item in filterMenu.items {
            item.state = .off
        }
        sender.state = .on

        // 设置过滤器
        if tag == -1 {
            selectedFilter = nil
            filterButton.contentTintColor = .secondaryLabelColor
            filterButton.image = NSImage(
                systemSymbolName: "line.3.horizontal.decrease.circle",
                accessibilityDescription: "过滤")
        } else if tag >= 0 && tag < ClipboardContentType.allCases.count {
            selectedFilter = newFilter
            filterButton.contentTintColor = .systemBlue
            // 选中分类时，按钮图标同步切换为该分类图标，更直观且节省空间
            if let selectedFilter = selectedFilter {
                filterButton.image = NSImage(
                    systemSymbolName: selectedFilter.iconName,
                    accessibilityDescription: selectedFilter.displayName)
            }
        }

        applyFilter()
    }

    @objc func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "清空剪贴板历史"
        alert.informativeText = "确定要清空所有剪贴板历史吗？固定的项目不会被删除。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardService.shared.clearHistory()
        }
    }

    @objc func togglePin() {
        ClipboardPanelManager.shared.togglePinned()
    }

    @objc func handleClipboardChange() {
        loadItems()
    }

    @objc func tableViewClicked() {
        // 单击模式下，点击即粘贴
        if clickMode == .singleClick {
            let clickedRow = tableView.clickedRow
            guard clickedRow >= 0, clickedRow < filteredItems.count else { return }
            let item = filteredItems[clickedRow]
            pasteItem(item)
        }
    }

    @objc func tableViewDoubleClicked() {
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

        // ⌘+0...5: 筛选快捷键
        if flags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers, let char = chars.first {
                if char >= "0" && char <= "5" {
                    let index = Int(String(char)) ?? 0
                    searchFieldDidSelectFilter(at: index)
                    return
                }
            }
        }

        super.keyDown(with: event)
    }

    func moveSelection(by delta: Int) {
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
    func scrollToKeepSelectionCentered() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        let visibleRect = scrollView.contentView.bounds
        let selectedRect = tableView.rect(ofRow: selectedRow)

        // 计算目标滚动位置，使选中行在中间
        // targetY = 选中行中心点 - 可视区域高度的一半
        let targetY = selectedRect.midY - (visibleRect.height / 2)

        // 边界处理：确保不会滚动超出范围
        let maxY = max(0, tableView.frame.height - visibleRect.height)
        let clampedY = max(0, min(targetY, maxY))

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - 粘贴功能

    /// 粘贴项目（保持原始格式）
    func pasteItem(_ item: ClipboardItem) {
        // 先写入剪贴板
        ClipboardService.shared.copyToClipboard(item)

        // 隐藏面板并激活之前的应用
        if !ClipboardPanelManager.shared.isPinned {
            ClipboardPanelManager.shared.hidePanelAndActivatePreviousApp()
        }

        // 延迟执行粘贴，等待目标窗口获得焦点
        // 增加延迟时间确保窗口完全激活
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.performPaste()
        }
    }

    /// 粘贴项目为纯文本
    func pasteItemAsPlainText(_ item: ClipboardItem) {
        // 先写入剪贴板（纯文本）
        ClipboardService.shared.copyAsPlainText(item)

        // 隐藏面板并激活之前的应用
        if !ClipboardPanelManager.shared.isPinned {
            ClipboardPanelManager.shared.hidePanelAndActivatePreviousApp()
        }

        // 延迟执行粘贴，等待目标窗口获得焦点
        // 增加延迟时间确保窗口完全激活
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.performPaste()
        }
    }

    /// 执行粘贴操作
    func performPaste() {
        // 使用 CGEvent 直接发送按键事件，更可靠
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key down: Cmd + V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        // Key up: Cmd + V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)
    }
}

