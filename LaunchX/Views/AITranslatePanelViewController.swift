import AppKit
import Combine
import Foundation

/// AI 翻译面板视图控制器
class AITranslatePanelViewController: NSViewController {

    // MARK: - UI 组件

    private var containerView: NSVisualEffectView!
    private var titleBar: NSView!
    private var titleLabel: NSTextField!
    private var settingsButton: NSButton!
    private var pinButton: NSButton!

    private var inputScrollView: NSScrollView!
    private var inputTextView: NSTextView!
    private var inputPlaceholder: NSTextField!
    private var inputHeightConstraint: NSLayoutConstraint!

    private var languageBar: NSView!
    private var fromLangButton: NSButton!
    private var swapButton: NSButton!
    private var toLangButton: NSButton!

    private var resultScrollView: NSScrollView!
    private var resultStackView: NSStackView!
    private var resultHeightConstraint: NSLayoutConstraint!

    private var loadingIndicator: NSProgressIndicator!

    // 是否有翻译结果
    private var hasTranslationResult: Bool = false

    /// 内容高度变化回调
    var onContentHeightChanged: ((CGFloat) -> Void)?

    // 语言菜单
    private var fromLangMenu: NSMenu!
    private var toLangMenu: NSMenu!

    // MARK: - 状态

    private var settings = AITranslateSettings.load()
    private var fromLang: TranslateLanguage = .auto
    private var toLang: TranslateLanguage = .auto
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
    }

    // MARK: - UI 设置

    private func setupUI() {
        // 容器视图（毛玻璃效果）
        containerView = NSVisualEffectView(frame: view.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.material = .sidebar
        containerView.blendingMode = .behindWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        view.addSubview(containerView)

        setupTitleBar()
        setupInputArea()
        setupLanguageBar()
        setupResultArea()
        setupLoadingIndicator()
    }

    private func setupTitleBar() {
        titleBar = NSView()
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleBar)

        // 标题
        titleLabel = NSTextField(labelWithString: "AI 翻译")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(titleLabel)

        // 设置按钮
        settingsButton = NSButton()
        settingsButton.image = NSImage(
            systemSymbolName: "gearshape", accessibilityDescription: "设置")
        settingsButton.bezelStyle = .inline
        settingsButton.isBordered = false
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(settingsButton)

        // 固定按钮
        pinButton = NSButton()
        pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "固定")
        pinButton.bezelStyle = .inline
        pinButton.isBordered = false
        pinButton.target = self
        pinButton.action = #selector(togglePin)
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(pinButton)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 16),

            pinButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            pinButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),
            pinButton.widthAnchor.constraint(equalToConstant: 24),
            pinButton.heightAnchor.constraint(equalToConstant: 24),

            settingsButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            settingsButton.trailingAnchor.constraint(
                equalTo: pinButton.leadingAnchor, constant: -8),
            settingsButton.widthAnchor.constraint(equalToConstant: 24),
            settingsButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setupInputArea() {
        // 输入滚动视图
        inputScrollView = NSScrollView()
        inputScrollView.hasVerticalScroller = true
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.autohidesScrollers = true
        inputScrollView.borderType = .noBorder
        inputScrollView.backgroundColor = .clear
        inputScrollView.drawsBackground = false
        inputScrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(inputScrollView)

        // 输入文本视图
        inputTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: inputMinHeight))
        inputTextView.minSize = NSSize(width: 0, height: inputMinHeight)
        inputTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inputTextView.isVerticallyResizable = true
        inputTextView.isHorizontallyResizable = false
        inputTextView.autoresizingMask = [.width]
        inputTextView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inputTextView.textContainer?.widthTracksTextView = true
        inputTextView.textContainer?.lineFragmentPadding = 0
        inputTextView.font = .systemFont(ofSize: 15)
        inputTextView.textColor = .labelColor
        inputTextView.backgroundColor = .clear
        inputTextView.drawsBackground = false
        inputTextView.isRichText = false
        inputTextView.allowsUndo = true
        inputTextView.delegate = self

        inputScrollView.documentView = inputTextView

        // 占位符
        inputPlaceholder = NSTextField(labelWithString: "输入文本并按回车，↑↓ 翻看历史记录")
        inputPlaceholder.font = .systemFont(ofSize: 15)
        inputPlaceholder.textColor = NSColor.placeholderTextColor
        inputPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(inputPlaceholder)

        inputHeightConstraint = inputScrollView.heightAnchor.constraint(
            equalToConstant: inputMinHeight)

        NSLayoutConstraint.activate([
            inputScrollView.topAnchor.constraint(equalTo: titleBar.bottomAnchor, constant: 4),
            inputScrollView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 16),
            inputScrollView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -16),
            inputHeightConstraint,

            inputPlaceholder.topAnchor.constraint(equalTo: inputScrollView.topAnchor, constant: 0),
            inputPlaceholder.leadingAnchor.constraint(
                equalTo: inputScrollView.leadingAnchor, constant: 5),
        ])
    }

    private func setupLanguageBar() {
        languageBar = NSView()
        languageBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(languageBar)

        // 源语言选择按钮
        fromLangButton = createLanguageButton()
        fromLangButton.target = self
        fromLangButton.action = #selector(showFromLangMenu(_:))
        languageBar.addSubview(fromLangButton)

        // 交换按钮
        swapButton = NSButton()
        swapButton.image = NSImage(
            systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "交换")
        swapButton.bezelStyle = .inline
        swapButton.isBordered = false
        swapButton.contentTintColor = .secondaryLabelColor
        swapButton.target = self
        swapButton.action = #selector(swapLanguages)
        swapButton.translatesAutoresizingMaskIntoConstraints = false
        languageBar.addSubview(swapButton)

        // 目标语言选择按钮
        toLangButton = createLanguageButton()
        toLangButton.target = self
        toLangButton.action = #selector(showToLangMenu(_:))
        languageBar.addSubview(toLangButton)

        // 创建语言菜单
        fromLangMenu = createLanguageMenu(isSource: true)
        toLangMenu = createLanguageMenu(isSource: false)

        NSLayoutConstraint.activate([
            languageBar.topAnchor.constraint(equalTo: inputScrollView.bottomAnchor, constant: 8),
            languageBar.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 16),
            languageBar.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -16),
            languageBar.heightAnchor.constraint(equalToConstant: 40),

            fromLangButton.leadingAnchor.constraint(equalTo: languageBar.leadingAnchor),
            fromLangButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            fromLangButton.trailingAnchor.constraint(
                equalTo: swapButton.leadingAnchor, constant: -12),
            fromLangButton.heightAnchor.constraint(equalToConstant: 36),

            swapButton.centerXAnchor.constraint(equalTo: languageBar.centerXAnchor),
            swapButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            swapButton.widthAnchor.constraint(equalToConstant: 32),
            swapButton.heightAnchor.constraint(equalToConstant: 32),

            toLangButton.leadingAnchor.constraint(equalTo: swapButton.trailingAnchor, constant: 12),
            toLangButton.trailingAnchor.constraint(equalTo: languageBar.trailingAnchor),
            toLangButton.centerYAnchor.constraint(equalTo: languageBar.centerYAnchor),
            toLangButton.heightAnchor.constraint(equalToConstant: 36),
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
        for lang in TranslateLanguage.allCases {
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
        resultScrollView = NSScrollView()
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = false
        resultScrollView.autohidesScrollers = true
        resultScrollView.borderType = .noBorder
        resultScrollView.backgroundColor = .clear
        resultScrollView.drawsBackground = false
        resultScrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(resultScrollView)

        // 使用 flipped view 让内容从顶部开始
        let flippedContainer = FlippedView()
        flippedContainer.translatesAutoresizingMaskIntoConstraints = false

        resultStackView = NSStackView()
        resultStackView.orientation = .vertical
        resultStackView.alignment = .leading
        resultStackView.spacing = 0
        resultStackView.translatesAutoresizingMaskIntoConstraints = false
        flippedContainer.addSubview(resultStackView)

        resultScrollView.documentView = flippedContainer

        // 初始状态下结果区域高度为 0（优先级低于底部约束，这样展开时可以正常工作）
        resultHeightConstraint = resultScrollView.heightAnchor.constraint(equalToConstant: 0)
        resultHeightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            resultScrollView.topAnchor.constraint(equalTo: languageBar.bottomAnchor, constant: 4),
            resultScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            resultScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            resultScrollView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor, constant: -8),

            resultStackView.topAnchor.constraint(equalTo: flippedContainer.topAnchor),
            resultStackView.leadingAnchor.constraint(equalTo: flippedContainer.leadingAnchor),
            resultStackView.trailingAnchor.constraint(equalTo: flippedContainer.trailingAnchor),

            flippedContainer.widthAnchor.constraint(equalTo: resultScrollView.widthAnchor),
        ])

        // 初始激活高度约束
        resultHeightConstraint.isActive = true

        // 初始状态隐藏结果区域
        resultScrollView.isHidden = true
    }

    private func setupLoadingIndicator() {
        loadingIndicator = NSProgressIndicator()
        loadingIndicator.style = .spinning
        loadingIndicator.isIndeterminate = true
        loadingIndicator.controlSize = .small
        loadingIndicator.isHidden = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: resultScrollView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: resultScrollView.centerYAnchor),
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
        inputTextView.string = ""
        inputPlaceholder.isHidden = false
        updateInputHeight()

        // 清空结果
        for view in resultStackView.arrangedSubviews {
            resultStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // 收起结果区域
        hasTranslationResult = false
        collapseResultArea()
    }

    /// 收起结果区域
    private func collapseResultArea() {
        resultScrollView.isHidden = true
        resultHeightConstraint.isActive = true
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
        inputTextView.string = text
        inputPlaceholder.isHidden = !text.isEmpty
        updateInputHeight()
    }

    func focusInput() {
        view.window?.makeFirstResponder(inputTextView)
    }

    func performTranslation() {
        let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        translate(text: text)
    }

    func updatePinnedState(_ isPinned: Bool) {
        let imageName = isPinned ? "pin.fill" : "pin"
        pinButton.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "固定")
    }

    // MARK: - 输入框高度自适应

    private func updateInputHeight() {
        guard let layoutManager = inputTextView.layoutManager,
            let textContainer = inputTextView.textContainer
        else { return }

        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let newHeight = min(max(textHeight + 8, inputMinHeight), inputMaxHeight)

        if inputHeightConstraint.constant != newHeight {
            inputHeightConstraint.constant = newHeight
            view.layoutSubtreeIfNeeded()
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

        if serviceConfig.serviceType == .aiTranslate {
            if isWordMode {
                // 单词模式：给出例句
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
            } else {
                // 句子模式：直接翻译，使用更明确的 prompt
                effectiveServiceConfig = TranslateServiceConfig(
                    id: serviceConfig.id,
                    name: serviceConfig.name,
                    serviceType: serviceConfig.serviceType,
                    systemPrompt:
                        "You are a professional translator. Your ONLY task is to translate text between languages. Output ONLY the translated text in the target language, nothing else. No explanations, no original text, just the translation.",
                    userPromptTemplate:
                        "Translate the following text to {toLang}. Output ONLY the translation:\n\n{text}",
                    modelConfigId: serviceConfig.modelConfigId,
                    isEnabled: serviceConfig.isEnabled
                )
            }
        }

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
        for view in resultStackView.arrangedSubviews {
            resultStackView.removeArrangedSubview(view)
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
            resultStackView.addArrangedSubview(wrapper)
            return
        }

        for (index, service) in enabledServices.enumerated() {
            let serviceView = createServiceRowView(service: service, isLoading: false, content: nil)
            resultStackView.addArrangedSubview(serviceView)

            if index < enabledServices.count - 1 {
                let separator = createSeparator()
                resultStackView.addArrangedSubview(separator)
            }
        }
    }

    private func showServicesWithLoading(showWordTranslate: Bool) {
        for view in resultStackView.arrangedSubviews {
            resultStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // 根据参数过滤要显示的服务
        let enabledServices = settings.serviceConfigs.filter { config in
            guard config.isEnabled else { return false }
            if config.serviceType == .wordTranslate && !showWordTranslate {
                return false
            }
            return true
        }

        for (index, service) in enabledServices.enumerated() {
            let serviceView = createServiceRowView(service: service, isLoading: true, content: nil)
            serviceView.identifier = NSUserInterfaceItemIdentifier("service_\(service.id)")
            resultStackView.addArrangedSubview(serviceView)

            if index < enabledServices.count - 1 {
                let separator = createSeparator()
                resultStackView.addArrangedSubview(separator)
            }
        }

        // 展开结果区域
        hasTranslationResult = true
        expandResultArea()
    }

    /// 展开结果区域
    private func expandResultArea() {
        resultScrollView.isHidden = false
        resultHeightConstraint.isActive = false
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
        let inputHeight: CGFloat = inputHeightConstraint.constant
        let languageBarHeight: CGFloat = 40
        let padding: CGFloat = 30  // 上下间距

        // 计算结果区域的实际内容高度
        var resultContentHeight: CGFloat = 0
        for subview in resultStackView.arrangedSubviews {
            resultContentHeight += subview.fittingSize.height
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
        let identifier = NSUserInterfaceItemIdentifier("service_\(serviceConfig.id)")

        for (index, subview) in resultStackView.arrangedSubviews.enumerated() {
            if subview.identifier == identifier {
                resultStackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()

                let newView = createServiceRowView(
                    service: serviceConfig, isLoading: false, content: content, isError: isError)
                newView.identifier = identifier
                resultStackView.insertArrangedSubview(newView, at: index)
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

        // 头部
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)

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
        headerStack.addArrangedSubview(iconView)

        // 服务名
        let nameLabel = NSTextField(labelWithString: service.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        headerStack.addArrangedSubview(nameLabel)

        // 弹簧
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)

        // 复制按钮
        let copyButton = NSButton()
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        copyButton.bezelStyle = .inline
        copyButton.isBordered = false
        copyButton.target = self
        copyButton.action = #selector(copyServiceResult(_:))
        copyButton.identifier = NSUserInterfaceItemIdentifier("copy_\(service.id)")
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copyButton.widthAnchor.constraint(equalToConstant: 24),
            copyButton.heightAnchor.constraint(equalToConstant: 24),
        ])
        headerStack.addArrangedSubview(copyButton)

        // 内容区域
        var contentLabel: NSTextField?
        if let content = content {
            contentLabel = NSTextField(wrappingLabelWithString: content)
            contentLabel!.font = .systemFont(ofSize: 14)
            contentLabel!.textColor = isError ? .systemRed : .labelColor
            contentLabel!.isSelectable = true
            contentLabel!.translatesAutoresizingMaskIntoConstraints = false
            contentLabel!.identifier = NSUserInterfaceItemIdentifier("content_\(service.id)")
            container.addSubview(contentLabel!)
        } else if isLoading {
            let loadingLabel = NSTextField(labelWithString: "翻译中...")
            loadingLabel.font = .systemFont(ofSize: 13)
            loadingLabel.textColor = .secondaryLabelColor
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(loadingLabel)
            contentLabel = loadingLabel
        }

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])

        if let label = contentLabel {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            ])
        } else {
            NSLayoutConstraint.activate([
                headerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
            ])
        }

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
        for view in resultStackView.arrangedSubviews {
            resultStackView.removeArrangedSubview(view)
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
        resultStackView.addArrangedSubview(wrapper)
    }

    private func updateLoadingState(_ isLoading: Bool) {
        loadingIndicator.isHidden = !isLoading
        if isLoading {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
    }

    private func updateLanguageButtons() {
        let fromText: String
        if fromLang == .auto {
            let detected = getDetectedLanguageDisplay()
            fromText = "自动：\(detected)"
        } else {
            fromText = fromLang.displayName
        }
        fromLangButton.title = "\(fromText)  ▾"

        let toText: String
        if toLang == .auto {
            let target = getTargetLanguageDisplay()
            toText = "自动：\(target)"
        } else {
            toText = toLang.displayName
        }
        toLangButton.title = "\(toText)  ▾"
    }

    private func getDetectedLanguageDisplay() -> String {
        let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "英语"
        }
        let detected = AITranslateService.shared.detectLanguage(text)
        return detected == .chinese ? "中文" : "英语"
    }

    private func getTargetLanguageDisplay() -> String {
        let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "中文简体"
        }
        let detected = AITranslateService.shared.detectLanguage(text)
        return detected == .chinese ? "英语" : "中文简体"
    }

    // MARK: - 操作

    @objc private func openSettings() {
        AITranslatePanelManager.shared.forceHidePanel()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePin() {
        AITranslatePanelManager.shared.togglePinned()
    }

    @objc private func showFromLangMenu(_ sender: NSButton) {
        fromLangMenu.popUp(
            positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func showToLangMenu(_ sender: NSButton) {
        toLangMenu.popUp(
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
        guard fromLang != .auto && toLang != .auto else { return }
        let temp = fromLang
        fromLang = toLang
        toLang = temp
        updateLanguageButtons()
    }

    @objc private func copyServiceResult(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
            identifier.hasPrefix("copy_"),
            let serviceIdString = identifier.components(separatedBy: "copy_").last,
            let serviceId = UUID(uuidString: serviceIdString)
        else {
            print("[AITranslate] Failed to get service ID from button")
            return
        }

        let contentIdentifier = NSUserInterfaceItemIdentifier("content_\(serviceId)")
        for subview in resultStackView.arrangedSubviews {
            if let contentLabel = findView(in: subview, identifier: contentIdentifier)
                as? NSTextField
            {
                let text = contentLabel.stringValue
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                print("[AITranslate] Copied to clipboard: \(text.prefix(50))...")
                return
            }
        }
        print("[AITranslate] Content label not found for service: \(serviceId)")
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

// MARK: - FlippedView

/// 用于让 NSScrollView 的内容从顶部开始排列
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - NSTextViewDelegate

extension AITranslatePanelViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        inputPlaceholder.isHidden = !inputTextView.string.isEmpty
        updateInputHeight()

        if AITranslateService.shared.currentHistoryIndex >= 0 {
            AITranslateService.shared.resetHistoryNavigation()
        }

        if fromLang == .auto || toLang == .auto {
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
                inputTextView.string = item.sourceText
                inputPlaceholder.isHidden = true
                updateInputHeight()
            }
            return true
        }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if let item = AITranslateService.shared.navigateHistory(direction: -1) {
                inputTextView.string = item.sourceText
                inputPlaceholder.isHidden = true
                updateInputHeight()
            } else {
                inputTextView.string = ""
                inputPlaceholder.isHidden = false
                updateInputHeight()
            }
            return true
        }

        return false
    }
}
