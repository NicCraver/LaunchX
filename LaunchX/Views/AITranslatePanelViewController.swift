import AppKit
import Combine
import Foundation

/// AI 翻译面板视图控制器
class AITranslatePanelViewController: NSViewController {

    // MARK: - UI 组件

    var containerView: NSView?
    private var titleBar: NSView?
    private var titleLabel: NSTextField?

    private var pinButton: NSButton?

    private var inputScrollView: NSScrollView?
    private var inputTextView: NSTextView?
    private var inputPlaceholder: NSTextField?
    private var inputHeightConstraint: NSLayoutConstraint?

    private var languageBar: NSView?
    private var fromLangButton: NSButton?
    private var swapButton: NSButton?
    private var toLangButton: NSButton?

    private var resultScrollView: NSScrollView?
    private var resultStackView: NSStackView?
    private var resultHeightConstraint: NSLayoutConstraint?

    private var loadingIndicator: NSProgressIndicator?

    // 是否有翻译结果
    private var hasTranslationResult: Bool = false

    /// 内容高度变化回调
    var onContentHeightChanged: ((CGFloat) -> Void)?

    // 语言菜单
    private var fromLangMenu: NSMenu?
    private var toLangMenu: NSMenu?

    // MARK: - 状态

    private var settings = AITranslateSettings.load()
    private var fromLang: TranslateLanguage = TranslateLanguage.auto
    private var toLang: TranslateLanguage = TranslateLanguage.auto
    private var cancellables = Set<AnyCancellable>()

    // 输入框高度限制
    private let inputMinHeight: CGFloat = 60
    private let inputMaxHeight: CGFloat = 120

    // MARK: - 生命周期

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        loadSettings()

