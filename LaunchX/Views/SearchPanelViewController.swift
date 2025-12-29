import Cocoa

/// Pure AppKit implementation of the search panel - no SwiftUI overhead
class SearchPanelViewController: NSViewController {

    // MARK: - UI Components
    private let searchField = NSTextField()
    private let searchIcon = NSImageView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let divider = NSBox()
    private let noResultsLabel = NSTextField(labelWithString: "No results found.")

    // IDE 项目模式 UI
    private let ideTagView = NSView()
    private let ideIconView = NSImageView()
    private let ideNameLabel = NSTextField(labelWithString: "")

    // MARK: - State
    private var results: [SearchResult] = []
    private var recentApps: [SearchResult] = []  // 最近使用的应用
    private var selectedIndex: Int = 0
    private let searchEngine = SearchEngine.shared
    private var isShowingRecents: Bool = false  // 是否正在显示最近使用

    // IDE 项目模式状态
    private var isInIDEProjectMode: Bool = false
    private var currentIDEApp: SearchResult? = nil
    private var currentIDEType: IDEType? = nil
    private var ideProjects: [IDEProject] = []
    private var filteredIDEProjects: [IDEProject] = []

    // 文件夹打开方式选择模式状态
    private var isInFolderOpenMode: Bool = false
    private var currentFolder: SearchResult? = nil
    private var folderOpeners: [IDERecentProjectsService.FolderOpenerApp] = []

    // 网页直达 Query 模式状态
    private var isInWebLinkQueryMode: Bool = false
    private var currentWebLinkResult: SearchResult? = nil

    // 实用工具模式状态
    private var isInUtilityMode: Bool = false
    private var currentUtilityIdentifier: String? = nil
    private var currentUtilityResult: SearchResult? = nil

    // IP 查询结果
    private var ipQueryResults: [(label: String, ip: String)] = []

    // Kill 进程模式数据
    private var killModeApps: [RunningProcessInfo] = []  // 已打开应用
    private var killModePorts: [RunningProcessInfo] = []  // 监听端口进程
    private var killModeAllItems: [RunningProcessInfo] = []  // 合并列表（用于显示）
    private var killModeFilteredItems: [RunningProcessInfo] = []  // 搜索过滤后的列表

    // MARK: - Constants
    private let rowHeight: CGFloat = 44
    private let headerHeight: CGFloat = 80

