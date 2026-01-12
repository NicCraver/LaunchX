import Cocoa

/// Pure AppKit implementation of the search panel - no SwiftUI overhead
class SearchPanelViewController: NSViewController {

    // MARK: - UI Components
    private var contentView: NSView!  // 用于添加子视图的内容视图
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
    var results: [SearchResult] = []
    private var contentHeightConstraint: NSLayoutConstraint?
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

    // 书签搜索模式状态
    private var isInBookmarkMode: Bool = false
    private var bookmarkResults: [BookmarkItem] = []

    // 2FA 短信模式状态
    private var isIn2FAMode: Bool = false
    private var twoFAResults: [TwoFactorCodeItem] = []

    // IP 查询结果
    private var ipQueryResults: [(label: String, ip: String)] = []

    // Kill 进程模式数据
    private var killModeApps: [RunningProcessInfo] = []  // 已打开应用
    private var killModePorts: [RunningProcessInfo] = []  // 监听端口进程
    private var killModeAllItems: [RunningProcessInfo] = []  // 合并列表（用于显示）
    private var killModeFilteredItems: [RunningProcessInfo] = []  // 搜索过滤后的列表

    // UUID 生成器状态
    private var uuidUseHyphen: Bool = true  // 是否使用连字符
    private var uuidUppercase: Bool = true  // 是否大写
    private var uuidCount: Int = 1  // 生成数量
    private var generatedUUIDs: [String] = []  // 生成的 UUID 列表
    private var uuidDebounceWorkItem: DispatchWorkItem?  // UUID 生成防抖

    // UUID 生成器 UI 组件
    private let uuidOptionsView = NSView()  // 选项容器
    private let hyphenCheckbox = NSButton(checkboxWithTitle: "连字符", target: nil, action: nil)
    private let uppercaseRadio = NSButton(radioButtonWithTitle: "大写字符", target: nil, action: nil)
    private let lowercaseRadio = NSButton(radioButtonWithTitle: "小写字符", target: nil, action: nil)
    private let resultLabel = NSTextField(labelWithString: "结果")
    private let uuidResultView = NSScrollView()  // UUID 结果滚动视图
    private let uuidResultTextView = NSTextView()  // UUID 结果文本

    // URL 编码解码 UI 组件
    private let urlCoderView = NSView()  // URL 编码解码容器
    private let decodedURLLabel = NSTextField(labelWithString: "解码的 URL")
    private let decodedURLScrollView = NSScrollView()  // 解码 URL 滚动视图
    private let decodedURLTextView = NSTextView()  // 解码 URL 文本视图
    private let decodedURLCopyButton = NSButton()
    private let encodedURLLabel = NSTextField(labelWithString: "编码的 URL")
    private let encodedURLScrollView = NSScrollView()  // 编码 URL 滚动视图
    private let encodedURLTextView = NSTextView()  // 编码 URL 文本视图
    private let encodedURLCopyButton = NSButton()
    private var urlCoderDebounceWorkItem: DispatchWorkItem?  // URL 编码解码防抖