        // 监听液态玻璃设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiquidGlassSettingDidChange),
            name: NSNotification.Name("enableLiquidGlassDidChange"),
            object: nil
        )
    }

    /// 处理液态玻璃设置变化
    @objc private func handleLiquidGlassSettingDidChange() {
        let useLiquidGlass =
            UserDefaults.standard.object(forKey: "enableLiquidGlass") as? Bool ?? true

        // 动态更新毛玻璃材质以实现即时生效
        if let visualEffectView = self.containerView as? NSVisualEffectView {
            visualEffectView.material = useLiquidGlass ? .sidebar : .popover
        }
    }

    deinit {
        // 清理 Combine 订阅
        cancellables.removeAll()

        // 移除所有通知观察者
        NotificationCenter.default.removeObserver(self)

        // 清理 NSTextView delegate
        inputTextView?.delegate = nil
    }

    // MARK: - UI 设置

    private func setupUI() {
        let useLiquidGlass =
            UserDefaults.standard.object(forKey: "enableLiquidGlass") as? Bool ?? true
        let container: NSView

        if #available(macOS 26.0, *), useLiquidGlass {
            let glassEffectView = NSGlassEffectView()
            glassEffectView.style = .clear
            glassEffectView.tintColor = NSColor(named: "PanelBackgroundColor")
            glassEffectView.wantsLayer = true
            glassEffectView.layer?.cornerRadius = 20
            glassEffectView.layer?.masksToBounds = true
            container = glassEffectView
        } else {
            // 容器视图（毛玻璃效果）
            let visualEffectView = NSVisualEffectView(frame: view.bounds)
            // 如果开启了液态玻璃但在旧版本系统，使用更透明的 material 模拟
            visualEffectView.material = useLiquidGlass ? .sidebar : .popover
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 20
            container = visualEffectView
        }

        container.frame = view.bounds
        container.autoresizingMask = [.width, .height]
        view.addSubview(container)
        self.containerView = container

        setupTitleBar()
        setupInputArea()
        setupLanguageBar()
        setupResultArea()
        setupLoadingIndicator()
    }

    private func setupTitleBar() {
        guard let containerView = containerView else { return }

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bar)
        self.titleBar = bar

        // 标题
        let label = NSTextField(labelWithString: "AI 翻译")
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(label)
        self.titleLabel = label

        // 固定按钮
        let btn = NSButton()
        btn.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "固定")
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.target = self
        btn.action = #selector(togglePin)
        btn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(btn)
        self.pinButton = btn

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: containerView.topAnchor),
            bar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),

            label.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),

            btn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            btn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            btn.widthAnchor.constraint(equalToConstant: 24),
            btn.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setupInputArea() {
        guard let containerView = containerView, let titleBar = titleBar else { return }

        // 输入滚动视图
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.backgroundColor = .clear
        scroll.drawsBackground = false
        scroll.horizontalScrollElasticity = .none
        scroll.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scroll)
        self.inputScrollView = scroll

        // 输入文本视图
        let tv = NSTextView()
        tv.minSize = NSSize(width: 0, height: inputMinHeight)
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.font = .systemFont(ofSize: 15)
        tv.textColor = .labelColor
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.delegate = self
        scroll.documentView = tv
        self.inputTextView = tv

        // 占位符
        let placeholder = NSTextField(labelWithString: "输入文本并按回车，↑↓ 翻看历史记录")
        placeholder.font = .systemFont(ofSize: 15)
        placeholder.textColor = NSColor.placeholderTextColor
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(placeholder)
        self.inputPlaceholder = placeholder

        let constraint = scroll.heightAnchor.constraint(equalToConstant: inputMinHeight)
        self.inputHeightConstraint = constraint

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: titleBar.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -16),
            constraint,

            placeholder.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 0),
            placeholder.leadingAnchor.constraint(
                equalTo: scroll.leadingAnchor, constant: 5),
        ])
    }

    private func setupLanguageBar() {
        guard let containerView = containerView, let inputScrollView = inputScrollView else {
            return
        }

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bar)
        self.languageBar = bar

        // 源语言选择按钮
        let fromBtn = createLanguageButton()
        fromBtn.target = self
        fromBtn.action = #selector(showFromLangMenu(_:))
        bar.addSubview(fromBtn)
        self.fromLangButton = fromBtn

        // 交换按钮
        let sBtn = NSButton()
        sBtn.image = NSImage(
            systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "交换")
        sBtn.bezelStyle = .inline
        sBtn.isBordered = false
        sBtn.contentTintColor = .secondaryLabelColor
        sBtn.target = self
        sBtn.action = #selector(swapLanguages)
        sBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(sBtn)
        self.swapButton = sBtn

        // 目标语言选择按钮
        let toBtn = createLanguageButton()
        toBtn.target = self
        toBtn.action = #selector(showToLangMenu(_:))
        bar.addSubview(toBtn)
        self.toLangButton = toBtn

        // 创建语言菜单
        self.fromLangMenu = createLanguageMenu(isSource: true)
        self.toLangMenu = createLanguageMenu(isSource: false)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: inputScrollView.bottomAnchor, constant: 8),
            bar.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -16),
            bar.heightAnchor.constraint(equalToConstant: 40),

            fromBtn.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            fromBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            fromBtn.trailingAnchor.constraint(
                equalTo: sBtn.leadingAnchor, constant: -12),
            fromBtn.heightAnchor.constraint(equalToConstant: 36),

            sBtn.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            sBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            sBtn.widthAnchor.constraint(equalToConstant: 32),
            sBtn.heightAnchor.constraint(equalToConstant: 32),

            toBtn.leadingAnchor.constraint(equalTo: sBtn.trailingAnchor, constant: 12),
            toBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            toBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            toBtn.heightAnchor.constraint(equalToConstant: 36),
            toBtn.widthAnchor.constraint(equalTo: fromBtn.widthAnchor),
        ])

        updateLanguageButtons()
    }

    private func createLanguageButton() -> NSButton {
        let button = NSButton()
        button.bezelStyle = .smallSquare
        button.isBordered = false
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .labelColor
        button.wantsLayer = true
        button.layer?.cornerRadius = 18
        button.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1.0).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func createLanguageMenu(isSource: Bool) -> NSMenu {
        let menu = NSMenu()
        for lang: TranslateLanguage in TranslateLanguage.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: isSource ? #selector(selectFromLang(_:)) : #selector(selectToLang(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            menu.addItem(item)
        }
        return menu
    }

    private func setupResultArea() {
        guard let containerView = containerView, let languageBar = languageBar else { return }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.backgroundColor = .clear
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scroll)
        self.resultScrollView = scroll

        // 使用 flipped view 让内容从顶部开始
        let flippedContainer = FlippedView()
        flippedContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.setHuggingPriority(.required, for: .vertical)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.defaultLow, for: .horizontal)
        flippedContainer.addSubview(stack)
        self.resultStackView = stack

        // 让 flippedContainer 自动适应 stackView 的高度，确保点击事件能穿透到子视图
        NSLayoutConstraint.activate([
            stack.bottomAnchor.constraint(equalTo: flippedContainer.bottomAnchor)
        ])

        scroll.documentView = flippedContainer

        // 初始状态下结果区域高度为 0（优先级低于底部约束，这样展开时可以正常工作）
        let constraint = scroll.heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = .defaultHigh
        self.resultHeightConstraint = constraint

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: languageBar.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scroll.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor, constant: -8),

            stack.topAnchor.constraint(equalTo: flippedContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: flippedContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: flippedContainer.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: flippedContainer.widthAnchor),

            flippedContainer.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        // 初始激活高度约束
        constraint.isActive = true

        // 初始状态隐藏结果区域
        scroll.isHidden = true
    }

    private func setupLoadingIndicator() {
        guard let containerView = containerView, let titleBar = titleBar, let pinButton = pinButton
        else { return }

        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isHidden = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(indicator)
        self.loadingIndicator = indicator

        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            indicator.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -8),
            indicator.widthAnchor.constraint(equalToConstant: 16),
            indicator.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    // MARK: - 数据绑定

    private func setupBindings() {
        AITranslateService.shared.$isTranslating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isTranslating in
                self?.updateLoadingState(isTranslating)
            }
            .store(in: &cancellables)
    }

    private func loadSettings() {
        settings = AITranslateSettings.load()
        fromLang = settings.defaultFromLang
        toLang = settings.defaultToLang
        updateLanguageButtons()
        updateServicesDisplay()
    }

    /// 刷新设置（面板显示时调用）
    func reloadSettings() {
        settings = AITranslateSettings.load()
        // 不再自动显示服务列表，等有翻译结果时再显示
    }

    /// 重置面板状态（清空输入和结果）
    func resetPanelState() {
        // 清空输入
        if let tv = inputTextView {
            tv.string = ""
        }
        if let placeholder = inputPlaceholder {
            placeholder.isHidden = false
        }
        updateInputHeight()

        // 清空结果
        if let stack = resultStackView {
            for view in stack.arrangedSubviews {
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        // 收起结果区域
        hasTranslationResult = false
        collapseResultArea()
    }

    /// 收起结果区域
    private func collapseResultArea() {
        if let scrollView = resultScrollView {
            scrollView.isHidden = true
        }
        if let constraint = resultHeightConstraint {
            constraint.isActive = true
        }
        view.layoutSubtreeIfNeeded()

        // 调整窗口为紧凑高度
        if let window = view.window {
            let compactHeight: CGFloat = 180
            var frame = window.frame
            if frame.height > compactHeight {
                frame.origin.y += (frame.height - compactHeight)
                frame.size.height = compactHeight
                window.setFrame(frame, display: true, animate: true)
            }
        }
    }

    // MARK: - 公开方法

    func setInputText(_ text: String) {
        inputTextView?.string = text
        inputPlaceholder?.isHidden = !text.isEmpty
        updateInputHeight()
    }

    func focusInput() {
        if let tv = inputTextView {
            view.window?.makeFirstResponder(tv)
        }
    }

    func performTranslation() {
        guard let tv = inputTextView else { return }
        let text = tv.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        translate(text: text)
    }

    func updatePinnedState(_ isPinned: Bool) {
        let imageName = isPinned ? "pin.fill" : "pin"
        if let btn = pinButton {
            btn.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "固定")
        }
    }

    // MARK: - 输入框高度自适应

    private func updateInputHeight() {
        guard let tv = inputTextView,
            let layoutManager = tv.layoutManager,
            let textContainer = tv.textContainer
        else { return }

        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let newHeight = min(max(textHeight + 8, inputMinHeight), inputMaxHeight)

        if let constraint = inputHeightConstraint {
            if constraint.constant != newHeight {
                constraint.constant = newHeight
                view.layoutSubtreeIfNeeded()
                updateContentHeight()
            }
        }
    }

    // MARK: - 翻译逻辑

    private func translate(text: String) {
        // 重新加载设置确保最新
        settings = AITranslateSettings.load()

        guard
            let modelConfig = settings.modelConfigs.first(where: { $0.isDefault })
                ?? settings.modelConfigs.first
        else {
            showError("请先在设置中配置 AI 模型")
            return
        }

        let isSingleWord = AITranslateService.shared.isSingleWord(text)
        let detectedLang = AITranslateService.shared.detectLanguage(text)
        let isEnglishToChineseWord = isSingleWord && detectedLang == .english

        // 根据是否为单词决定显示哪些服务
        showServicesWithLoading(showWordTranslate: isEnglishToChineseWord)

        // 开始新的翻译会话
        AITranslateService.shared.startNewTranslation(
            text: text, fromLang: fromLang, toLang: toLang)

        // 执行 AI 翻译
        if let aiConfig = settings.serviceConfigs.first(where: {
            $0.serviceType == .aiTranslate && $0.isEnabled
        }) {
            translateWithService(
                text: text, serviceConfig: aiConfig, modelConfig: modelConfig,
                isWordMode: isEnglishToChineseWord)
        }

        // 只有英文单词才执行单词翻译
        if isEnglishToChineseWord {
            if let wordConfig = settings.serviceConfigs.first(where: {
                $0.serviceType == .wordTranslate && $0.isEnabled
            }) {
                translateWithService(
                    text: text, serviceConfig: wordConfig, modelConfig: modelConfig,
                    isWordMode: false)
            }
        }
    }

    private func translateWithService(
        text: String,
        serviceConfig: TranslateServiceConfig,
        modelConfig: AIModelConfig,
        isWordMode: Bool = false
    ) {
        var effectiveServiceConfig = serviceConfig

        // 单词模式下，AI 翻译使用特殊的例句 prompt
        if isWordMode && serviceConfig.serviceType == .aiTranslate {
            effectiveServiceConfig = TranslateServiceConfig(
                id: serviceConfig.id,
                name: serviceConfig.name,
                serviceType: serviceConfig.serviceType,
                systemPrompt:
                    "You are a language learning assistant. When given an English word, provide 2-3 example sentences showing how native speakers use this word in daily life or popular TV shows/movies. Format: just the English sentences with Chinese translations, no explanations needed. Keep it concise.",
                userPromptTemplate:
                    "Give me 2-3 natural example sentences for the word \"{text}\" as used by native English speakers in daily conversation or TV shows/movies. Include Chinese translation for each sentence.",
                modelConfigId: serviceConfig.modelConfigId,
                isEnabled: serviceConfig.isEnabled
            )
        }
        // 其他情况使用用户配置的 prompt

        AITranslateService.shared.translate(
            text: text,
            fromLang: fromLang,
            toLang: toLang,
            serviceConfig: effectiveServiceConfig,
            modelConfig: modelConfig
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let translation):
                self.updateServiceResult(
                    serviceConfig: serviceConfig, content: translation, isError: false)
            case .failure(let error):
                self.updateServiceResult(
                    serviceConfig: serviceConfig, content: error.localizedDescription, isError: true
                )
            }
        }
    }

    // MARK: - 服务显示

    private func updateServicesDisplay() {
        guard let stack = resultStackView else { return }

        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let enabledServices = settings.serviceConfigs.filter { $0.isEnabled }

        if enabledServices.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "暂无启用的翻译服务")
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false

            let wrapper = NSView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                emptyLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 16),
                emptyLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                emptyLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -16),
            ])
            stack.addArrangedSubview(wrapper)
            return
        }

        for (index, service) in enabledServices.enumerated() {
            let serviceView = createServiceRowView(service: service, isLoading: false, content: nil)
            stack.addArrangedSubview(serviceView)
            serviceView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            if index < enabledServices.count - 1 {
                let separator = createSeparator()
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive =
                    true
            }
        }
    }

    private func showServicesWithLoading(showWordTranslate: Bool) {
        guard let stack = resultStackView else { return }

        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // 根据参数过滤要显示的服务
        var enabledServices = settings.serviceConfigs.filter { config in
            guard config.isEnabled else { return false }
            if config.serviceType == .wordTranslate && !showWordTranslate {
                return false
            }
            return true
        }

        // 固定顺序：单词翻译在前，AI翻译在后
        enabledServices.sort { s1, s2 in
            if s1.serviceType == .wordTranslate && s2.serviceType != .wordTranslate {
                return true
            }
            if s1.serviceType != .wordTranslate && s2.serviceType == .wordTranslate {
                return false
            }
            return false
        }

        for (index, service) in enabledServices.enumerated() {
            let serviceView = createServiceRowView(service: service, isLoading: true, content: nil)
            serviceView.identifier = NSUserInterfaceItemIdentifier("service_\(service.id)")
            stack.addArrangedSubview(serviceView)
            serviceView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            if index < enabledServices.count - 1 {
                let separator = createSeparator()
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive =
                    true
            }
        }

        // 展开结果区域
        hasTranslationResult = true
        expandResultArea()
    }

    /// 展开结果区域
    private func expandResultArea() {
        if let scrollView = resultScrollView {
            scrollView.isHidden = false
        }
        if let constraint = resultHeightConstraint {
            constraint.isActive = false
        }
        view.layoutSubtreeIfNeeded()

        // 延迟计算内容高度，等布局完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateContentHeight()
        }
    }

    /// 计算并更新内容高度
    private func updateContentHeight() {
        view.layoutSubtreeIfNeeded()

        // 计算各部分高度
        let titleBarHeight: CGFloat = 44
        let inputHeight: CGFloat = inputHeightConstraint?.constant ?? 60
        let languageBarHeight: CGFloat = 40
        let padding: CGFloat = 30  // 上下间距

        // 计算结果区域的实际内容高度
        var resultContentHeight: CGFloat = 0
        if let stack = resultStackView {
            for subview in stack.arrangedSubviews {
                resultContentHeight += subview.fittingSize.height
            }
        }

        // 给结果区域一些额外空间
        resultContentHeight += 16

        let totalHeight =
            titleBarHeight + inputHeight + languageBarHeight + resultContentHeight + padding

        // 回调通知面板调整高度
        onContentHeightChanged?(totalHeight)
    }

    private func updateServiceResult(
        serviceConfig: TranslateServiceConfig, content: String, isError: Bool
    ) {
        guard let stack = resultStackView else { return }
        let identifier = NSUserInterfaceItemIdentifier("service_\(serviceConfig.id)")

        for (index, subview) in stack.arrangedSubviews.enumerated() {
            if subview.identifier == identifier {
                stack.removeArrangedSubview(subview)
                subview.removeFromSuperview()

                let newView = createServiceRowView(
                    service: serviceConfig, isLoading: false, content: content, isError: isError)
                newView.identifier = identifier
                stack.insertArrangedSubview(newView, at: index)
                newView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
                break
            }
        }

        // 内容更新后重新计算高度
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.updateContentHeight()
        }
    }

    private func createServiceRowView(
        service: TranslateServiceConfig, isLoading: Bool, content: String?, isError: Bool = false
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.identifier = NSUserInterfaceItemIdentifier("service_\(service.id)")

        // 头部容器 - 包含图标和服务名
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerView)

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

        // 头部布局约束 (不包含复制按钮)
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            leftStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])

        // 内容区域
        var contentLabel: NSTextField?
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
            container.addSubview(label)
            contentLabel = label
        } else if isLoading {
            let loadingLabel = NSTextField(labelWithString: "翻译中...")
            loadingLabel.font = NSFont.systemFont(ofSize: 13)
            loadingLabel.textColor = NSColor.secondaryLabelColor
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(loadingLabel)
            contentLabel = loadingLabel
        }

        // 复制按钮 - 最后添加确保在最上层
        let copyButton = NSButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        copyButton.bezelStyle = .accessoryBarAction
        copyButton.isBordered = false
        copyButton.imagePosition = .imageOnly
        copyButton.contentTintColor = .secondaryLabelColor
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.target = self
        copyButton.action = #selector(handleCopyButtonClick(_:))
        container.addSubview(copyButton)  // 直接添加到 container，确保在最上层

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -56),
            headerView.heightAnchor.constraint(equalToConstant: 24),

            copyButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            copyButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            copyButton.widthAnchor.constraint(equalToConstant: 24),
            copyButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        if let label = contentLabel {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            ])
        } else {
            NSLayoutConstraint.activate([
                headerView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
            ])
        }

        // 让 container 可以水平拉伸填满 stackView
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)
        container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return container
    }

    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        return separator
    }

    private func showError(_ message: String) {
        guard let stack = resultStackView else { return }

        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let errorLabel = NSTextField(labelWithString: message)
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = .systemRed
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 16),
            errorLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            errorLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(wrapper)
    }

    private func updateLoadingState(_ isLoading: Bool) {
        guard let indicator = loadingIndicator else { return }
        indicator.isHidden = !isLoading
        if isLoading {
            indicator.startAnimation(nil)
        } else {
            indicator.stopAnimation(nil)
        }
    }

    private func updateLanguageButtons() {
        let fromText: String
        if fromLang == TranslateLanguage.auto {
            let detected: String = getDetectedLanguageDisplay()
            fromText = "自动：\(detected)"
        } else {
            fromText = fromLang.displayName
        }

        if let fromBtn: NSButton = fromLangButton {
            fromBtn.title = "\(fromText)  ▾"
        }

        let toText: String
        if toLang == TranslateLanguage.auto {
            let target: String = getTargetLanguageDisplay()
            toText = "自动：\(target)"
        } else {
            toText = toLang.displayName
        }

        if let toBtn: NSButton = toLangButton {
            toBtn.title = "\(toText)  ▾"
        }
    }

    private func getDetectedLanguageDisplay() -> String {
        let text: String =
            inputTextView?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            return "英语"
        }
        let detected: TranslateLanguage = AITranslateService.shared.detectLanguage(text)
        return detected == TranslateLanguage.chinese ? "中文" : "英语"
    }

    private func getTargetLanguageDisplay() -> String {
        let text: String =
            inputTextView?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            return "中文"
        }
        let detected: TranslateLanguage = AITranslateService.shared.detectLanguage(text)
        return detected == TranslateLanguage.chinese ? "英语" : "中文"
    }

    // MARK: - 操作

    @objc private func togglePin() {
        AITranslatePanelManager.shared.togglePinned()
    }

    @objc private func showFromLangMenu(_ sender: NSButton) {
        fromLangMenu?.popUp(
            positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func showToLangMenu(_ sender: NSButton) {
        toLangMenu?.popUp(
            positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func selectFromLang(_ sender: NSMenuItem) {
        if let lang = sender.representedObject as? TranslateLanguage {
            fromLang = lang
            updateLanguageButtons()
        }
    }

    @objc private func selectToLang(_ sender: NSMenuItem) {
        if let lang = sender.representedObject as? TranslateLanguage {
            toLang = lang
            updateLanguageButtons()
        }
    }

    @objc private func swapLanguages() {
        guard fromLang != TranslateLanguage.auto && toLang != TranslateLanguage.auto else { return }
        let temp = fromLang
        fromLang = toLang
        toLang = temp
        updateLanguageButtons()
    }

    @objc private func copyServiceResult(_ sender: NSButton) {
        handleCopyButtonClick(sender)
    }

    @objc private func handleCopyButtonClick(_ sender: NSButton) {
        print("[AITranslate] handleCopyButtonClick called")

        // 从按钮向上查找 container（有 service_ 前缀 identifier 的视图）
        var currentView: NSView? = sender
        var container: NSView? = nil
        var depth = 0

        while let view = currentView {
            let id = view.identifier?.rawValue ?? "nil"
            print("[AITranslate] depth \(depth): \(type(of: view)), identifier: \(id)")
            if let identifier = view.identifier?.rawValue, identifier.hasPrefix("service_") {
                container = view
                break
            }
            currentView = view.superview
            depth += 1
        }

        guard let container = container else {
            print("[AITranslate] Failed to find container with service_ prefix")
            return
        }

        print("[AITranslate] Found container: \(container.identifier?.rawValue ?? "nil")")

        // 递归查找所有 NSTextField（排除标题），找到内容最长的那个
        func findContentLabel(in view: NSView) -> NSTextField? {
            var bestMatch: NSTextField? = nil

            for subview in view.subviews {
                if let textField = subview as? NSTextField,
                    textField.isSelectable,  // 内容标签是可选择的
                    !textField.stringValue.isEmpty
                {
                    if bestMatch == nil
                        || textField.stringValue.count > (bestMatch?.stringValue.count ?? 0)
                    {
                        bestMatch = textField
                    }
                }
                // 递归查找子视图
                if let found = findContentLabel(in: subview) {
                    if bestMatch == nil
                        || found.stringValue.count > (bestMatch?.stringValue.count ?? 0)
                    {
                        bestMatch = found
                    }
                }
            }
            return bestMatch
        }

        // 先尝试通过 identifier 直接定位内容标签
        let serviceId =
            container.identifier?.rawValue.replacingOccurrences(of: "service_", with: "") ?? ""
        let contentId = NSUserInterfaceItemIdentifier("content_\(serviceId)")

        var targetLabel: NSTextField? = nil
        if let found = findView(in: container, identifier: contentId) as? NSTextField {
            targetLabel = found
        } else {
            // 降级使用递归查找
            targetLabel = findContentLabel(in: container)
        }

        if let contentLabel = targetLabel {
            let text = contentLabel.stringValue
            print("[AITranslate] Copying text: \(text.prefix(50))...")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            // 视觉反馈 - 短暂改变图标为勾选
            let originalImage = sender.image
            sender.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "已复制")
            sender.contentTintColor = .systemGreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sender.image = originalImage
                sender.contentTintColor = .secondaryLabelColor
            }
        } else {
            print("[AITranslate] No selectable content found in container")
        }
    }

    private func findView(in view: NSView, identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        if view.identifier == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = findView(in: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
}

// MARK: - CopyButton

/// 自定义复制按钮，使用闭包处理点击事件

// MARK: - FlippedView

/// 用于让 NSScrollView 的内容从顶部开始排列
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - NSTextViewDelegate

extension AITranslatePanelViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        if let tv = inputTextView {
            inputPlaceholder?.isHidden = !tv.string.isEmpty
        }
        updateInputHeight()

        if AITranslateService.shared.currentHistoryIndex >= 0 {
            AITranslateService.shared.resetHistoryNavigation()
        }

        if fromLang == TranslateLanguage.auto || toLang == TranslateLanguage.auto {
            updateLanguageButtons()
        }
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            performTranslation()
            AITranslateService.shared.resetHistoryNavigation()
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            AITranslatePanelManager.shared.forceHidePanel()
            return true
        }

        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if let item = AITranslateService.shared.navigateHistory(direction: 1) {
                if let tv = inputTextView {
                    tv.string = item.sourceText
                }
                inputPlaceholder?.isHidden = true
                updateInputHeight()
                // 显示历史记录中的翻译结果
                showHistoryTranslationResult(item)
            }
            return true
        }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if let item = AITranslateService.shared.navigateHistory(direction: -1) {
                if let tv = inputTextView {
                    tv.string = item.sourceText
                }
                inputPlaceholder?.isHidden = true
                updateInputHeight()
                // 显示历史记录中的翻译结果
                showHistoryTranslationResult(item)
            } else {
                if let tv = inputTextView {
                    tv.string = ""
                }
                inputPlaceholder?.isHidden = false
                updateInputHeight()
                // 清空结果区域
                collapseResultArea()
            }
            return true
        }

        return false
    }

    /// 显示历史记录中的翻译结果
    func showHistoryTranslationResult(_ item: TranslateHistoryItem) {
        guard let stack = resultStackView else { return }

        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let settings = AITranslateSettings.load()

        // 如果有多个服务结果，显示所有结果
        if let serviceResults = item.serviceResults, !serviceResults.isEmpty {
            // 固定顺序：单词翻译在前，AI翻译在后
            let sortedResults: [TranslateServiceResult] = serviceResults.sorted { r1, r2 in
                if r1.serviceType == TranslateServiceType.wordTranslate
                    && r2.serviceType != TranslateServiceType.wordTranslate
                {
                    return true
                }
                if r1.serviceType != TranslateServiceType.wordTranslate
                    && r2.serviceType == TranslateServiceType.wordTranslate
                {
                    return false
                }
                return false
            }

            for (index, result) in sortedResults.enumerated() {
                // 找到对应的服务配置
                if let serviceConfig: TranslateServiceConfig = settings.serviceConfigs.first(
                    where: {
                        $0.serviceType == result.serviceType && $0.isEnabled
                    })
                {
                    // 对于单词翻译，在翻译结果前加上原始单词
                    var displayText: String = result.translatedText
                    if result.serviceType == TranslateServiceType.wordTranslate {
                        displayText = "「\(item.sourceText)」\n\n\(result.translatedText)"
                    }

                    let serviceView = createServiceRowView(
                        service: serviceConfig, isLoading: false, content: displayText)
                    serviceView.identifier = NSUserInterfaceItemIdentifier(
                        "service_\(serviceConfig.id)")
                    stack.addArrangedSubview(serviceView)
                    serviceView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

                    // 添加分隔线
                    if index < sortedResults.count - 1 {
                        let separator = createSeparator()
                        stack.addArrangedSubview(separator)
                        separator.widthAnchor.constraint(equalTo: stack.widthAnchor)
                            .isActive = true
                    }
                }
            }
        } else {
            // 向后兼容：旧的历史记录格式
            if let serviceConfig = settings.serviceConfigs.first(where: {
                $0.serviceType == item.serviceType && $0.isEnabled
            }) {
                // 对于单词翻译，在翻译结果前加上原始单词
                var displayText: String = item.translatedText
                if item.serviceType == TranslateServiceType.wordTranslate {
                    displayText = "「\(item.sourceText)」\n\n\(item.translatedText)"
                }

                let serviceView = createServiceRowView(
                    service: serviceConfig, isLoading: false, content: displayText)
                serviceView.identifier = NSUserInterfaceItemIdentifier(
                    "service_\(serviceConfig.id)")
                stack.addArrangedSubview(serviceView)
                serviceView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive =
                    true
            } else {
                // 如果找不到对应的服务配置，使用默认显示
                let defaultConfig = TranslateServiceConfig.defaultAITranslate
                var displayText: String = item.translatedText
                if item.serviceType == TranslateServiceType.wordTranslate {
                    displayText = "「\(item.sourceText)」\n\n\(item.translatedText)"
                }

                let serviceView = createServiceRowView(
                    service: defaultConfig, isLoading: false, content: displayText)
                stack.addArrangedSubview(serviceView)
                serviceView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive =
                    true
            }
        }

        // 展开结果区域
        hasTranslationResult = true
        expandResultArea()
    }
}