    // Placeholder 样式
    private func setPlaceholder(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 22, weight: .light),
        ]
        searchField.placeholderAttributedString = NSAttributedString(
            string: text, attributes: attributes)
    }

    // 用于 IDE 模式切换的约束
    private var searchFieldLeadingToIcon: NSLayoutConstraint?
    private var searchFieldLeadingToTag: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func loadView() {
        // macOS 26+ 使用 Liquid Glass 效果
        if #available(macOS 26.0, *) {
            let glassEffectView = NSGlassEffectView()
            glassEffectView.style = .clear
            glassEffectView.tintColor = NSColor(named: "PanelBackgroundColor")
            glassEffectView.wantsLayer = true
            glassEffectView.layer?.cornerRadius = 26
            glassEffectView.layer?.masksToBounds = true
            self.view = glassEffectView
            return
        }

        // macOS 26 以下使用传统的 NSVisualEffectView
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 26
        visualEffectView.layer?.masksToBounds = true

        self.view = visualEffectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("SearchPanelViewController: viewDidLoad called")
        setupUI()
        setupKeyboardMonitor()
        setupNotificationObservers()

        // SearchEngine handles indexing automatically on init
        // Just trigger a reference to ensure it starts
        _ = searchEngine.isReady

        // 加载最近使用的应用
        loadRecentApps()

        // Register for panel show callback to refresh recent apps
        PanelManager.shared.onWillShow = { [weak self] in
            self?.loadRecentApps()
        }

        // Register for panel hide callback
        PanelManager.shared.onWillHide = { [weak self] in
            self?.resetState()
        }
    }

    /// 设置通知观察者
    private func setupNotificationObservers() {
        // 监听直接进入 IDE 模式的通知（由快捷键触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterIDEModeDirectly(_:)),
            name: .enterIDEModeDirectly,
            object: nil
        )

        // 监听直接进入网页直达 Query 模式的通知（由快捷键触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterWebLinkQueryModeDirectly(_:)),
            name: .enterWebLinkQueryModeDirectly,
            object: nil
        )

        // 监听直接进入实用工具模式的通知（由快捷键触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterUtilityModeDirectly(_:)),
            name: .enterUtilityModeDirectly,
            object: nil
        )

        // 监听工具配置变化，刷新默认搜索缓存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToolsConfigDidChange),
            name: .toolsConfigDidChange,
            object: nil
        )
    }

    /// 处理工具配置变化
    @objc private func handleToolsConfigDidChange() {
        refreshDefaultSearchWebLinksCache()
    }

    /// 处理直接进入 IDE 模式的通知
    @objc private func handleEnterIDEModeDirectly(_ notification: Notification) {
        print("SearchPanelViewController: handleEnterIDEModeDirectly called")

        guard let userInfo = notification.userInfo,
            let idePath = userInfo["path"] as? String,
            let ideType = userInfo["ideType"] as? IDEType
        else {
            print("SearchPanelViewController: Invalid notification userInfo")
            return
        }

        print("SearchPanelViewController: IDE path=\(idePath), type=\(ideType)")

        // 获取该 IDE 的最近项目
        let projects = IDERecentProjectsService.shared.getRecentProjects(for: ideType, limit: 20)
        print("SearchPanelViewController: Got \(projects.count) projects")

        guard !projects.isEmpty else {
            print("SearchPanelViewController: No projects found, returning")
            return
        }

        // 创建一个虚拟的 SearchResult 来表示 IDE 应用
        let icon = NSWorkspace.shared.icon(forFile: idePath)
        icon.size = NSSize(width: 32, height: 32)
        let name = FileManager.default.displayName(atPath: idePath)
            .replacingOccurrences(of: ".app", with: "")

        let ideApp = SearchResult(
            name: name,
            path: idePath,
            icon: icon,
            isDirectory: true
        )

        // 进入 IDE 项目模式
        isInIDEProjectMode = true
        currentIDEApp = ideApp
        currentIDEType = ideType
        ideProjects = projects
        filteredIDEProjects = projects

        // 更新 UI
        updateIDEModeUI()

        // 显示项目列表
        results = projects.map { $0.toSearchResult() }
        selectedIndex = 0
        searchField.stringValue = ""
        setPlaceholder("搜索项目...")
        tableView.reloadData()
        updateVisibility()

        print("SearchPanelViewController: IDE mode setup complete, results count=\(results.count)")
    }

    /// 处理直接进入网页直达 Query 模式的通知
    @objc private func handleEnterWebLinkQueryModeDirectly(_ notification: Notification) {
        print("SearchPanelViewController: handleEnterWebLinkQueryModeDirectly called")

        guard let userInfo = notification.userInfo,
            let tool = userInfo["tool"] as? ToolItem
        else {
            print("SearchPanelViewController: Invalid notification userInfo for WebLink query mode")
            return
        }

        print("SearchPanelViewController: WebLink tool=\(tool.name)")

        // 创建一个 SearchResult 来表示网页直达
        var icon: NSImage
        if let iconData = tool.iconData, let customIcon = NSImage(data: iconData) {
            customIcon.size = NSSize(width: 32, height: 32)
            icon = customIcon
        } else {
            icon =
                NSImage(systemSymbolName: "globe", accessibilityDescription: "Web Link")
                ?? NSImage()
            icon.size = NSSize(width: 32, height: 32)
        }

        let webLinkResult = SearchResult(
            name: tool.name,
            path: tool.url ?? "",
            icon: icon,
            isDirectory: false,
            isWebLink: true,
            supportsQueryExtension: true,
            defaultUrl: tool.defaultUrl
        )

        // 进入网页直达 Query 模式
        isInWebLinkQueryMode = true
        currentWebLinkResult = webLinkResult

        // 更新 UI
        updateWebLinkQueryModeUI()

        // 清空结果列表
        results = []
        selectedIndex = 0
        searchField.stringValue = ""
        setPlaceholder("请输入关键词搜索...")
        tableView.reloadData()
        updateVisibility()

        print("SearchPanelViewController: WebLink query mode setup complete")
    }

    /// 处理直接进入实用工具模式的通知
    @objc private func handleEnterUtilityModeDirectly(_ notification: Notification) {
        print("SearchPanelViewController: handleEnterUtilityModeDirectly called")

        guard let userInfo = notification.userInfo,
            let tool = userInfo["tool"] as? ToolItem
        else {
            print("SearchPanelViewController: Invalid notification userInfo for Utility mode")
            return
        }

        // 如果已经在同一个实用工具的扩展模式中，忽略重复触发
        if isInUtilityMode && currentUtilityIdentifier == tool.extensionIdentifier {
            print(
                "SearchPanelViewController: Already in utility mode for \(tool.extensionIdentifier ?? "nil"), ignoring"
            )
            return
        }

        print(
            "SearchPanelViewController: Utility tool=\(tool.name), identifier=\(tool.extensionIdentifier ?? "nil")"
        )

        // 创建一个 SearchResult 来表示实用工具
        var icon: NSImage
        if let iconData = tool.iconData, let customIcon = NSImage(data: iconData) {
            customIcon.size = NSSize(width: 32, height: 32)
            icon = customIcon
        } else {
            icon =
                NSImage(
                    systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "Utility")
                ?? NSImage()
            icon.size = NSSize(width: 32, height: 32)
        }

        let utilityResult = SearchResult(
            name: tool.name,
            path: tool.extensionIdentifier ?? "",
            icon: icon,
            isDirectory: false,
            isUtility: true
        )

        // 进入实用工具模式
        isInUtilityMode = true
        currentUtilityIdentifier = tool.extensionIdentifier
        currentUtilityResult = utilityResult

        // 更新 UI
        updateUtilityModeUI()

        // 根据不同的实用工具类型执行相应操作
        switch tool.extensionIdentifier {
        case "ip":
            loadIPAddresses()
        case "uuid":
            // TODO: UUID 生成器
            break
        case "url":
            // TODO: URL 编码解码
            break
        case "base64":
            // TODO: Base64 编码解码
            break
        case "kill":
            loadKillModeProcesses()
        default:
            break
        }

        print("SearchPanelViewController: Utility mode setup complete")
    }

    // MARK: - Setup

    private func setupUI() {
        // IDE Tag View (用于 IDE 项目模式)
        ideTagView.wantsLayer = true
        ideTagView.layer?.backgroundColor =
            NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        ideTagView.layer?.cornerRadius = 6
        ideTagView.translatesAutoresizingMaskIntoConstraints = false
        ideTagView.isHidden = true
        view.addSubview(ideTagView)

        ideIconView.translatesAutoresizingMaskIntoConstraints = false
        ideTagView.addSubview(ideIconView)

        ideNameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        ideNameLabel.textColor = .labelColor
        ideNameLabel.translatesAutoresizingMaskIntoConstraints = false
        ideTagView.addSubview(ideNameLabel)

        // Search icon (隐藏，不再显示)
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.isHidden = true
        view.addSubview(searchIcon)

        // Search field
        setPlaceholder("搜索应用或文档...")
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 22, weight: .light)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        // Divider
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.isHidden = true
        view.addSubview(divider)

        // Table view setup
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ResultColumn"))
        column.width = 610
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = rowHeight
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.doubleAction = #selector(tableViewDoubleClicked)

        // Scroll view
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        view.addSubview(scrollView)

        // No results label
        noResultsLabel.textColor = .secondaryLabelColor
        noResultsLabel.alignment = .center
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        noResultsLabel.isHidden = true
        view.addSubview(noResultsLabel)

        // Constraints
        NSLayoutConstraint.activate([
            // IDE Tag View - 与搜索框垂直居中对齐，微调 +3 补偿视觉偏差
            ideTagView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ideTagView.centerYAnchor.constraint(equalTo: searchField.centerYAnchor, constant: -3),
            ideTagView.heightAnchor.constraint(equalToConstant: 28),

            ideIconView.leadingAnchor.constraint(equalTo: ideTagView.leadingAnchor, constant: 6),
            ideIconView.centerYAnchor.constraint(equalTo: ideTagView.centerYAnchor),
            ideIconView.widthAnchor.constraint(equalToConstant: 18),
            ideIconView.heightAnchor.constraint(equalToConstant: 18),

            ideNameLabel.leadingAnchor.constraint(equalTo: ideIconView.trailingAnchor, constant: 6),
            ideNameLabel.trailingAnchor.constraint(
                equalTo: ideTagView.trailingAnchor, constant: -8),
            ideNameLabel.centerYAnchor.constraint(equalTo: ideTagView.centerYAnchor),

            // Search icon
            searchIcon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchIcon.centerYAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            searchIcon.widthAnchor.constraint(equalToConstant: 22),
            searchIcon.heightAnchor.constraint(equalToConstant: 22),

            // Search field (leading 约束单独处理，用于 IDE 模式切换)
            searchField.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: searchIcon.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 32),

            // Divider
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.topAnchor.constraint(equalTo: view.topAnchor, constant: headerHeight),

            // Scroll view
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // No results label
            noResultsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noResultsLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 20),
        ])

        // 创建并保存 searchField 的 leading 约束
        // 默认直接从左边开始（无搜索图标）
        searchFieldLeadingToIcon = searchField.leadingAnchor.constraint(
            equalTo: view.leadingAnchor, constant: 20)
        searchFieldLeadingToTag = searchField.leadingAnchor.constraint(
            equalTo: ideTagView.trailingAnchor, constant: 12)
        searchFieldLeadingToIcon?.isActive = true
    }

    private var keyboardMonitor: Any?

    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self = self,
                let window = self.view.window,
                window.isVisible,
                window.isKeyWindow
            else {
                return event
            }
            return self.handleKeyEvent(event)
        }
    }

    deinit {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Public Methods

    func focus() {
        view.window?.makeFirstResponder(searchField)

        // 每次显示面板时刷新状态，确保设置更改立即生效
        refreshDisplayMode()
    }

    /// 刷新显示模式（Simple/Full）
    private func refreshDisplayMode() {
        // 如果在 IDE 项目模式或文件夹模式，不要覆盖当前显示的结果
        if isInIDEProjectMode || isInFolderOpenMode {
            updateVisibility()
            return
        }

        let defaultWindowMode =
            UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"

        if searchField.stringValue.isEmpty {
            if defaultWindowMode == "full" && !recentApps.isEmpty {
                results = recentApps
                isShowingRecents = true
            } else {
                results = []
                isShowingRecents = false
            }
            selectedIndex = 0
            tableView.reloadData()
        }

        updateVisibility()
    }

    func resetState() {
        // 如果在 IDE 项目模式，先恢复普通模式 UI
        if isInIDEProjectMode {
            isInIDEProjectMode = false
            currentIDEApp = nil
            currentIDEType = nil
            ideProjects = []
            filteredIDEProjects = []
            restoreNormalModeUI()
            setPlaceholder("搜索应用或文档...")
        }

        // 如果在文件夹打开模式，先恢复普通模式 UI
        if isInFolderOpenMode {
            isInFolderOpenMode = false
            currentFolder = nil
            folderOpeners = []
            restoreNormalModeUI()
            setPlaceholder("搜索应用或文档...")
        }

        // 如果在网页直达 Query 模式，先恢复普通模式 UI
        if isInWebLinkQueryMode {
            isInWebLinkQueryMode = false
            currentWebLinkResult = nil
            restoreNormalModeUI()
            setPlaceholder("搜索应用或文档...")
        }

        // 如果在实用工具模式，先恢复普通模式 UI
        if isInUtilityMode {
            isInUtilityMode = false
            currentUtilityIdentifier = nil
            currentUtilityResult = nil
            ipQueryResults = []
            restoreNormalModeUI()
            searchField.isHidden = false
            setPlaceholder("搜索应用或文档...")
        }

        searchField.stringValue = ""
        selectedIndex = 0

        // Full 模式下显示最近使用的应用
        let defaultWindowMode =
            UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"
        if defaultWindowMode == "full" && !recentApps.isEmpty {
            results = recentApps
            isShowingRecents = true
        } else {
            results = []
            isShowingRecents = false
        }

        tableView.reloadData()
        updateVisibility()
    }

    // MARK: - Search

    /// 缓存的默认搜索网页直达列表
    private var cachedDefaultSearchWebLinks: [SearchResult]?

    /// 获取默认搜索网页直达（带缓存）
    private func getDefaultSearchWebLinks() -> [SearchResult] {
        if let cached = cachedDefaultSearchWebLinks {
            return cached
        }
        let links = searchEngine.getDefaultSearchWebLinks()
        cachedDefaultSearchWebLinks = links
        return links
    }

    /// 刷新默认搜索网页直达缓存
    private func refreshDefaultSearchWebLinksCache() {
        cachedDefaultSearchWebLinks = nil
    }

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            selectedIndex = 0

            // Full 模式下显示最近使用的应用
            let defaultWindowMode =
                UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"
            if defaultWindowMode == "full" && !recentApps.isEmpty {
                results = recentApps
                isShowingRecents = true
            } else {
                results = []
                isShowingRecents = false
            }

            tableView.reloadData()
            updateVisibility()
            return
        }

        isShowingRecents = false
        let searchResults = searchEngine.searchSync(text: query)
        let defaultSearchLinks = getDefaultSearchWebLinks()

        // 过滤掉已经在搜索结果中的默认搜索（避免重复显示）
        let existingPaths = Set(searchResults.map { $0.path })
        let filteredDefaultLinks = defaultSearchLinks.filter { !existingPaths.contains($0.path) }

        if searchResults.isEmpty {
            // 没有搜索结果时，默认搜索显示在最上面
            results = filteredDefaultLinks
        } else {
            // 有搜索结果时，默认搜索显示在最后面
            results = searchResults + filteredDefaultLinks
        }

        selectedIndex = results.isEmpty ? 0 : 0
        tableView.reloadData()
        updateVisibility()

        if !results.isEmpty {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }

    private func updateVisibility() {
        let hasQuery = !searchField.stringValue.isEmpty
        let hasResults = !results.isEmpty
        let defaultWindowMode =
            UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"

        divider.isHidden = !hasQuery && !isShowingRecents
        scrollView.isHidden = !hasResults
        noResultsLabel.isHidden = !hasQuery || hasResults

        // Update window height
        if defaultWindowMode == "full" {
            // Full 模式：始终展开
            updateWindowHeight(expanded: true)
        } else {
            // Simple 模式：有搜索内容且有结果时展开
            updateWindowHeight(expanded: hasQuery && hasResults)
        }
    }

    private func updateWindowHeight(expanded: Bool) {
        guard let window = view.window else { return }

        // Read user's default window mode preference
        let defaultWindowMode =
            UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"

        // If user prefers "full" mode, always show expanded view when there's a query
        // If "simple" mode, only expand when there are results
        let shouldExpand: Bool
        if defaultWindowMode == "full" {
            shouldExpand = expanded  // Expand whenever there's a query
        } else {
            shouldExpand = expanded && !results.isEmpty  // Simple mode: only expand with results
        }

        let targetHeight: CGFloat = shouldExpand ? 500 : 80
        let currentFrame = window.frame

        guard abs(currentFrame.height - targetHeight) > 1 else { return }

        let newOriginY = currentFrame.origin.y - (targetHeight - currentFrame.height)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: newOriginY,
            width: currentFrame.width,
            height: targetHeight
        )

        // No animation for speed
        window.setFrame(newFrame, display: true, animate: false)
    }

    // MARK: - Keyboard Handling

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // 检查输入法是否正在组合输入（如中文输入法）
        var isComposing = false
        if let fieldEditor = searchField.currentEditor() as? NSTextView {
            isComposing = fieldEditor.markedRange().length > 0
        }

        switch Int(event.keyCode) {
        case 51:  // Delete - IDE 项目模式、文件夹打开模式、网页直达 Query 模式或实用工具模式下，输入框为空时退出
            if isComposing { return event }
            if (isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode)
                && searchField.stringValue.isEmpty
            {
                if isInIDEProjectMode {
                    exitIDEProjectMode()
                } else if isInFolderOpenMode {
                    exitFolderOpenMode()
                } else if isInWebLinkQueryMode {
                    exitWebLinkQueryMode()
                } else if isInUtilityMode {
                    exitUtilityMode()
                }
                return nil
            }
            return event
        case 48:  // Tab - 进入 IDE 项目模式、文件夹打开模式或网页直达 Query 模式
            if isComposing { return event }
            if !isInIDEProjectMode && !isInFolderOpenMode && !isInWebLinkQueryMode {
                // 检查当前选中项是否有扩展功能
                guard results.indices.contains(selectedIndex) else {
                    // 没有选中任何项目，忽略 Tab 键
                    return nil
                }
                let item = results[selectedIndex]

                // 检查是否为 IDE（有项目列表扩展）
                if let ideType = IDEType.detect(from: item.path) {
                    let projects = IDERecentProjectsService.shared.getRecentProjects(
                        for: ideType, limit: 20)
                    if !projects.isEmpty {
                        // 进入 IDE 项目模式
                        if tryEnterIDEProjectMode() {
                            return nil
                        }
                    }
                }

                // 检查是否为文件夹（有打开方式扩展）
                let isApp = item.path.hasSuffix(".app")
                if item.isDirectory && !isApp {
                    let openers = IDERecentProjectsService.shared.getAvailableFolderOpeners()
                    if !openers.isEmpty {
                        // 进入文件夹打开模式
                        if tryEnterFolderOpenMode() {
                            return nil
                        }
                    }
                }

                // 检查是否为网页直达且支持 query 扩展
                if item.isWebLink && item.supportsQueryExtension {
                    if tryEnterWebLinkQueryMode(for: item) {
                        return nil
                    }
                }

                // 检查是否为实用工具
                if item.isUtility {
                    if tryEnterUtilityMode(for: item) {
                        return nil
                    }
                }

                // 当前选中项没有扩展功能，忽略 Tab 键（阻止焦点切换）
                return nil
            }
            // 已经在扩展模式中，忽略 Tab 键
            return nil
        case 125:  // Down arrow
            if isComposing { return event }  // 让输入法处理
            moveSelectionDown()
            return nil
        case 126:  // Up arrow
            if isComposing { return event }  // 让输入法处理
            moveSelectionUp()
            return nil
        case 53:  // Escape
            if isComposing { return event }  // 让输入法取消
            // 如果在 IDE 项目模式或文件夹打开模式，先退出该模式
            if isInIDEProjectMode {
                exitIDEProjectMode()
                return nil
            }
            if isInFolderOpenMode {
                exitFolderOpenMode()
                return nil
            }
            if isInWebLinkQueryMode {
                exitWebLinkQueryMode()
                return nil
            }
            if isInUtilityMode {
                exitUtilityMode()
                return nil
            }
            PanelManager.shared.hidePanel()
            return nil
        case 36:  // Return
            if isComposing { return event }  // 让输入法确认输入
            openSelected()
            return nil
        default:
            // Ctrl+N / Ctrl+P
            if event.modifierFlags.contains(.control) {
                if event.keyCode == 45 {  // N
                    moveSelectionDown()
                    return nil
                } else if event.keyCode == 35 {  // P
                    moveSelectionUp()
                    return nil
                }
            }
            return event
        }
    }

    private func moveSelectionDown() {
        guard !results.isEmpty else { return }
        var newIndex = selectedIndex + 1
        // 跳过分组标题
        while newIndex < results.count && results[newIndex].isSectionHeader {
            newIndex += 1
        }
        if newIndex < results.count {
            selectedIndex = newIndex
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            scrollToKeepSelectionCentered()
            tableView.reloadData()
        }
    }

    private func moveSelectionUp() {
        guard !results.isEmpty else { return }
        var newIndex = selectedIndex - 1
        // 跳过分组标题
        while newIndex >= 0 && results[newIndex].isSectionHeader {
            newIndex -= 1
        }
        if newIndex >= 0 {
            selectedIndex = newIndex
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            scrollToKeepSelectionCentered()
            tableView.reloadData()
        }
    }

    // MARK: - IDE Project Mode

    /// 尝试进入 IDE 项目模式
    /// - Returns: 是否成功进入
    private func tryEnterIDEProjectMode() -> Bool {
        guard results.indices.contains(selectedIndex) else { return false }
        let item = results[selectedIndex]

        // 检测是否为支持的 IDE
        guard let ideType = IDEType.detect(from: item.path) else { return false }

        // 获取该 IDE 的最近项目
        let projects = IDERecentProjectsService.shared.getRecentProjects(for: ideType, limit: 20)
        guard !projects.isEmpty else { return false }

        // 进入 IDE 项目模式
        isInIDEProjectMode = true
        currentIDEApp = item
        currentIDEType = ideType
        ideProjects = projects
        filteredIDEProjects = projects

        // 更新 UI
        updateIDEModeUI()

        // 显示项目列表
        results = projects.map { $0.toSearchResult() }
        selectedIndex = 0
        searchField.stringValue = ""
        setPlaceholder("搜索项目...")
        tableView.reloadData()
        updateVisibility()

        return true
    }

    /// 退出 IDE 项目模式
    private func exitIDEProjectMode() {
        isInIDEProjectMode = false
        currentIDEApp = nil
        currentIDEType = nil
        ideProjects = []
        filteredIDEProjects = []

        // 恢复 UI
        restoreNormalModeUI()

        // 恢复搜索状态
        searchField.stringValue = ""
        setPlaceholder("搜索应用或文档...")
        resetState()
    }

    /// 更新 IDE 模式 UI
    private func updateIDEModeUI() {
        guard let app = currentIDEApp else { return }

        // 显示 IDE 标签
        ideTagView.isHidden = false
        ideIconView.image = app.icon
        ideNameLabel.stringValue = app.name

        // 切换 searchField 的 leading 约束
        searchFieldLeadingToIcon?.isActive = false
        searchFieldLeadingToTag?.isActive = true
    }

    /// 恢复普通模式 UI
    private func restoreNormalModeUI() {
        // 隐藏 IDE/文件夹 标签
        ideTagView.isHidden = true

        // 切换 searchField 的 leading 约束
        searchFieldLeadingToTag?.isActive = false
        searchFieldLeadingToIcon?.isActive = true
    }

    /// IDE 项目模式下的搜索
    private func performIDEProjectSearch(_ query: String) {
        if query.isEmpty {
            filteredIDEProjects = ideProjects
        } else {
            let lowercasedQuery = query.lowercased()
            filteredIDEProjects = ideProjects.filter { project in
                project.name.lowercased().contains(lowercasedQuery)
                    || project.path.lowercased().contains(lowercasedQuery)
            }
        }

        results = filteredIDEProjects.map { $0.toSearchResult() }
        selectedIndex = results.isEmpty ? 0 : 0
        tableView.reloadData()
        updateVisibility()
    }

    // MARK: - Folder Open Mode

    /// 尝试进入文件夹打开方式选择模式
    /// - Returns: 是否成功进入
    private func tryEnterFolderOpenMode() -> Bool {
        guard results.indices.contains(selectedIndex) else { return false }
        let item = results[selectedIndex]

        // 检测是否为文件夹（非 .app）
        let isApp = item.path.hasSuffix(".app")
        guard item.isDirectory && !isApp else { return false }

        // 获取可用的打开方式
        let openers = IDERecentProjectsService.shared.getAvailableFolderOpeners()
        guard !openers.isEmpty else { return false }

        // 进入文件夹打开模式
        isInFolderOpenMode = true
        currentFolder = item
        folderOpeners = openers

        // 更新 UI
        updateFolderModeUI()

        // 显示打开方式列表
        results = openers.map { opener in
            SearchResult(
                name: opener.name,
                path: opener.path,
                icon: opener.icon,
                isDirectory: false
            )
        }
        selectedIndex = 0
        searchField.stringValue = ""
        setPlaceholder("选择打开方式...")
        tableView.reloadData()
        updateVisibility()

        return true
    }

    /// 退出文件夹打开模式
    private func exitFolderOpenMode() {
        isInFolderOpenMode = false
        currentFolder = nil
        folderOpeners = []

        // 恢复 UI
        restoreNormalModeUI()

        // 恢复搜索状态
        searchField.stringValue = ""
        setPlaceholder("搜索应用或文档...")
        resetState()
    }

    /// 更新文件夹打开模式 UI
    private func updateFolderModeUI() {
        guard let folder = currentFolder else { return }

        // 显示文件夹标签
        ideTagView.isHidden = false
        ideIconView.image = folder.icon
        ideNameLabel.stringValue = folder.name

        // 切换 searchField 的 leading 约束
        searchFieldLeadingToIcon?.isActive = false
        searchFieldLeadingToTag?.isActive = true
    }

    /// 文件夹打开模式下的搜索（过滤打开方式）
    private func performFolderOpenerSearch(_ query: String) {
        let filteredOpeners: [IDERecentProjectsService.FolderOpenerApp]
        if query.isEmpty {
            filteredOpeners = folderOpeners
        } else {
            let lowercasedQuery = query.lowercased()
            filteredOpeners = folderOpeners.filter { opener in
                opener.name.lowercased().contains(lowercasedQuery)
            }
        }

        results = filteredOpeners.map { opener in
            SearchResult(
                name: opener.name,
                path: opener.path,
                icon: opener.icon,
                isDirectory: false
            )
        }
        selectedIndex = results.isEmpty ? 0 : 0
        tableView.reloadData()
        updateVisibility()
    }

    // MARK: - 网页直达 Query 模式

    /// 尝试进入网页直达 Query 模式
    private func tryEnterWebLinkQueryMode(for item: SearchResult) -> Bool {
        guard item.supportsQueryExtension else { return false }

        isInWebLinkQueryMode = true
        currentWebLinkResult = item

        // 复用 IDE 模式的 UI
        updateWebLinkQueryModeUI()

        // 清空搜索框
        searchField.stringValue = ""
        setPlaceholder("请输入关键词搜索...")

        // 清空结果列表（query 模式下不显示搜索结果）
        results = []
        tableView.reloadData()
        updateVisibility()

        return true
    }

    /// 退出网页直达 Query 模式
    private func exitWebLinkQueryMode() {
        isInWebLinkQueryMode = false
        currentWebLinkResult = nil

        // 恢复 UI
        restoreNormalModeUI()

        // 恢复搜索状态
        searchField.stringValue = ""
        setPlaceholder("搜索应用或文档...")
        resetState()
    }

    /// 更新网页直达 Query 模式 UI
    private func updateWebLinkQueryModeUI() {
        guard let webLink = currentWebLinkResult else { return }

        // 复用 ideTagView 显示网页直达信息
        ideTagView.isHidden = false
        ideIconView.image = webLink.icon
        ideNameLabel.stringValue = webLink.name

        // 切换 searchField 的 leading 约束
        searchFieldLeadingToIcon?.isActive = false
        searchFieldLeadingToTag?.isActive = true
    }

    /// 网页直达 Query 模式下打开 URL
    private func openWebLinkWithQuery(webLink: SearchResult) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        var finalUrl: String?

        if query.isEmpty {
            // 用户没有输入
            if let defaultUrl = webLink.defaultUrl, !defaultUrl.isEmpty {
                // 优先使用默认 URL
                finalUrl = defaultUrl
            } else {
                // 没有设置默认 URL，去掉 {query} 占位符
                finalUrl = webLink.path.replacingOccurrences(of: "{query}", with: "")
            }
        } else {
            // 替换 {query} 占位符
            let encodedQuery =
                query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            finalUrl = webLink.path.replacingOccurrences(of: "{query}", with: encodedQuery)
        }

        if let urlString = finalUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        exitWebLinkQueryMode()
        PanelManager.shared.hidePanel()
    }

    // MARK: - 实用工具模式

    /// 尝试进入实用工具模式
    private func tryEnterUtilityMode(for item: SearchResult) -> Bool {
        guard item.isUtility else { return false }

        isInUtilityMode = true
        currentUtilityIdentifier = item.path  // path 存储的是 extensionIdentifier
        currentUtilityResult = item

        // 更新 UI
        updateUtilityModeUI()

        // 根据不同的实用工具类型执行相应操作
        switch item.path {
        case "ip":
            loadIPAddresses()
        case "uuid":
            // TODO: UUID 生成器
            break
        case "url":
            // TODO: URL 编码解码
            break
        case "base64":
            // TODO: Base64 编码解码
            break
        case "kill":
            loadKillModeProcesses()
        default:
            break
        }

        return true
    }

    /// 退出实用工具模式
    private func exitUtilityMode() {
        isInUtilityMode = false
        currentUtilityIdentifier = nil
        currentUtilityResult = nil
        ipQueryResults = []

        // 清理 kill 模式数据
        killModeApps = []
        killModePorts = []
        killModeAllItems = []
        killModeFilteredItems = []

        // 恢复 UI
        restoreNormalModeUI()
        searchField.isHidden = false  // 恢复搜索框显示

        // 恢复搜索状态
        searchField.stringValue = ""
        setPlaceholder("搜索应用或文档...")
        resetState()

        // 聚焦搜索框，方便用户继续搜索
        view.window?.makeFirstResponder(searchField)
    }

    /// 更新实用工具模式 UI
    private func updateUtilityModeUI() {
        guard let utility = currentUtilityResult else { return }

        // 复用 ideTagView 显示实用工具信息
        ideTagView.isHidden = false
        ideIconView.image = utility.icon
        ideNameLabel.stringValue = utility.name

        // 切换 searchField 的 leading 约束
        searchFieldLeadingToIcon?.isActive = false
        searchFieldLeadingToTag?.isActive = true

        // 根据实用工具类型决定是否显示搜索框
        // kill 模式需要搜索，其他模式（如 IP 查询）不需要
        if currentUtilityIdentifier == "kill" {
            searchField.isHidden = false
            searchField.stringValue = ""
            setPlaceholder("请输入关键词搜索")
        } else {
            searchField.isHidden = true
        }
    }

    /// 加载 IP 地址
    private func loadIPAddresses() {
        // 设置 placeholder 提示用户操作
        searchField.stringValue = ""

        ipQueryResults = [
            (label: "本地 IP", ip: "加载中..."),
            (label: "公网 IP", ip: "加载中..."),
        ]
        reloadIPResults()

        // 获取本地 IP
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let localIP = self?.getLocalIPAddress() ?? "获取失败"
            DispatchQueue.main.async {
                guard let self = self, self.isInUtilityMode, self.currentUtilityIdentifier == "ip"
                else { return }
                if self.ipQueryResults.count > 0 {
                    self.ipQueryResults[0] = (label: "本地 IP", ip: localIP)
                    self.reloadIPResults()
                }
            }
        }

        // 获取公网 IP
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let publicIP = self?.getPublicIPAddress() ?? "获取失败"
            DispatchQueue.main.async {
                guard let self = self, self.isInUtilityMode, self.currentUtilityIdentifier == "ip"
                else { return }
                if self.ipQueryResults.count > 1 {
                    self.ipQueryResults[1] = (label: "公网 IP", ip: publicIP)
                    self.reloadIPResults()
                }
            }
        }
    }

    /// 刷新 IP 结果显示
    private func reloadIPResults() {
        // 保存当前选中索引
        let currentSelection = selectedIndex

        // 将 IP 结果转换为 SearchResult 显示
        results = ipQueryResults.enumerated().map { index, item in
            let icon: NSImage
            // 根据原始标签判断图标类型（去除 "✓ 已复制" 后缀）
            let isLocalIP = item.label.hasPrefix("本地")
            if isLocalIP {
                icon =
                    NSImage(systemSymbolName: "network", accessibilityDescription: nil) ?? NSImage()
            } else {
                icon =
                    NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
            }
            icon.size = NSSize(width: 32, height: 32)

            return SearchResult(
                name: item.ip,
                path: item.label,
                icon: icon,
                isDirectory: false,
                displayAlias: item.label
            )
        }

        // 恢复选中索引
        if results.indices.contains(currentSelection) {
            selectedIndex = currentSelection
        } else {
            selectedIndex = 0
        }

        tableView.reloadData()

        // 确保选中行视觉更新
        if results.indices.contains(selectedIndex) {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }

        updateVisibility()
    }

    /// 获取本地 IP 地址
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // 只处理 IPv4
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // 排除 loopback 接口
                if name == "en0" || name == "en1" || name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    if address != nil && !address!.isEmpty {
                        break
                    }
                }
            }
        }

        return address
    }

    /// 获取公网 IP 地址
    private func getPublicIPAddress() -> String? {
        // 优先使用国内 IP 查询服务，避免代理影响
        let services = [
            "https://myip.ipip.net/ip",
            "https://ip.3322.net",
            "https://www.taobao.com/help/getip.php",
            "https://api.ipify.org",
        ]

        for urlString in services {
            guard let url = URL(string: urlString) else { continue }

            let semaphore = DispatchSemaphore(value: 0)
            var result: String?

            var request = URLRequest(url: url)
            request.timeoutInterval = 3

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }
                guard error == nil,
                    let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200,
                    let data = data,
                    let content = String(data: data, encoding: .utf8)
                else { return }

                // 解析不同服务的响应格式
                if urlString.contains("taobao") {
                    // 淘宝格式: ipCallback({ip:"x.x.x.x"})
                    if let range = content.range(of: "\"([0-9.]+)\"", options: .regularExpression) {
                        let ipWithQuotes = String(content[range])
                        result = ipWithQuotes.replacingOccurrences(of: "\"", with: "")
                    }
                } else {
                    // 其他服务直接返回 IP 或简单文本
                    let ip = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    // 验证是否是有效的 IP 地址格式
                    let ipPattern = "^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$"
                    if ip.range(of: ipPattern, options: .regularExpression) != nil {
                        result = ip
                    }
                }
            }
            task.resume()

            // 等待最多 3 秒
            _ = semaphore.wait(timeout: .now() + 3)

            if let ip = result, !ip.isEmpty {
                return ip
            }
        }

        return nil
    }

    /// 处理实用工具模式下的回车操作
    private func handleUtilityAction() {
        guard let identifier = currentUtilityIdentifier else { return }

        switch identifier {
        case "ip":
            // 复制选中的 IP 地址
            let currentIndex = selectedIndex  // 捕获当前索引
            guard ipQueryResults.indices.contains(currentIndex) else { return }
            let ip = ipQueryResults[currentIndex].ip
            if ip != "加载中..." && ip != "获取失败" {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ip, forType: .string)

                // 获取原始标签（不含 "✓ 已复制"）
                let originalLabel =
                    ipQueryResults[currentIndex].label.hasPrefix("本地") ? "本地 IP" : "公网 IP"

                // 显示复制成功提示
                ipQueryResults[currentIndex] = (label: "\(originalLabel) ✓ 已复制", ip: ip)
                reloadIPResults()

                // 1秒后恢复原标签
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self,
                        self.isInUtilityMode,
                        self.currentUtilityIdentifier == "ip"
                    else { return }
                    // 使用捕获的索引而非当前选中索引
                    if self.ipQueryResults.indices.contains(currentIndex) {
                        self.ipQueryResults[currentIndex] = (label: originalLabel, ip: ip)
                        self.reloadIPResults()
                    }
                }
            }
        case "kill":
            // 显示 kill 确认弹窗
            showKillConfirmation()
        default:
            break
        }
    }

    // MARK: - Kill 模式方法

    /// 加载 kill 模式的进程列表
    private func loadKillModeProcesses() {
        // 设置 placeholder
        setPlaceholder("请输入关键词搜索")

        // 显示加载中状态
        results = []
        tableView.reloadData()

        // 异步加载进程列表
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = ProcessManager.shared.getRunningApps()
            let ports = ProcessManager.shared.getListeningPortProcesses()

            DispatchQueue.main.async {
                guard let self = self,
                    self.isInUtilityMode,
                    self.currentUtilityIdentifier == "kill"
                else { return }

                self.killModeApps = apps
                self.killModePorts = ports
                self.killModeAllItems = apps + ports
                self.killModeFilteredItems = self.killModeAllItems
                self.reloadKillModeResults()
            }
        }
    }

    /// 刷新 kill 模式结果显示
    private func reloadKillModeResults() {
        let currentSelection = selectedIndex

        // 构建带分组标题的结果列表
        var newResults: [SearchResult] = []

        // 过滤已打开应用
        let filteredApps = killModeFilteredItems.filter { $0.isApp }
        // 过滤监听端口进程
        let filteredPorts = killModeFilteredItems.filter { !$0.isApp }

        // 添加「已打开应用」分组
        if !filteredApps.isEmpty {
            // 添加分组标题
            let headerResult = SearchResult(
                name: "已打开应用",
                path: "",
                icon: NSImage(),
                isDirectory: false,
                isSectionHeader: true
            )
            newResults.append(headerResult)

            // 添加应用列表
            for app in filteredApps {
                let icon =
                    app.icon ?? NSImage(
                        systemSymbolName: "app", accessibilityDescription: "App")!
                icon.size = NSSize(width: 32, height: 32)

                let result = SearchResult(
                    name: app.name,
                    path: "\(app.id)",  // 存储 PID
                    icon: icon,
                    isDirectory: false,
                    processStats: "|\(app.formattedCPU)|\(app.formattedMemory)"  // 格式: |cpu|memory (无端口)
                )
                newResults.append(result)
            }
        }

        // 添加「已监听端口」分组
        if !filteredPorts.isEmpty {
            // 添加分组标题
            let headerResult = SearchResult(
                name: "已打开监听端口",
                path: "",
                icon: NSImage(),
                isDirectory: false,
                isSectionHeader: true
            )
            newResults.append(headerResult)

            // 添加端口进程列表
            for process in filteredPorts {
                let icon =
                    process.icon ?? NSImage(
                        systemSymbolName: "terminal", accessibilityDescription: "Process")!
                icon.size = NSSize(width: 32, height: 32)

                // 端口号放到 processStats 前面，使用管道分隔
                let portStr = process.port != nil ? ":\(process.port!)" : ""
                let result = SearchResult(
                    name: process.name,
                    path: "\(process.id)",  // 存储 PID
                    icon: icon,
                    isDirectory: false,
                    processStats: "\(portStr)|\(process.formattedCPU)|\(process.formattedMemory)"  // 格式: port|cpu|memory
                )
                newResults.append(result)
            }
        }

        results = newResults

        // 恢复选中索引，跳过分组标题
        if results.indices.contains(currentSelection)
            && !results[currentSelection].isSectionHeader
        {
            selectedIndex = currentSelection
        } else {
            // 找到第一个非标题行
            selectedIndex = results.firstIndex { !$0.isSectionHeader } ?? 0
        }

        tableView.reloadData()

        if results.indices.contains(selectedIndex) {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }

        updateVisibility()
    }

    /// 执行 kill 模式搜索过滤
    private func performKillModeSearch(_ query: String) {
        if query.isEmpty {
            killModeFilteredItems = killModeAllItems
        } else {
            let lowercaseQuery = query.lowercased()
            killModeFilteredItems = killModeAllItems.filter { process in
                // 匹配名称
                if process.name.lowercased().contains(lowercaseQuery) {
                    return true
                }
                // 匹配端口号
                if let port = process.port, "\(port)".contains(query) {
                    return true
                }
                // 匹配 PID
                if "\(process.id)".contains(query) {
                    return true
                }
                return false
            }
        }
        reloadKillModeResults()
    }

    /// 显示 kill 确认弹窗
    private func showKillConfirmation() {
        guard selectedIndex < results.count else { return }
        let selectedResult = results[selectedIndex]

        // 跳过分组标题
        guard !selectedResult.isSectionHeader else { return }

        // 获取 PID
        guard let pid = Int32(selectedResult.path) else { return }

        // 查找对应的进程信息
        guard let processInfo = killModeAllItems.first(where: { $0.id == pid }) else { return }

        // 显示确认弹窗
        let alert = NSAlert()
        alert.messageText = "是否确定退出 \(processInfo.name)?"
        alert.informativeText = processInfo.isApp ? "" : "进程 ID: \(pid)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        // 设置图标
        if let icon = processInfo.icon {
            alert.icon = icon
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 执行 kill
            let success: Bool
            if processInfo.isApp {
                success = ProcessManager.shared.terminateApp(pid: pid)
            } else {
                success = ProcessManager.shared.killProcess(pid: pid)
            }

            if success {
                // 从列表中移除
                killModeAllItems.removeAll { $0.id == pid }
                killModeFilteredItems.removeAll { $0.id == pid }
                killModeApps.removeAll { $0.id == pid }
                killModePorts.removeAll { $0.id == pid }
                reloadKillModeResults()
            } else {
                // 显示失败提示
                let failAlert = NSAlert()
                failAlert.messageText = "无法终止 \(processInfo.name)"
                failAlert.informativeText = "可能需要更高的权限"
                failAlert.alertStyle = .critical
                failAlert.addButton(withTitle: "确定")
                failAlert.runModal()
            }
        }
    }

    /// 滚动表格使选中行尽量保持在可视区域中间
    private func scrollToKeepSelectionCentered() {
        let visibleRect = scrollView.contentView.bounds

        // 计算可视区域能显示多少行
        let visibleRows = Int(visibleRect.height / rowHeight)
        let middleOffset = visibleRows / 2

        // 计算目标滚动位置，使选中行在中间
        let targetRow = max(0, selectedIndex - middleOffset)
        let targetRect = tableView.rect(ofRow: targetRow)

        // 如果选中行在前几行，不需要居中（保持在顶部）
        if selectedIndex < middleOffset {
            tableView.scrollRowToVisible(0)
        }
        // 如果选中行在最后几行，不需要居中（保持在底部）
        else if selectedIndex >= results.count - middleOffset {
            tableView.scrollRowToVisible(results.count - 1)
        }
        // 否则滚动使选中行居中
        else {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetRect.origin.y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    /// 加载最近使用的应用
    private func loadRecentApps() {
        // 如果已经在扩展模式中，不加载最近应用
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var apps: [SearchResult] = []
            var addedPaths = Set<String>()

            // 1. 优先从 LRU 缓存获取最近使用的应用
            let lruPaths = RecentAppsManager.shared.getRecentApps(limit: 8)
            for path in lruPaths {
                guard !addedPaths.contains(path) else { continue }
                if let result = self?.createSearchResult(from: path) {
                    apps.append(result)
                    addedPaths.insert(path)
                }
            }

            // 2. 如果 LRU 记录不足，用默认应用补充
            if apps.count < 8 {
                let defaultApps = [
                    "/System/Library/CoreServices/Finder.app",
                    "/System/Applications/System Settings.app",
                    "/System/Applications/App Store.app",
                    "/System/Applications/Notes.app",
                    "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
                    "/System/Applications/Mail.app",
                    "/System/Applications/Calendar.app",
                    "/System/Applications/Weather.app",
                ]

                for path in defaultApps {
                    guard apps.count < 8 else { break }
                    guard !addedPaths.contains(path) else { continue }
                    guard FileManager.default.fileExists(atPath: path) else { continue }

                    if let result = self?.createSearchResult(from: path) {
                        apps.append(result)
                        addedPaths.insert(path)
                    }
                }
            }

            DispatchQueue.main.async {
                // 再次检查是否在特殊模式，避免覆盖 IDE 项目列表
                guard
                    self?.isInIDEProjectMode != true && self?.isInFolderOpenMode != true
                        && self?.isInWebLinkQueryMode != true
                else {
                    return
                }

                self?.recentApps = apps

                // 如果是 Full 模式且当前没有搜索内容，显示最近应用
                let defaultWindowMode =
                    UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"
                if defaultWindowMode == "full" && self?.searchField.stringValue.isEmpty == true {
                    self?.results = apps
                    self?.isShowingRecents = true
                    self?.tableView.reloadData()
                    self?.updateVisibility()
                }
            }
        }
    }

    /// 从路径创建 SearchResult
    private func createSearchResult(from path: String) -> SearchResult? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let name = FileManager.default.displayName(atPath: path)
            .replacingOccurrences(of: ".app", with: "")
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)

        return SearchResult(
            name: name,
            path: path,
            icon: icon,
            isDirectory: true
        )
    }

    @objc private func tableViewDoubleClicked() {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && results.indices.contains(clickedRow) else { return }
        selectedIndex = clickedRow
        openSelected()
    }

    private func openSelected() {
        // 网页直达 Query 模式：替换 {query} 占位符后打开
        // 注意：Tab 模式下 results 为空，需要优先处理
        if isInWebLinkQueryMode, let webLink = currentWebLinkResult {
            openWebLinkWithQuery(webLink: webLink)
            return
        }

        // 实用工具模式：执行对应操作
        if isInUtilityMode {
            handleUtilityAction()
            return
        }

        guard results.indices.contains(selectedIndex) else { return }
        let item = results[selectedIndex]

        // IDE 项目模式：使用对应 IDE 打开项目
        if isInIDEProjectMode, let ideApp = currentIDEApp {
            IDERecentProjectsService.shared.openProject(
                IDEProject(name: item.name, path: item.path, ideType: currentIDEType ?? .vscode),
                withIDEAt: ideApp.path
            )
            PanelManager.shared.hidePanel()
            return
        }

        // 文件夹打开模式：使用选中的应用打开文件夹
        if isInFolderOpenMode, let folder = currentFolder {
            IDERecentProjectsService.shared.openFolder(folder.path, withApp: item.path)
            PanelManager.shared.hidePanel()
            return
        }

        // 网页直达：处理 {query} 占位符
        if item.isWebLink {
            var finalUrl = item.path

            // 如果支持 query 扩展，需要处理 {query} 占位符
            if item.supportsQueryExtension {
                // 获取当前搜索框中的文本作为查询
                let currentQuery = searchField.stringValue.trimmingCharacters(in: .whitespaces)

                if !currentQuery.isEmpty {
                    // 有搜索文本，用它替换 {query} 占位符
                    let encodedQuery =
                        currentQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        ?? currentQuery
                    finalUrl = item.path.replacingOccurrences(of: "{query}", with: encodedQuery)
                } else if let defaultUrl = item.defaultUrl, !defaultUrl.isEmpty {
                    // 没有搜索文本但有默认 URL，直接跳转到默认 URL
                    finalUrl = defaultUrl
                } else {
                    // 没有搜索文本也没有默认 URL，去掉 {query} 占位符
                    finalUrl = item.path.replacingOccurrences(of: "{query}", with: "")
                }
            }

            if let url = URL(string: finalUrl) {
                NSWorkspace.shared.open(url)
            }
            PanelManager.shared.hidePanel()
            return
        }

        // 普通模式：使用默认应用打开
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.open(url)

        // 记录到 LRU 缓存（仅记录 .app 应用）
        if item.path.hasSuffix(".app") {
            RecentAppsManager.shared.recordAppOpen(path: item.path)
        }

        PanelManager.shared.hidePanel()
    }
}