    // Base64 编码解码 UI 组件
    private let base64CoderView = NSView()  // Base64 编码解码容器
    private let originalTextLabel = NSTextField(labelWithString: "原始文本")
    private let originalTextScrollView = NSScrollView()  // 原始文本滚动视图
    private let originalTextView = NSTextView()  // 原始文本视图
    private let originalTextCopyButton = NSButton()
    private let base64TextLabel = NSTextField(labelWithString: "Base64")
    private let base64TextScrollView = NSScrollView()  // Base64 文本滚动视图
    private let base64TextView = NSTextView()  // Base64 文本视图
    private let base64TextCopyButton = NSButton()
    private var base64CoderDebounceWorkItem: DispatchWorkItem?  // Base64 编码解码防抖

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
            self.contentView = glassEffectView  // macOS 26+ 直接使用 glassEffectView
            return
        }

        // macOS 26 以下使用传统的 NSVisualEffectView
        // 使用容器视图来分离阴影层和内容层，解决圆角裁剪与阴影显示的冲突
        let containerView = NSView()
        containerView.wantsLayer = true

        // 阴影层 - 用于显示阴影
        let shadowLayer = CALayer()
        shadowLayer.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
        shadowLayer.cornerRadius = 26
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.4
        shadowLayer.shadowOffset = CGSize(width: 0, height: -4)
        shadowLayer.shadowRadius = 20
        containerView.layer?.addSublayer(shadowLayer)

        // 内容视图 - NSVisualEffectView
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 26
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true  // 正确裁剪圆角

        // 添加边框
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(visualEffectView)

        // 保存阴影层引用，用于布局更新
        containerView.layer?.setValue(shadowLayer, forKey: "shadowLayer")

        // 设置约束让 visualEffectView 填充 containerView
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        self.view = containerView
        self.contentView = visualEffectView  // 子视图应添加到 visualEffectView
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

    override func viewDidLayout() {
        super.viewDidLayout()
        // 更新阴影层的 frame 以匹配视图大小
        if let shadowLayer = view.layer?.value(forKey: "shadowLayer") as? CALayer {
            shadowLayer.frame = view.bounds
        }
    }

    // 支持顶部拖拽（简单的支持了一下，这不是重点）
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.isMovableByWindowBackground = true
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

        // 监听直接进入书签模式的通知（由快捷键触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterBookmarkModeDirectly),
            name: .enterBookmarkModeDirectly,
            object: nil
        )

        // 监听直接进入 2FA 模式的通知（由快捷键触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnter2FAModeDirectly),
            name: .enter2FAModeDirectly,
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

        // 如果在其他扩展模式中，先清理
        if isInWebLinkQueryMode || isInFolderOpenMode || isInUtilityMode {
            cleanupAllExtensionModes()
        }

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
        isShowingRecents = false
        selectedIndex = 0
        searchField.stringValue = ""
        setPlaceholder("搜索项目...")
        tableView.reloadData()
        updateVisibility()

        // 聚焦搜索框
        view.window?.makeFirstResponder(searchField)

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

        // 如果在其他扩展模式中，先清理
        if isInIDEProjectMode || isInFolderOpenMode || isInUtilityMode {
            cleanupAllExtensionModes()
        }

        // 进入网页直达 Query 模式
        isInWebLinkQueryMode = true
        currentWebLinkResult = webLinkResult

        // 更新 UI
        updateWebLinkQueryModeUI()

        // 清空结果列表，确保不显示最近使用的app
        results = []
        isShowingRecents = false
        selectedIndex = 0
        searchField.stringValue = ""
        setPlaceholder("请输入关键词搜索...")
        tableView.reloadData()
        updateVisibility()

        // 聚焦搜索框
        view.window?.makeFirstResponder(searchField)

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

        // 如果在其他扩展模式中（包括其他实用工具），先清理
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode {
            cleanupAllExtensionModes()
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
            loadUUIDGenerator()
        case "url":
            loadURLCoder()
        case "base64":
            loadBase64Coder()
        case "kill":
            loadKillModeProcesses()
        default:
            break
        }

        print("SearchPanelViewController: Utility mode setup complete")
    }

    /// 处理直接进入书签模式的通知
    @objc private func handleEnterBookmarkModeDirectly() {
        print("SearchPanelViewController: handleEnterBookmarkModeDirectly called")

        // 如果在其他扩展模式中，先清理（包括 2FA 模式等）
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode
            || isIn2FAMode
        {
            cleanupAllExtensionModes()
        }

        // 如果已经在书签模式中，刷新数据即可
        if isInBookmarkMode {
            print("SearchPanelViewController: Already in bookmark mode, refreshing")
            loadAllBookmarks()
            return
        }

        // 进入书签模式
        isInBookmarkMode = true

        // 更新 UI
        updateBookmarkModeUI()

        // 加载所有书签
        loadAllBookmarks()

        print("SearchPanelViewController: Bookmark mode setup complete")
    }

    /// 更新书签模式 UI
    private func updateBookmarkModeUI() {
        // 显示 IDE Tag View 作为书签标签
        ideTagView.isHidden = false
        let bookmarkIcon =
            NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: "Bookmark")
            ?? NSImage()
        bookmarkIcon.size = NSSize(width: 16, height: 16)
        ideIconView.image = bookmarkIcon
        ideNameLabel.stringValue = "搜索书签"

        // 切换 searchField 的 leading 约束（避免与标签重叠）
        searchFieldLeadingToIcon?.isActive = false
        searchFieldLeadingToTag?.isActive = true

        // 更新搜索框占位符
        setPlaceholder("搜索书签...")

        // 清空搜索框
        searchField.stringValue = ""

        // 聚焦搜索框
        view.window?.makeFirstResponder(searchField)
    }

    /// 加载所有书签
    private func loadAllBookmarks() {
        bookmarkResults = BookmarkService.shared.getAllBookmarks()

        // 转换为 SearchResult
        results = bookmarkResults.map { bookmark in
            SearchResult(
                name: bookmark.title,
                path: bookmark.url,
                icon: bookmark.source.icon,
                isDirectory: false,
                displayAlias: bookmark.folderPath.isEmpty ? nil : bookmark.folderPath.last,
                isBookmark: true,
                bookmarkSource: bookmark.source.rawValue
            )
        }

        selectedIndex = 0
        tableView.reloadData()
        updateVisibility()

        if !results.isEmpty {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }

    /// 书签模式搜索
    private func performBookmarkSearch(_ query: String) {
        let filteredBookmarks: [BookmarkItem]
        if query.isEmpty {
            filteredBookmarks = bookmarkResults
        } else {
            filteredBookmarks = BookmarkService.shared.search(query: query)
        }

        results = filteredBookmarks.map { bookmark in
            SearchResult(
                name: bookmark.title,
                path: bookmark.url,
                icon: bookmark.source.icon,
                isDirectory: false,
                displayAlias: bookmark.folderPath.isEmpty ? nil : bookmark.folderPath.last,
                isBookmark: true,
                bookmarkSource: bookmark.source.rawValue
            )
        }

        selectedIndex = 0
        tableView.reloadData()
        updateVisibility()

        if !results.isEmpty {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }

    /// 退出书签模式
    private func exitBookmarkMode() {
        guard isInBookmarkMode else { return }

        isInBookmarkMode = false
        bookmarkResults = []

        // 恢复 UI
        restoreNormalModeUI()

        // 恢复搜索状态
        searchField.stringValue = ""
        setPlaceholder("搜索应用或文档...")
        resetState()
    }

    /// 进入书签模式（通过别名搜索选择）
    private func enterBookmarkMode() {
        // 如果在其他扩展模式中，先清理
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode {
            cleanupAllExtensionModes()
        }

        // 进入书签模式
        isInBookmarkMode = true

        // 更新 UI
        updateBookmarkModeUI()

        // 加载所有书签
        loadAllBookmarks()

        print("SearchPanelViewController: Entered bookmark mode via alias")
    }

    /// 进入 2FA 模式（通过别名搜索选择）
    private func enter2FAMode() {
        // 如果在其他扩展模式中，先清理
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode
            || isInBookmarkMode
        {
            cleanupAllExtensionModes()
        }

        // 进入 2FA 模式
        isIn2FAMode = true

        // 更新 UI
        update2FAModeUI()

        // 加载所有验证码
        loadAll2FACodes()

        print("SearchPanelViewController: Entered 2FA mode via alias")
    }

    // MARK: - 2FA 短信模式

    /// 处理直接进入 2FA 模式的通知
    @objc private func handleEnter2FAModeDirectly() {
        print("SearchPanelViewController: handleEnter2FAModeDirectly called")

        // 如果在其他扩展模式中，先清理（包括书签模式等）
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode
            || isInBookmarkMode
        {
            cleanupAllExtensionModes()
        }

        // 如果已经在 2FA 模式中，刷新数据即可
        if isIn2FAMode {
            print("SearchPanelViewController: Already in 2FA mode, refreshing")
            loadAll2FACodes()
            return
        }

        // 进入 2FA 模式
        isIn2FAMode = true

        // 更新 UI
        update2FAModeUI()

        // 加载所有验证码
        loadAll2FACodes()

        print("SearchPanelViewController: 2FA mode setup complete")
    }

    /// 更新 2FA 模式 UI
    private func update2FAModeUI() {
        // 显示 IDE Tag View 作为 2FA 标签
        ideTagView.isHidden = false
        let twoFAIcon =
            NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "2FA")
            ?? NSImage()
        twoFAIcon.size = NSSize(width: 16, height: 16)
        ideIconView.image = twoFAIcon
        ideNameLabel.stringValue = "2FA 短信"

        // 切换 searchField 的 leading 约束（避免与标签重叠）
        searchFieldLeadingToIcon?.isActive = false
        searchFieldLeadingToTag?.isActive = true

        // 更新搜索框占位符
        setPlaceholder("搜索验证码...")

        // 清空搜索框
        searchField.stringValue = ""

        // 聚焦搜索框
        view.window?.makeFirstResponder(searchField)
    }

    /// 加载所有 2FA 验证码
    private func loadAll2FACodes() {
        let settings = TwoFactorAuthSettings.load()
        twoFAResults = TwoFactorAuthService.shared.getRecentCodes(
            timeSpanMinutes: settings.timeSpanMinutes)

        // 转换为 SearchResult
        results = twoFAResults.map { code in
            SearchResult(
                name: "验证码: \(code.code)",
                path: "\(code.sender) · \(code.formattedTime)",
                icon: NSImage(
                    systemSymbolName: "number.circle.fill", accessibilityDescription: "Code")
                    ?? NSImage(),
                isDirectory: false,
                displayAlias: nil,
                is2FACode: true
            )
        }

        selectedIndex = 0
        tableView.reloadData()
        updateVisibility()

        if !results.isEmpty {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }

    /// 2FA 模式搜索
    private func perform2FASearch(_ query: String) {
        let filteredCodes: [TwoFactorCodeItem]
        if query.isEmpty {
            filteredCodes = twoFAResults
        } else {
            // 搜索验证码或发送者
            filteredCodes = twoFAResults.filter { code in
                code.code.contains(query) || code.sender.localizedCaseInsensitiveContains(query)
                    || code.fullMessage.localizedCaseInsensitiveContains(query)
            }
        }

        results = filteredCodes.map { code in
            SearchResult(
                name: "验证码: \(code.code)",
                path: "\(code.sender) · \(code.formattedTime)",
                icon: NSImage(
                    systemSymbolName: "number.circle.fill", accessibilityDescription: "Code")
                    ?? NSImage(),
                isDirectory: false,
                displayAlias: nil,
                is2FACode: true
            )
        }

        selectedIndex = 0
        tableView.reloadData()
        updateVisibility()

        if !results.isEmpty {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }

    /// 退出 2FA 模式
    private func exit2FAMode() {
        guard isIn2FAMode else { return }

        isIn2FAMode = false
        twoFAResults = []

        // 恢复 UI
        restoreNormalModeUI()

        // 恢复搜索状态
        searchField.stringValue = ""
        setPlaceholder("搜索应用或文档...")
        resetState()
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
        contentView.addSubview(ideTagView)

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
        contentView.addSubview(searchIcon)

        // Search field
        setPlaceholder("搜索应用或文档...")
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 22, weight: .light)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        // Divider
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.isHidden = true
        contentView.addSubview(divider)

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
        contentView.addSubview(scrollView)

        // No results label
        noResultsLabel.textColor = .secondaryLabelColor
        noResultsLabel.alignment = .center
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        noResultsLabel.isHidden = true
        contentView.addSubview(noResultsLabel)

        // Constraints
        NSLayoutConstraint.activate([
            // IDE Tag View - 与搜索框垂直居中对齐，微调 +3 补偿视觉偏差
            ideTagView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
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
            searchIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchIcon.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            searchIcon.widthAnchor.constraint(equalToConstant: 22),
            searchIcon.heightAnchor.constraint(equalToConstant: 22),

            // Search field (leading 约束单独处理，用于 IDE 模式切换)
            searchField.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: searchIcon.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 32),

            // Divider
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: headerHeight),

            // Scroll view
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // No results label
            noResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            noResultsLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 20),
        ])

        // Define main height constraint
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: headerHeight)
        contentHeightConstraint?.isActive = true

        // 创建并保存 searchField 的 leading 约束
        // 默认直接从左边开始（无搜索图标）
        searchFieldLeadingToIcon = searchField.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor, constant: 20)
        searchFieldLeadingToTag = searchField.leadingAnchor.constraint(
            equalTo: ideTagView.trailingAnchor, constant: 12)
        searchFieldLeadingToIcon?.isActive = true

        // UUID 生成器 UI 设置
        setupUUIDGeneratorUI()

        // URL 编码解码 UI 设置
        setupURLCoderUI()

        // Base64 编码解码 UI 设置
        setupBase64CoderUI()
    }

    /// 设置 UUID 生成器 UI
    private func setupUUIDGeneratorUI() {
        // 选项容器
        uuidOptionsView.translatesAutoresizingMaskIntoConstraints = false
        uuidOptionsView.isHidden = true
        contentView.addSubview(uuidOptionsView)

        // 连字符复选框
        hyphenCheckbox.state = .on
        hyphenCheckbox.target = self
        hyphenCheckbox.action = #selector(uuidOptionChanged)
        hyphenCheckbox.translatesAutoresizingMaskIntoConstraints = false
        hyphenCheckbox.setContentHuggingPriority(.required, for: .horizontal)
        hyphenCheckbox.refusesFirstResponder = true
        uuidOptionsView.addSubview(hyphenCheckbox)

        // 大写单选按钮
        uppercaseRadio.state = .on
        uppercaseRadio.target = self
        uppercaseRadio.action = #selector(uuidCaseChanged(_:))
        uppercaseRadio.translatesAutoresizingMaskIntoConstraints = false
        uppercaseRadio.setContentHuggingPriority(.required, for: .horizontal)
        uppercaseRadio.refusesFirstResponder = true
        uuidOptionsView.addSubview(uppercaseRadio)

        // 小写单选按钮
        lowercaseRadio.state = .off
        lowercaseRadio.target = self
        lowercaseRadio.action = #selector(uuidCaseChanged(_:))
        lowercaseRadio.translatesAutoresizingMaskIntoConstraints = false
        lowercaseRadio.setContentHuggingPriority(.required, for: .horizontal)
        lowercaseRadio.refusesFirstResponder = true
        uuidOptionsView.addSubview(lowercaseRadio)

        // 结果标签
        resultLabel.stringValue = "结果"
        resultLabel.font = .systemFont(ofSize: 12, weight: .medium)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        uuidOptionsView.addSubview(resultLabel)

        // UUID 结果滚动视图
        uuidResultView.hasVerticalScroller = true
        uuidResultView.hasHorizontalScroller = false
        uuidResultView.autohidesScrollers = true
        uuidResultView.borderType = .noBorder
        uuidResultView.drawsBackground = false
        uuidResultView.translatesAutoresizingMaskIntoConstraints = false
        uuidOptionsView.addSubview(uuidResultView)

        // UUID 结果文本视图
        uuidResultTextView.isEditable = false
        uuidResultTextView.isSelectable = true
        uuidResultTextView.isRichText = false
        uuidResultTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        uuidResultTextView.drawsBackground = false
        uuidResultTextView.textColor = .labelColor
        uuidResultTextView.textContainerInset = NSSize(width: 0, height: 4)
        uuidResultTextView.textContainer?.lineFragmentPadding = 0
        uuidResultTextView.autoresizingMask = [.width]
        uuidResultView.documentView = uuidResultTextView

        // UUID 选项约束
        NSLayoutConstraint.activate([
            uuidOptionsView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            uuidOptionsView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            uuidOptionsView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),

            // 第一行：选项按钮（水平排列）
            hyphenCheckbox.leadingAnchor.constraint(equalTo: uuidOptionsView.leadingAnchor),
            hyphenCheckbox.topAnchor.constraint(equalTo: uuidOptionsView.topAnchor),

            uppercaseRadio.leadingAnchor.constraint(
                equalTo: hyphenCheckbox.trailingAnchor, constant: 16),
            uppercaseRadio.centerYAnchor.constraint(equalTo: hyphenCheckbox.centerYAnchor),

            lowercaseRadio.leadingAnchor.constraint(
                equalTo: uppercaseRadio.trailingAnchor, constant: 12),
            lowercaseRadio.centerYAnchor.constraint(equalTo: hyphenCheckbox.centerYAnchor),

            // 结果标签
            resultLabel.leadingAnchor.constraint(equalTo: uuidOptionsView.leadingAnchor),
            resultLabel.topAnchor.constraint(equalTo: hyphenCheckbox.bottomAnchor, constant: 12),

            // UUID 结果视图
            uuidResultView.leadingAnchor.constraint(equalTo: uuidOptionsView.leadingAnchor),
            uuidResultView.trailingAnchor.constraint(equalTo: uuidOptionsView.trailingAnchor),
            uuidResultView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 8),
            uuidResultView.bottomAnchor.constraint(equalTo: uuidOptionsView.bottomAnchor),
        ])

        uuidOptionsView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor, constant: -12
        ).isActive = true
    }

    /// 设置 URL 编码解码 UI
    private func setupURLCoderUI() {
        // URL 编码解码容器
        urlCoderView.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.isHidden = true
        contentView.addSubview(urlCoderView)

        // 解码的 URL 标签
        decodedURLLabel.font = .systemFont(ofSize: 12, weight: .medium)
        decodedURLLabel.textColor = .secondaryLabelColor
        decodedURLLabel.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(decodedURLLabel)

        // 解码的 URL 复制按钮
        decodedURLCopyButton.image = NSImage(
            systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        decodedURLCopyButton.bezelStyle = .inline
        decodedURLCopyButton.isBordered = false
        decodedURLCopyButton.target = self
        decodedURLCopyButton.action = #selector(copyDecodedURL)
        decodedURLCopyButton.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(decodedURLCopyButton)

        // 解码的 URL 输入框背景
        let decodedFieldBg = NSView()
        decodedFieldBg.wantsLayer = true
        decodedFieldBg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        decodedFieldBg.layer?.cornerRadius = 6
        decodedFieldBg.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(decodedFieldBg)

        // 解码的 URL 滚动视图
        decodedURLScrollView.hasVerticalScroller = true
        decodedURLScrollView.hasHorizontalScroller = false
        decodedURLScrollView.autohidesScrollers = true
        decodedURLScrollView.borderType = .noBorder
        decodedURLScrollView.drawsBackground = false
        decodedURLScrollView.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(decodedURLScrollView)

        // 解码的 URL 文本视图
        decodedURLTextView.isEditable = true
        decodedURLTextView.isSelectable = true
        decodedURLTextView.isRichText = false
        decodedURLTextView.font = .systemFont(ofSize: 13)
        decodedURLTextView.drawsBackground = false
        decodedURLTextView.textColor = .labelColor
        decodedURLTextView.textContainerInset = NSSize(width: 4, height: 4)
        decodedURLTextView.delegate = self
        decodedURLTextView.autoresizingMask = [.width]
        decodedURLScrollView.documentView = decodedURLTextView

        // 编码的 URL 标签
        encodedURLLabel.font = .systemFont(ofSize: 12, weight: .medium)
        encodedURLLabel.textColor = .secondaryLabelColor
        encodedURLLabel.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(encodedURLLabel)

        // 编码的 URL 复制按钮
        encodedURLCopyButton.image = NSImage(
            systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        encodedURLCopyButton.bezelStyle = .inline
        encodedURLCopyButton.isBordered = false
        encodedURLCopyButton.target = self
        encodedURLCopyButton.action = #selector(copyEncodedURL)
        encodedURLCopyButton.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(encodedURLCopyButton)

        // 编码的 URL 输入框背景
        let encodedFieldBg = NSView()
        encodedFieldBg.wantsLayer = true
        encodedFieldBg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        encodedFieldBg.layer?.cornerRadius = 6
        encodedFieldBg.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(encodedFieldBg)

        // 编码的 URL 滚动视图
        encodedURLScrollView.hasVerticalScroller = true
        encodedURLScrollView.hasHorizontalScroller = false
        encodedURLScrollView.autohidesScrollers = true
        encodedURLScrollView.borderType = .noBorder
        encodedURLScrollView.drawsBackground = false
        encodedURLScrollView.translatesAutoresizingMaskIntoConstraints = false
        urlCoderView.addSubview(encodedURLScrollView)

        // 编码的 URL 文本视图
        encodedURLTextView.isEditable = true
        encodedURLTextView.isSelectable = true
        encodedURLTextView.isRichText = false
        encodedURLTextView.font = .systemFont(ofSize: 13)
        encodedURLTextView.drawsBackground = false
        encodedURLTextView.textColor = .labelColor
        encodedURLTextView.textContainerInset = NSSize(width: 4, height: 4)
        encodedURLTextView.delegate = self
        encodedURLTextView.autoresizingMask = [.width]
        encodedURLScrollView.documentView = encodedURLTextView

        // URL 编码解码约束
        NSLayoutConstraint.activate([
            urlCoderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            urlCoderView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            urlCoderView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),

            // 解码的 URL 标签
            decodedURLLabel.leadingAnchor.constraint(equalTo: urlCoderView.leadingAnchor),
            decodedURLLabel.topAnchor.constraint(equalTo: urlCoderView.topAnchor),

            // 解码的 URL 复制按钮
            decodedURLCopyButton.trailingAnchor.constraint(equalTo: urlCoderView.trailingAnchor),
            decodedURLCopyButton.centerYAnchor.constraint(equalTo: decodedURLLabel.centerYAnchor),
            decodedURLCopyButton.widthAnchor.constraint(equalToConstant: 20),
            decodedURLCopyButton.heightAnchor.constraint(equalToConstant: 20),

            // 解码的 URL 输入框背景
            decodedFieldBg.leadingAnchor.constraint(equalTo: urlCoderView.leadingAnchor),
            decodedFieldBg.trailingAnchor.constraint(equalTo: urlCoderView.trailingAnchor),
            decodedFieldBg.topAnchor.constraint(equalTo: decodedURLLabel.bottomAnchor, constant: 6),
            decodedFieldBg.heightAnchor.constraint(equalToConstant: 150),

            // 解码的 URL 滚动视图
            decodedURLScrollView.leadingAnchor.constraint(
                equalTo: decodedFieldBg.leadingAnchor, constant: 4),
            decodedURLScrollView.trailingAnchor.constraint(
                equalTo: decodedFieldBg.trailingAnchor, constant: -4),
            decodedURLScrollView.topAnchor.constraint(
                equalTo: decodedFieldBg.topAnchor, constant: 4),
            decodedURLScrollView.bottomAnchor.constraint(
                equalTo: decodedFieldBg.bottomAnchor, constant: -4),

            // 编码的 URL 标签
            encodedURLLabel.leadingAnchor.constraint(equalTo: urlCoderView.leadingAnchor),
            encodedURLLabel.topAnchor.constraint(
                equalTo: decodedFieldBg.bottomAnchor, constant: 12),

            // 编码的 URL 复制按钮
            encodedURLCopyButton.trailingAnchor.constraint(equalTo: urlCoderView.trailingAnchor),
            encodedURLCopyButton.centerYAnchor.constraint(equalTo: encodedURLLabel.centerYAnchor),
            encodedURLCopyButton.widthAnchor.constraint(equalToConstant: 20),
            encodedURLCopyButton.heightAnchor.constraint(equalToConstant: 20),

            // 编码的 URL 输入框背景
            encodedFieldBg.leadingAnchor.constraint(equalTo: urlCoderView.leadingAnchor),
            encodedFieldBg.trailingAnchor.constraint(equalTo: urlCoderView.trailingAnchor),
            encodedFieldBg.topAnchor.constraint(equalTo: encodedURLLabel.bottomAnchor, constant: 6),
            encodedFieldBg.heightAnchor.constraint(equalToConstant: 150),

            // 编码的 URL 滚动视图
            encodedURLScrollView.leadingAnchor.constraint(
                equalTo: encodedFieldBg.leadingAnchor, constant: 4),
            encodedURLScrollView.trailingAnchor.constraint(
                equalTo: encodedFieldBg.trailingAnchor, constant: -4),
            encodedURLScrollView.topAnchor.constraint(
                equalTo: encodedFieldBg.topAnchor, constant: 4),
            encodedURLScrollView.bottomAnchor.constraint(
                equalTo: encodedFieldBg.bottomAnchor, constant: -4),
        ])

        urlCoderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
            .isActive = true
    }

    /// 设置 Base64 编码解码 UI
    private func setupBase64CoderUI() {
        // Base64 编码解码容器
        base64CoderView.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.isHidden = true
        contentView.addSubview(base64CoderView)

        // 原始文本标签
        originalTextLabel.font = .systemFont(ofSize: 12, weight: .medium)
        originalTextLabel.textColor = .secondaryLabelColor
        originalTextLabel.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(originalTextLabel)

        // 原始文本复制按钮
        originalTextCopyButton.image = NSImage(
            systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        originalTextCopyButton.bezelStyle = .inline
        originalTextCopyButton.isBordered = false
        originalTextCopyButton.target = self
        originalTextCopyButton.action = #selector(copyOriginalText)
        originalTextCopyButton.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(originalTextCopyButton)

        // 原始文本输入框背景
        let originalFieldBg = NSView()
        originalFieldBg.wantsLayer = true
        originalFieldBg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        originalFieldBg.layer?.cornerRadius = 6
        originalFieldBg.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(originalFieldBg)

        // 原始文本滚动视图
        originalTextScrollView.hasVerticalScroller = true
        originalTextScrollView.hasHorizontalScroller = false
        originalTextScrollView.autohidesScrollers = true
        originalTextScrollView.borderType = .noBorder
        originalTextScrollView.drawsBackground = false
        originalTextScrollView.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(originalTextScrollView)

        // 原始文本视图
        originalTextView.isEditable = true
        originalTextView.isSelectable = true
        originalTextView.isRichText = false
        originalTextView.font = .systemFont(ofSize: 13)
        originalTextView.drawsBackground = false
        originalTextView.textColor = .labelColor
        originalTextView.textContainerInset = NSSize(width: 4, height: 4)
        originalTextView.delegate = self
        originalTextView.autoresizingMask = [.width]
        originalTextScrollView.documentView = originalTextView

        // Base64 文本标签
        base64TextLabel.font = .systemFont(ofSize: 12, weight: .medium)
        base64TextLabel.textColor = .secondaryLabelColor
        base64TextLabel.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(base64TextLabel)

        // Base64 文本复制按钮
        base64TextCopyButton.image = NSImage(
            systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        base64TextCopyButton.bezelStyle = .inline
        base64TextCopyButton.isBordered = false
        base64TextCopyButton.target = self
        base64TextCopyButton.action = #selector(copyBase64Text)
        base64TextCopyButton.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(base64TextCopyButton)

        // Base64 文本输入框背景
        let base64FieldBg = NSView()
        base64FieldBg.wantsLayer = true
        base64FieldBg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        base64FieldBg.layer?.cornerRadius = 6
        base64FieldBg.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(base64FieldBg)

        // Base64 文本滚动视图
        base64TextScrollView.hasVerticalScroller = true
        base64TextScrollView.hasHorizontalScroller = false
        base64TextScrollView.autohidesScrollers = true
        base64TextScrollView.borderType = .noBorder
        base64TextScrollView.drawsBackground = false
        base64TextScrollView.translatesAutoresizingMaskIntoConstraints = false
        base64CoderView.addSubview(base64TextScrollView)

        // Base64 文本视图
        base64TextView.isEditable = true
        base64TextView.isSelectable = true
        base64TextView.isRichText = false
        base64TextView.font = .systemFont(ofSize: 13)
        base64TextView.drawsBackground = false
        base64TextView.textColor = .labelColor
        base64TextView.textContainerInset = NSSize(width: 4, height: 4)
        base64TextView.delegate = self
        base64TextView.autoresizingMask = [.width]
        base64TextScrollView.documentView = base64TextView

        // Base64 编码解码约束
        NSLayoutConstraint.activate([
            base64CoderView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 20),
            base64CoderView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -20),
            base64CoderView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),

            // 原始文本标签
            originalTextLabel.leadingAnchor.constraint(equalTo: base64CoderView.leadingAnchor),
            originalTextLabel.topAnchor.constraint(equalTo: base64CoderView.topAnchor),

            // 原始文本复制按钮
            originalTextCopyButton.trailingAnchor.constraint(
                equalTo: base64CoderView.trailingAnchor),
            originalTextCopyButton.centerYAnchor.constraint(
                equalTo: originalTextLabel.centerYAnchor),
            originalTextCopyButton.widthAnchor.constraint(equalToConstant: 20),
            originalTextCopyButton.heightAnchor.constraint(equalToConstant: 20),

            // 原始文本输入框背景
            originalFieldBg.leadingAnchor.constraint(equalTo: base64CoderView.leadingAnchor),
            originalFieldBg.trailingAnchor.constraint(equalTo: base64CoderView.trailingAnchor),
            originalFieldBg.topAnchor.constraint(
                equalTo: originalTextLabel.bottomAnchor, constant: 6),
            originalFieldBg.heightAnchor.constraint(equalToConstant: 150),

            // 原始文本滚动视图
            originalTextScrollView.leadingAnchor.constraint(
                equalTo: originalFieldBg.leadingAnchor, constant: 4),
            originalTextScrollView.trailingAnchor.constraint(
                equalTo: originalFieldBg.trailingAnchor, constant: -4),
            originalTextScrollView.topAnchor.constraint(
                equalTo: originalFieldBg.topAnchor, constant: 4),
            originalTextScrollView.bottomAnchor.constraint(
                equalTo: originalFieldBg.bottomAnchor, constant: -4),

            // Base64 文本标签
            base64TextLabel.leadingAnchor.constraint(equalTo: base64CoderView.leadingAnchor),
            base64TextLabel.topAnchor.constraint(
                equalTo: originalFieldBg.bottomAnchor, constant: 12),

            // Base64 文本复制按钮
            base64TextCopyButton.trailingAnchor.constraint(equalTo: base64CoderView.trailingAnchor),
            base64TextCopyButton.centerYAnchor.constraint(equalTo: base64TextLabel.centerYAnchor),
            base64TextCopyButton.widthAnchor.constraint(equalToConstant: 20),
            base64TextCopyButton.heightAnchor.constraint(equalToConstant: 20),

            // Base64 文本输入框背景
            base64FieldBg.leadingAnchor.constraint(equalTo: base64CoderView.leadingAnchor),
            base64FieldBg.trailingAnchor.constraint(equalTo: base64CoderView.trailingAnchor),
            base64FieldBg.topAnchor.constraint(equalTo: base64TextLabel.bottomAnchor, constant: 6),
            base64FieldBg.heightAnchor.constraint(equalToConstant: 150),

            // Base64 文本滚动视图
            base64TextScrollView.leadingAnchor.constraint(
                equalTo: base64FieldBg.leadingAnchor, constant: 4),
            base64TextScrollView.trailingAnchor.constraint(
                equalTo: base64FieldBg.trailingAnchor, constant: -4),
            base64TextScrollView.topAnchor.constraint(
                equalTo: base64FieldBg.topAnchor, constant: 4),
            base64TextScrollView.bottomAnchor.constraint(
                equalTo: base64FieldBg.bottomAnchor, constant: -4),
        ])

        base64CoderView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor, constant: -12
        ).isActive = true
    }

    @objc private func copyOriginalText() {
        let text = originalTextView.string
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func copyBase64Text() {
        let text = base64TextView.string
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func copyDecodedURL() {
        let text = decodedURLTextView.string
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func copyEncodedURL() {
        let text = encodedURLTextView.string
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func uuidOptionChanged() {
        uuidUseHyphen = (hyphenCheckbox.state == .on)
        generateUUIDs()
    }

    @objc private func uuidCaseChanged(_ sender: NSButton) {
        if sender == uppercaseRadio {
            uppercaseRadio.state = .on
            lowercaseRadio.state = .off
            uuidUppercase = true
        } else {
            uppercaseRadio.state = .off
            lowercaseRadio.state = .on
            uuidUppercase = false
        }
        generateUUIDs()
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

        // 强制立即更新窗口高度，确保在 Simple 模式下启动时不会显示多余高度
        updateVisibility()
    }

    /// 刷新显示模式（Simple/Full）
    private func refreshDisplayMode() {
        // ⚠️ 重要：添加新的扩展模式时，必须在此处添加检查，否则会覆盖扩展模式的结果
        // 如果在扩展模式中，不要覆盖当前显示的结果
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode
            || isInBookmarkMode || isIn2FAMode
        {
            updateVisibility()
            return
        }

        let defaultWindowMode =
            UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"

        if searchField.stringValue.isEmpty {
            if defaultWindowMode == "full" && !recentApps.isEmpty {
                results = recentApps
                isShowingRecents = true
                print(
                    "SearchPanelViewController: refreshDisplayMode set results to recentApps (\(recentApps.count) items)"
                )
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
        // ⚠️ 重要：添加新的扩展模式时，必须在此处添加清理逻辑，否则面板隐藏后状态不会被重置

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
            // 清理 UUID 模式数据
            generatedUUIDs = []
            uuidOptionsView.isHidden = true
            // 清理 URL 编码解码模式数据
            urlCoderView.isHidden = true
            decodedURLTextView.string = ""
            encodedURLTextView.string = ""
            // 清理 Base64 编码解码模式数据
            base64CoderView.isHidden = true
            originalTextView.string = ""
            base64TextView.string = ""
            restoreNormalModeUI()
            searchField.isHidden = false
            setPlaceholder("搜索应用或文档...")
        }

        // 如果在书签模式，先恢复普通模式 UI
        if isInBookmarkMode {
            isInBookmarkMode = false
            bookmarkResults = []
            restoreNormalModeUI()
            setPlaceholder("搜索应用或文档...")
        }

        // 如果在 2FA 模式，先恢复普通模式 UI
        if isIn2FAMode {
            isIn2FAMode = false
            twoFAResults = []
            restoreNormalModeUI()
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

        // 检查是否匹配书签别名（用于显示书签入口）
        let bookmarkEntryResult = checkBookmarkAliasMatch(query: query)

        // 检查是否匹配 2FA 别名（用于显示 2FA 入口）
        let twoFAEntryResult = check2FAAliasMatch(query: query)

        // 根据 LRU 对搜索结果重新排序（传入查询字符串用于别名匹配优先级）
        let sortedResults = sortSearchResults(searchResults, query: query)

        // 构建最终结果
        var finalResults: [SearchResult] = []

        // 扩展入口在最前面（如果匹配别名）
        if let bookmarkEntry = bookmarkEntryResult {
            finalResults.append(bookmarkEntry)
        }
        if let twoFAEntry = twoFAEntryResult {
            finalResults.append(twoFAEntry)
        }

        if sortedResults.isEmpty {
            // 没有搜索结果时，默认搜索显示在最上面
            finalResults.append(contentsOf: filteredDefaultLinks)
        } else {
            // 有搜索结果时，默认搜索显示在最后面
            finalResults.append(contentsOf: sortedResults)
            finalResults.append(contentsOf: filteredDefaultLinks)
        }

        results = finalResults
        selectedIndex = results.isEmpty ? 0 : 0
        tableView.reloadData()
        updateVisibility()

        if !results.isEmpty {
            tableView.selectRowIndexes(
                IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }

    /// 检查书签别名匹配
    /// - Parameter query: 搜索查询
    /// - Returns: 如果匹配，返回书签入口 SearchResult
    private func checkBookmarkAliasMatch(query: String) -> SearchResult? {
        let settings = BookmarkSettings.load()
        guard settings.isEnabled, !settings.alias.isEmpty else { return nil }

        let queryLower = query.lowercased()
        let aliasLower = settings.alias.lowercased()

        // 检查是否匹配别名（前缀匹配或完全匹配）
        guard aliasLower.hasPrefix(queryLower) || queryLower == aliasLower else { return nil }

        // 创建书签入口结果
        let bookmarkIcon =
            NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: "Bookmark")
            ?? NSImage()
        bookmarkIcon.size = NSSize(width: 32, height: 32)

        return SearchResult(
            name: "搜索书签",
            path: "bookmark-entry",
            icon: bookmarkIcon,
            isDirectory: false,
            displayAlias: settings.alias,
            isBookmarkEntry: true
        )
    }

    /// 检查 2FA 别名匹配
    /// - Parameter query: 搜索查询
    /// - Returns: 如果匹配，返回 2FA 入口 SearchResult
    private func check2FAAliasMatch(query: String) -> SearchResult? {
        let settings = TwoFactorAuthSettings.load()
        guard settings.isEnabled, !settings.alias.isEmpty else { return nil }

        let queryLower = query.lowercased()
        let aliasLower = settings.alias.lowercased()

        // 检查是否匹配别名（前缀匹配或完全匹配）
        guard aliasLower.hasPrefix(queryLower) || queryLower == aliasLower else { return nil }

        // 创建 2FA 入口结果
        let twoFAIcon =
            NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "2FA")
            ?? NSImage()
        twoFAIcon.size = NSSize(width: 32, height: 32)

        return SearchResult(
            name: "2FA 短信",
            path: "2fa-entry",
            icon: twoFAIcon,
            isDirectory: false,
            displayAlias: settings.alias,
            is2FAEntry: true
        )
    }

    /// 对搜索结果排序（别名完全匹配 > LRU > 其他）
    private func sortSearchResults(_ results: [SearchResult], query: String) -> [SearchResult] {
        let queryLower = query.lowercased()
        let recentItems = RecentAppsManager.shared.getRecentItems(limit: 30)

        // path -> LRU 顺序映射
        var lruOrder: [String: Int] = [:]
        for (index, item) in recentItems.enumerated() {
            lruOrder[item.identifier] = index
        }

        // 分离结果：别名完全匹配、LRU 结果、其他结果
        var exactAliasMatches: [SearchResult] = []
        var lruResults: [(result: SearchResult, order: Int)] = []
        var otherResults: [SearchResult] = []

        for result in results {
            // 检查别名是否完全匹配
            if let alias = result.displayAlias?.lowercased(), alias == queryLower {
                exactAliasMatches.append(result)
            } else if let order = lruOrder[result.path] {
                lruResults.append((result, order))
            } else {
                otherResults.append(result)
            }
        }

        // LRU 结果按顺序排序
        lruResults.sort { $0.order < $1.order }

        // 别名完全匹配优先 > LRU > 其他
        return exactAliasMatches + lruResults.map { $0.result } + otherResults
    }

    private func updateVisibility() {
        let hasQuery = !searchField.stringValue.isEmpty
        let hasResults = !results.isEmpty
        let defaultWindowMode =
            UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"

        // UUID 模式和 URL 模式使用独立视图，隐藏 scrollView
        let isUUIDMode = isInUtilityMode && currentUtilityIdentifier == "uuid"
        let isURLMode = isInUtilityMode && currentUtilityIdentifier == "url"
        let isBase64Mode = isInUtilityMode && currentUtilityIdentifier == "base64"
        let isIndependentViewMode = isUUIDMode || isURLMode || isBase64Mode

        // 网页直达 Query 模式下，没有输入时不显示结果列表
        let isWebLinkQueryModeEmpty = isInWebLinkQueryMode && !hasQuery

        divider.isHidden = !hasQuery && !isShowingRecents && !isIndependentViewMode
        scrollView.isHidden = !hasResults || isIndependentViewMode || isWebLinkQueryModeEmpty
        noResultsLabel.isHidden = !hasQuery || hasResults || isIndependentViewMode

        // Update window height
        if defaultWindowMode == "full" || isIndependentViewMode {
            // Full 模式或独立视图模式：始终展开
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

        let targetHeight: CGFloat = shouldExpand ? 500 : headerHeight

        // Update the height constraint instead of just the window frame
        contentHeightConstraint?.constant = targetHeight

        let currentFrame = window.frame
        guard abs(currentFrame.height - targetHeight) > 1 else { return }

        let newOriginY = currentFrame.origin.y - (targetHeight - currentFrame.height)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: newOriginY,
            width: currentFrame.width,
            height: targetHeight
        )

        // Disable window's internal constraint updates during frame set
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
        case 51:  // Delete - IDE 项目模式、文件夹打开模式、网页直达 Query 模式、实用工具模式、书签模式或 2FA 模式下，输入框为空时退出
            if isComposing { return event }
            // URL 模式和 Base64 模式使用独立文本框，delete 键由文本框处理，不退出
            if isInUtilityMode
                && (currentUtilityIdentifier == "url" || currentUtilityIdentifier == "base64")
            {
                return event
            }
            if (isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode
                || isInBookmarkMode || isIn2FAMode)
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
                } else if isInBookmarkMode {
                    exitBookmarkMode()
                } else if isIn2FAMode {
                    exit2FAMode()
                }
                return nil
            }
            return event
        case 48:  // Tab - 进入 IDE 项目模式、文件夹打开模式、网页直达 Query 模式或书签模式
            if isComposing { return event }
            if !isInIDEProjectMode && !isInFolderOpenMode && !isInWebLinkQueryMode
                && !isInBookmarkMode && !isIn2FAMode
            {
                // 检查当前选中项是否有扩展功能
                guard results.indices.contains(selectedIndex) else {
                    // 没有选中任何项目，忽略 Tab 键
                    return nil
                }
                let item = results[selectedIndex]

                // 检查是否为书签入口
                if item.isBookmarkEntry {
                    enterBookmarkMode()
                    return nil
                }

                // 检查是否为 2FA 入口
                if item.is2FAEntry {
                    enter2FAMode()
                    return nil
                }

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
            // 记录到 LRU 缓存
            RecentAppsManager.shared.recordWebLinkOpen(url: webLink.path, name: webLink.name)
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
            loadUUIDGenerator()
        case "url":
            loadURLCoder()
        case "base64":
            loadBase64Coder()
        case "kill":
            loadKillModeProcesses()
        default:
            break
        }

        return true
    }

    /// 清理所有扩展模式的 UI（用于切换到不同类型的扩展模式时）
    private func cleanupAllExtensionModes() {
        // 清理 IDE 项目模式
        if isInIDEProjectMode {
            isInIDEProjectMode = false
            currentIDEApp = nil
            currentIDEType = nil
            ideProjects = []
            filteredIDEProjects = []
        }

        // 清理文件夹打开模式
        if isInFolderOpenMode {
            isInFolderOpenMode = false
            currentFolder = nil
            folderOpeners = []
        }

        // 清理网页直达 Query 模式
        if isInWebLinkQueryMode {
            isInWebLinkQueryMode = false
            currentWebLinkResult = nil
        }

        // 清理实用工具模式
        if isInUtilityMode {
            isInUtilityMode = false
            currentUtilityIdentifier = nil
            currentUtilityResult = nil
            cleanupCurrentUtilityModeUI()
        }

        // 清理书签模式
        if isInBookmarkMode {
            isInBookmarkMode = false
            bookmarkResults = []
        }

        // 清理 2FA 模式
        if isIn2FAMode {
            isIn2FAMode = false
            twoFAResults = []
        }

        // 恢复 UI
        restoreNormalModeUI()
        searchField.isHidden = false
    }

    /// 清理当前实用工具模式的 UI（用于切换到其他实用工具时）
    private func cleanupCurrentUtilityModeUI() {
        // 清理 kill 模式数据
        killModeApps = []
        killModePorts = []
        killModeAllItems = []
        killModeFilteredItems = []

        // 清理 UUID 模式数据和 UI
        generatedUUIDs = []
        uuidOptionsView.isHidden = true
        uuidResultView.isHidden = true

        // 清理 URL 编码解码模式数据和 UI
        urlCoderView.isHidden = true
        decodedURLTextView.string = ""
        encodedURLTextView.string = ""

        // 清理 Base64 编码解码模式数据和 UI
        base64CoderView.isHidden = true
        originalTextView.string = ""
        base64TextView.string = ""

        // 清理 IP 查询数据
        ipQueryResults = []

        // 清理搜索框
        searchField.stringValue = ""

        // 清理表格数据
        results = []
        tableView.reloadData()
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

        // 清理 UUID 模式数据
        generatedUUIDs = []
        uuidOptionsView.isHidden = true

        // 清理 URL 编码解码模式数据
        urlCoderView.isHidden = true

        // 清理 Base64 编码解码模式数据
        base64CoderView.isHidden = true

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
        // kill 模式需要搜索，uuid 模式需要输入数量，其他模式（如 IP 查询）不需要
        if currentUtilityIdentifier == "kill" {
            searchField.isHidden = false
            searchField.stringValue = ""
            setPlaceholder("请输入关键词搜索")
        } else if currentUtilityIdentifier == "uuid" {
            searchField.isHidden = false
            // uuid 模式的 placeholder 在 loadUUIDGenerator 中设置
        } else {
            searchField.isHidden = true
        }
    }

    // MARK: - UUID 生成器方法

    /// 加载 UUID 生成器
    private func loadUUIDGenerator() {
        // 显示 UUID 选项视图
        uuidOptionsView.isHidden = false
        scrollView.isHidden = true
        divider.isHidden = false

        // 重置选项状态
        hyphenCheckbox.state = uuidUseHyphen ? .on : .off
        uppercaseRadio.state = uuidUppercase ? .on : .off
        lowercaseRadio.state = uuidUppercase ? .off : .on

        // 设置搜索框用于输入数量
        searchField.stringValue = ""
        setPlaceholder("1-1000")

        // 确保搜索框获取焦点
        view.window?.makeFirstResponder(searchField)

        // 生成初始 UUID
        generateUUIDs()

        // 更新窗口高度
        updateWindowHeight(expanded: true)
    }

    /// 生成 UUID 列表
    private func generateUUIDs() {
        // 从搜索框获取数量
        let inputText = searchField.stringValue
        if let count = Int(inputText), count > 0, count <= 1000 {
            uuidCount = count
        } else if inputText.isEmpty {
            uuidCount = 1
        } else {
            uuidCount = min(max(1, Int(inputText) ?? 1), 1000)
        }

        // 生成 UUID
        generatedUUIDs = (0..<uuidCount).map { _ in
            var uuid = UUID().uuidString
            if !uuidUseHyphen {
                uuid = uuid.replacingOccurrences(of: "-", with: "")
            }
            if !uuidUppercase {
                uuid = uuid.lowercased()
            }
            return uuid
        }

        // 更新文本视图
        let text = generatedUUIDs.joined(separator: "\n")
        uuidResultTextView.string = text

        // 确保文本视图大小正确
        if let container = uuidResultTextView.textContainer,
            let layoutManager = uuidResultTextView.layoutManager
        {
            layoutManager.ensureLayout(for: container)
            let size = layoutManager.usedRect(for: container).size
            uuidResultTextView.setFrameSize(
                NSSize(
                    width: uuidResultView.contentSize.width,
                    height: max(size.height + 16, uuidResultView.contentSize.height)
                ))
        }
    }

    /// 复制所有 UUID 到剪贴板
    private func copyAllUUIDs() {
        guard !generatedUUIDs.isEmpty else { return }
        let text = generatedUUIDs.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // 关闭面板
        PanelManager.shared.hidePanel()
    }

    // MARK: - URL 编码解码方法

    /// 加载 URL 编码解码工具
    private func loadURLCoder() {
        // 显示 URL 编码解码视图
        urlCoderView.isHidden = false
        scrollView.isHidden = true
        divider.isHidden = false

        // 清空输入框
        decodedURLTextView.string = ""
        encodedURLTextView.string = ""

        // 更新窗口高度
        updateWindowHeight(expanded: true)

        // 延迟让解码输入框获取焦点（确保窗口已显示）
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.decodedURLTextView)
        }
    }

    /// 处理解码输入框变化 - 编码 URL
    private func encodeURL() {
        let decoded = decodedURLTextView.string
        if decoded.isEmpty {
            encodedURLTextView.string = ""
            return
        }
        // URL 编码
        if let encoded = decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            encodedURLTextView.string = encoded
        }
    }

    /// 处理编码输入框变化 - 解码 URL
    private func decodeURL() {
        let encoded = encodedURLTextView.string
        if encoded.isEmpty {
            decodedURLTextView.string = ""
            return
        }
        // URL 解码
        if let decoded = encoded.removingPercentEncoding {
            decodedURLTextView.string = decoded
        }
    }

    // MARK: - Base64 编码解码方法

    /// 加载 Base64 编码解码工具
    private func loadBase64Coder() {
        // 显示 Base64 编码解码视图
        base64CoderView.isHidden = false
        scrollView.isHidden = true
        divider.isHidden = false

        // 清空输入框
        originalTextView.string = ""
        base64TextView.string = ""

        // 更新窗口高度
        updateWindowHeight(expanded: true)

        // 延迟让原始文本输入框获取焦点（确保窗口已显示）
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.originalTextView)
        }
    }

    /// 处理原始文本变化 - 编码为 Base64
    private func encodeBase64() {
        let original = originalTextView.string
        if original.isEmpty {
            base64TextView.string = ""
            return
        }
        // Base64 编码
        if let data = original.data(using: .utf8) {
            base64TextView.string = data.base64EncodedString()
        }
    }

    /// 处理 Base64 文本变化 - 解码为原始文本
    private func decodeBase64() {
        let base64 = base64TextView.string
        if base64.isEmpty {
            originalTextView.string = ""
            return
        }
        // Base64 解码
        if let data = Data(base64Encoded: base64),
            let decoded = String(data: data, encoding: .utf8)
        {
            originalTextView.string = decoded
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
        case "uuid":
            // 复制所有 UUID
            copyAllUUIDs()
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

        // 激活应用以确保弹窗获得焦点并支持回车确认
        NSApp.activate(ignoringOtherApps: true)
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
                NSApp.activate(ignoringOtherApps: true)
                failAlert.runModal()
            }
        }
    }

    /// 滚动表格使选中行尽量保持在可视区域中间
    private func scrollToKeepSelectionCentered() {
        guard selectedIndex >= 0 else { return }

        let visibleRect = scrollView.contentView.bounds
        let selectedRect = tableView.rect(ofRow: selectedIndex)

        // 计算目标滚动位置，使选中行在中间
        // targetY = 选中行中心点 - 可视区域高度的一半
        let targetY = selectedRect.midY - (visibleRect.height / 2)

        // 边界处理：确保不会滚动超出范围
        let maxY = max(0, tableView.frame.height - visibleRect.height)
        let clampedY = max(0, min(targetY, maxY))

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// 加载最近使用的项目（支持所有工具类型）
    private func loadRecentApps() {
        // ⚠️ 重要：添加新的扩展模式时，必须在此处添加检查，否则会在扩展模式下加载最近项目
        // 如果已经在扩展模式中，不加载最近项目
        if isInIDEProjectMode || isInFolderOpenMode || isInWebLinkQueryMode || isInUtilityMode
            || isInBookmarkMode || isIn2FAMode
        {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var items: [SearchResult] = []
            var addedKeys = Set<String>()

            // 获取工具配置用于查找别名等信息
            let config = ToolsConfig.load()

            // 1. 从 LRU 缓存获取最近使用的项目（最多 8 个）
            let recentItems = RecentAppsManager.shared.getRecentItems(limit: 8)

            for item in recentItems {
                guard !addedKeys.contains(item.uniqueKey) else { continue }

                if let result = self?.createSearchResultFromRecentItem(item, config: config) {
                    items.append(result)
                    addedKeys.insert(item.uniqueKey)
                }
            }

            // 2. 如果 LRU 记录不足 8 个，用默认应用补充
            if items.count < 8 {
                let defaultApps = [
                    "/System/Library/CoreServices/Finder.app",
                    "/System/Applications/System Settings.app",
                    "/System/Applications/Notes.app",
                    "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
                    "/System/Applications/App Store.app",
                    "/System/Applications/Mail.app",
                    "/System/Applications/Calendar.app",
                    "/System/Applications/Messages.app",
                ]

                for path in defaultApps {
                    guard items.count < 8 else { break }
                    let key = "app:\(path)"
                    guard !addedKeys.contains(key) else { continue }
                    guard FileManager.default.fileExists(atPath: path) else { continue }

                    if let result = self?.createSearchResult(from: path) {
                        items.append(result)
                        addedKeys.insert(key)
                    }
                }
            }

            DispatchQueue.main.async {
                // ⚠️ 重要：添加新的扩展模式时，必须在此处添加检查，否则异步回调会覆盖扩展模式的结果
                // 再次检查是否在扩展模式，避免覆盖扩展模式的结果列表
                guard
                    self?.isInIDEProjectMode != true && self?.isInFolderOpenMode != true
                        && self?.isInWebLinkQueryMode != true && self?.isInUtilityMode != true
                        && self?.isInBookmarkMode != true && self?.isIn2FAMode != true
                else {
                    return
                }

                self?.recentApps = items

                // 如果是 Full 模式且当前没有搜索内容，显示最近项目
                let defaultWindowMode =
                    UserDefaults.standard.string(forKey: "defaultWindowMode") ?? "full"
                if defaultWindowMode == "full" && self?.searchField.stringValue.isEmpty == true {
                    self?.results = items
                    self?.isShowingRecents = true
                    self?.tableView.reloadData()
                    self?.updateVisibility()
                }
            }
        }
    }

    /// 从 RecentItem 创建 SearchResult
    private func createSearchResultFromRecentItem(_ item: RecentItem, config: ToolsConfig)
        -> SearchResult?
    {
        switch item.type {
        case .app:
            return createSearchResult(from: item.identifier)

        case .webLink:
            // 查找对应的 ToolItem 获取完整信息
            if let tool = config.tools.first(where: {
                $0.type == .webLink && $0.url == item.identifier
            }) {
                let icon = tool.icon
                icon.size = NSSize(width: 32, height: 32)
                return SearchResult(
                    name: tool.name,
                    path: item.identifier,
                    icon: icon,
                    isDirectory: false,
                    displayAlias: tool.alias,
                    isWebLink: true,
                    supportsQueryExtension: tool.supportsQueryExtension,
                    defaultUrl: tool.defaultUrl
                )
            }
            return nil

        case .utility:
            // 查找对应的 ToolItem
            if let tool = config.tools.first(where: {
                $0.type == .utility && $0.extensionIdentifier == item.identifier
            }) {
                let icon = tool.icon
                icon.size = NSSize(width: 32, height: 32)
                return SearchResult(
                    name: tool.name,
                    path: item.identifier,
                    icon: icon,
                    isDirectory: false,
                    displayAlias: tool.alias,
                    isUtility: true,
                    supportsQueryExtension: true
                )
            }
            return nil

        case .systemCommand:
            // 查找对应的 ToolItem
            if let tool = config.tools.first(where: {
                $0.type == .systemCommand && $0.command == item.identifier
            }) {
                let icon = tool.icon
                icon.size = NSSize(width: 32, height: 32)
                return SearchResult(
                    name: tool.displayName,
                    path: item.identifier,
                    icon: icon,
                    isDirectory: false,
                    displayAlias: tool.alias,
                    isSystemCommand: true
                )
            }
            return nil
        }
    }

    /// 从路径创建 SearchResult
    private func createSearchResult(from path: String) -> SearchResult? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let name = FileManager.default.getAppDisplayName(at: path)
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
            // 记录 IDE 应用到 LRU 缓存
            RecentAppsManager.shared.recordAppOpen(path: ideApp.path)
            PanelManager.shared.hidePanel()
            return
        }

        // 文件夹打开模式：使用选中的应用打开文件夹
        if isInFolderOpenMode, let folder = currentFolder {
            IDERecentProjectsService.shared.openFolder(folder.path, withApp: item.path)
            // 记录打开文件夹的应用到 LRU 缓存
            RecentAppsManager.shared.recordAppOpen(path: item.path)
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
                // 记录到 LRU 缓存
                RecentAppsManager.shared.recordWebLinkOpen(url: item.path, name: item.name)
            }
            PanelManager.shared.hidePanel()
            return
        }

        // 系统命令：执行对应的系统操作
        if item.isSystemCommand {
            // 记录到 LRU 缓存
            RecentAppsManager.shared.recordSystemCommandOpen(command: item.path, name: item.name)
            // 先隐藏面板，避免弹窗被遮挡
            PanelManager.shared.hidePanel()
            // 执行系统命令（path 存储的是命令标识符）
            SystemCommandService.shared.execute(identifier: item.path) { success in
                if success {
                    print(
                        "SearchPanelViewController: System command '\(item.path)' executed successfully"
                    )
                } else {
                    print(
                        "SearchPanelViewController: System command '\(item.path)' failed or was cancelled"
                    )
                }
            }
            return
        }

        // 实用工具：进入扩展模式
        if item.isUtility {
            // 记录到 LRU 缓存
            RecentAppsManager.shared.recordUtilityOpen(identifier: item.path, name: item.name)
            // 通过搜索结果中的 path 获取工具信息
            let toolsConfig = ToolsConfig.load()
            if let tool = toolsConfig.enabledTools.first(where: {
                $0.extensionIdentifier == item.path
            }) {
                PanelManager.shared.showPanelInUtilityMode(tool: tool)
            }
            return
        }

        // 书签入口：进入书签搜索模式
        if item.isBookmarkEntry {
            enterBookmarkMode()
            return
        }

        // 2FA 入口：进入 2FA 搜索模式
        if item.is2FAEntry {
            enter2FAMode()
            return
        }

        // 书签：打开书签 URL
        if item.isBookmark {
            BookmarkService.shared.open(
                BookmarkItem(
                    title: item.name,
                    url: item.path,
                    source: item.bookmarkSource == "Chrome" ? .chrome : .safari
                ))
            PanelManager.shared.hidePanel()
            return
        }

        // 2FA 验证码：复制到剪贴板
        if item.is2FACode {
            // 从 twoFAResults 中找到对应的验证码
            if let codeItem = twoFAResults.first(where: { "验证码: \($0.code)" == item.name }) {
                codeItem.copyToClipboard()

                // 如果设置了复制后删除短信，则从列表移除并删除短信
                let settings = TwoFactorAuthSettings.load()
                if settings.deleteAfterCopy {
                    // 从列表中移除并刷新界面
                    twoFAResults.removeAll { $0.messageRowId == codeItem.messageRowId }
                    results.removeAll { $0.name == item.name }
                    tableView.reloadData()

                    // 更新选中状态
                    if !results.isEmpty {
                        selectedIndex = min(selectedIndex, results.count - 1)
                        tableView.selectRowIndexes(
                            IndexSet(integer: selectedIndex), byExtendingSelection: false)
                    }

                    // 异步删除短信（不阻塞 UI）
                    let rowId = codeItem.messageRowId
                    DispatchQueue.global(qos: .background).async {
                        _ = TwoFactorAuthService.shared.deleteMessage(rowId: rowId)
                    }
                }
            }
            PanelManager.shared.hidePanel()
            return
        }

        // 普通模式：使用默认应用打开
        let url = URL(fileURLWithPath: item.path)

        // 记录到 LRU 缓存（仅记录 .app 应用）
        if item.path.hasSuffix(".app") {
            RecentAppsManager.shared.recordAppOpen(path: item.path)
        }

        // 先隐藏面板，再异步打开 app（避免权限弹窗阻塞面板关闭）
        PanelManager.shared.hidePanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSWorkspace.shared.open(url)
        }
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
            } else if currentUtilityIdentifier == "uuid" {
                // UUID 模式：防抖处理数量变化
                uuidDebounceWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.generateUUIDs()
                }
                uuidDebounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
            }
            // 其他实用工具模式不进行搜索
            return
        }

        // 书签模式：搜索书签
        if isInBookmarkMode {
            performBookmarkSearch(query)
            return
        }

        // 2FA 模式：搜索验证码
        if isIn2FAMode {
            perform2FASearch(query)
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

// MARK: - NSTextViewDelegate

extension SearchPanelViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }

        if textView == decodedURLTextView {
            // 解码输入框变化 -> 编码
            urlCoderDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.encodeURL()
            }
            urlCoderDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        } else if textView == encodedURLTextView {
            // 编码输入框变化 -> 解码
            urlCoderDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.decodeURL()
            }
            urlCoderDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        } else if textView == originalTextView {
            // 原始文本变化 -> Base64 编码
            base64CoderDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.encodeBase64()
            }
            base64CoderDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        } else if textView == base64TextView {
            // Base64 文本变化 -> 解码
            base64CoderDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.decodeBase64()
            }
            base64CoderDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
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
    private var pathLabelTrailingToArrow: NSLayoutConstraint!
    private var pathLabelTrailingToEdge: NSLayoutConstraint!

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

        // App、网页直达、实用工具、系统命令、书签入口、2FA 入口只显示名称（垂直居中、字体大），文件和文件夹显示路径
        let isApp = item.path.hasSuffix(".app")
        let isWebLink = item.isWebLink
        let isUtility = item.isUtility
        let isSystemCommand = item.isSystemCommand
        let isBookmarkEntry = item.isBookmarkEntry
        let is2FAEntry = item.is2FAEntry
        let showPathLabel =
            !isApp && !isWebLink && !isUtility && !isSystemCommand && !isBookmarkEntry
            && !is2FAEntry && !hasProcessStats
        pathLabel.isHidden = !showPathLabel
        pathLabel.stringValue = showPathLabel ? item.path : ""

        // 检测是否为支持的 IDE、文件夹、网页直达 Query 扩展、实用工具、书签入口或 2FA 入口，显示箭头指示器
        // hideArrow 为 true 时强制隐藏（如文件夹打开模式下）
        // 有进程统计信息时也隐藏箭头
        let isIDE = IDEType.detect(from: item.path) != nil
        let isFolder = item.isDirectory && !isApp
        let isQueryWebLink = item.isWebLink && item.supportsQueryExtension
        let showArrow =
            !hideArrow && !hasProcessStats
            && (isIDE || isFolder || isQueryWebLink || isUtility || isBookmarkEntry || is2FAEntry)
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

        // 切换布局：App、网页直达、实用工具、系统命令、书签入口、2FA 入口、有进程统计的项垂直居中，其他顶部对齐
        if isApp || isWebLink || isUtility || isSystemCommand || isBookmarkEntry || is2FAEntry
            || hasProcessStats
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