// MARK: - NSTextFieldDelegate

extension SearchPanelViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue

        // IDE 项目模式：搜索项目
        if isInIDEProjectMode {
            performIDEProjectSearch(query)
            return
        }

        // 文件夹打开模式：搜索打开方式
        if isInFolderOpenMode {
            performFolderOpenerSearch(query)
            return
        }

        // 网页直达 Query 模式：不进行搜索，只等待用户输入
        if isInWebLinkQueryMode {
            return
        }

        // 实用工具模式：根据类型处理
        if isInUtilityMode {
            // kill 模式支持搜索
            if currentUtilityIdentifier == "kill" {
                performKillModeSearch(query)
            }
            // 其他实用工具模式不进行搜索
            return
        }

        // 普通模式：搜索应用和文件
        performSearch(query)
    }
}

// MARK: - NSTableViewDataSource

extension SearchPanelViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
}

// MARK: - NSTableViewDelegate

extension SearchPanelViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let identifier = NSUserInterfaceItemIdentifier("ResultCell")

        var cellView =
            tableView.makeView(withIdentifier: identifier, owner: self) as? ResultCellView
        if cellView == nil {
            cellView = ResultCellView()
            cellView?.identifier = identifier
        }

        let item = results[row]
        let isSelected = row == selectedIndex
        // 在文件夹打开模式或 IDE 项目模式下隐藏箭头（不能再 Tab）
        cellView?.configure(
            with: item, isSelected: isSelected, hideArrow: isInFolderOpenMode || isInIDEProjectMode)

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 && row < results.count {
            selectedIndex = row
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // 分组标题不可选中
        guard row < results.count else { return true }
        return !results[row].isSectionHeader
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // 分组标题使用较小的行高
        guard row < results.count else { return rowHeight }
        if results[row].isSectionHeader {
            return 28  // 分组标题行高
        }
        return rowHeight
    }
}

// MARK: - Result Cell View

class ResultCellView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let aliasLabel = NSTextField(labelWithString: "")  // 别名标签
    private let aliasBadgeView = NSView()  // 别名背景视图
    private let pathLabel = NSTextField(labelWithString: "")
    private let backgroundView = NSView()
    private let arrowIndicator = NSImageView()  // IDE 箭头指示器

    // 进程统计信息（三列独立显示）
    private let portLabel = NSTextField(labelWithString: "")
    private let cpuIcon = NSImageView()
    private let cpuLabel = NSTextField(labelWithString: "")
    private let memoryIcon = NSImageView()
    private let memoryLabel = NSTextField(labelWithString: "")
    private let statsContainerView = NSView()  // 统计信息容器

    // 用于切换 nameLabel 位置的约束
    private var nameLabelTopConstraint: NSLayoutConstraint!
    private var nameLabelCenterYConstraint: NSLayoutConstraint!
    private var nameLabelTrailingToArrow: NSLayoutConstraint!
    private var nameLabelTrailingToEdge: NSLayoutConstraint!
    private var nameLabelTrailingToStats: NSLayoutConstraint!

    // 分组标题模式的约束
    private var nameLabelLeadingNormal: NSLayoutConstraint!
    private var nameLabelLeadingHeader: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Background
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 4
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
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
        aliasBadgeView.layer?.cornerRadius = 4
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

        // 进程统计信息容器
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.isHidden = true
        addSubview(statsContainerView)

        // 端口号标签
        portLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        portLabel.textColor = .secondaryLabelColor
        portLabel.alignment = .left  // 改为左对齐
        portLabel.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(portLabel)

        // CPU 图标
        cpuIcon.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
        cpuIcon.contentTintColor = .secondaryLabelColor
        cpuIcon.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(cpuIcon)

        // CPU 标签
        cpuLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cpuLabel.textColor = .secondaryLabelColor
        cpuLabel.alignment = .left  // 改为左对齐
        cpuLabel.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(cpuLabel)

        // 内存图标
        memoryIcon.image = NSImage(
            systemSymbolName: "memorychip", accessibilityDescription: "Memory")
        memoryIcon.contentTintColor = .secondaryLabelColor
        memoryIcon.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(memoryIcon)

        // 内存标签
        memoryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        memoryLabel.textColor = .secondaryLabelColor
        memoryLabel.alignment = .left  // 改为左对齐
        memoryLabel.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(memoryLabel)

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

            // 从左到右布局：端口 -> CPU图标+标签 -> 内存图标+标签
            // 端口标签（最左边，固定宽度）
            portLabel.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
            portLabel.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            portLabel.widthAnchor.constraint(equalToConstant: 50),

            // CPU 图标（紧跟端口）
            cpuIcon.leadingAnchor.constraint(equalTo: portLabel.trailingAnchor, constant: 8),
            cpuIcon.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            cpuIcon.widthAnchor.constraint(equalToConstant: 12),
            cpuIcon.heightAnchor.constraint(equalToConstant: 12),

            // CPU 标签（紧跟 CPU 图标）
            cpuLabel.leadingAnchor.constraint(equalTo: cpuIcon.trailingAnchor, constant: 2),
            cpuLabel.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            cpuLabel.widthAnchor.constraint(equalToConstant: 45),

            // 内存图标（紧跟 CPU 标签）
            memoryIcon.leadingAnchor.constraint(equalTo: cpuLabel.trailingAnchor, constant: 8),
            memoryIcon.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            memoryIcon.widthAnchor.constraint(equalToConstant: 12),
            memoryIcon.heightAnchor.constraint(equalToConstant: 12),

            // 内存标签（紧跟内存图标，最右边）
            memoryLabel.leadingAnchor.constraint(equalTo: memoryIcon.trailingAnchor, constant: 2),
            memoryLabel.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            memoryLabel.widthAnchor.constraint(equalToConstant: 60),
            memoryLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),

            // 容器高度
            statsContainerView.topAnchor.constraint(equalTo: portLabel.topAnchor),
            statsContainerView.bottomAnchor.constraint(equalTo: portLabel.bottomAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])
    }

    func configure(with item: SearchResult, isSelected: Bool, hideArrow: Bool = false) {
        // 处理分组标题
        if item.isSectionHeader {
            configureSectionHeader(with: item)
            return
        }

        iconView.image = item.icon
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
        if hasProcessStats {
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
        } else {
            portLabel.stringValue = ""
            cpuLabel.stringValue = ""
            memoryLabel.stringValue = ""
            statsContainerView.isHidden = true
        }

        // App、网页直达、实用工具只显示名称（垂直居中、字体大），文件和文件夹显示路径
        let isApp = item.path.hasSuffix(".app")
        let isWebLink = item.isWebLink
        let isUtility = item.isUtility
        let showPathLabel = !isApp && !isWebLink && !isUtility && !hasProcessStats
        pathLabel.isHidden = !showPathLabel
        pathLabel.stringValue = showPathLabel ? item.path : ""

        // 检测是否为支持的 IDE、文件夹、网页直达 Query 扩展或实用工具，显示箭头指示器
        // hideArrow 为 true 时强制隐藏（如文件夹打开模式下）
        // 有进程统计信息时也隐藏箭头
        let isIDE = IDEType.detect(from: item.path) != nil
        let isFolder = item.isDirectory && !isApp
        let isQueryWebLink = item.isWebLink && item.supportsQueryExtension
        let showArrow =
            !hideArrow && !hasProcessStats && (isIDE || isFolder || isQueryWebLink || isUtility)
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

        // 切换布局：App、网页直达、实用工具、有进程统计的项垂直居中，其他顶部对齐
        if isApp || isWebLink || isUtility || hasProcessStats {
            nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
            nameLabelTopConstraint.isActive = false
            nameLabelCenterYConstraint.isActive = true
        } else {
            nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
            nameLabelCenterYConstraint.isActive = false
            nameLabelTopConstraint.isActive = true
        }

        if isSelected {
            backgroundView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            nameLabel.textColor = .white
            pathLabel.textColor = .white.withAlphaComponent(0.8)
            arrowIndicator.contentTintColor = .white.withAlphaComponent(0.8)
            // 统计信息选中时的样式
            portLabel.textColor = .white.withAlphaComponent(0.9)
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
