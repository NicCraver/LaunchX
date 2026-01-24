import Carbon
import SwiftUI

// MARK: - AI 翻译设置视图

struct AITranslateSettingsView: View {
    @State private var settings = AITranslateSettings.load()
    @State private var showSelectionHotKeyPopover = false
    @State private var showInputHotKeyPopover = false
    @State private var showAddModelSheet = false
    @State private var showAddServiceSheet = false
    @State private var editingModel: AIModelConfig?
    @State private var editingService: TranslateServiceConfig?

    private let labelWidth: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题行
                HStack(spacing: 12) {
                    Image(systemName: "character.bubble.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.indigo)
                    Text("AI 翻译")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $settings.isEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: settings.isEnabled) { _, _ in
                            settings.save()
                        }
                }

                Divider()

                // 快捷键设置
                Group {
                    HStack {
                        Text("选词翻译快捷键:")
                            .frame(width: labelWidth, alignment: .trailing)
                        TranslateHotKeyButton(
                            keyCode: $settings.selectionHotKeyCode,
                            modifiers: $settings.selectionHotKeyModifiers,
                            showPopover: $showSelectionHotKeyPopover,
                            hotKeyType: "translateSelection"
                        ) {
                            settings.save()
                            HotKeyService.shared.registerTranslateSelectionHotKey(
                                keyCode: settings.selectionHotKeyCode,
                                modifiers: settings.selectionHotKeyModifiers
                            )
                        }
                        Spacer()
                    }

                    HStack {
                        Text("输入翻译快捷键:")
                            .frame(width: labelWidth, alignment: .trailing)
                        TranslateHotKeyButton(
                            keyCode: $settings.inputHotKeyCode,
                            modifiers: $settings.inputHotKeyModifiers,
                            showPopover: $showInputHotKeyPopover,
                            hotKeyType: "translateInput"
                        ) {
                            settings.save()
                            HotKeyService.shared.registerTranslateInputHotKey(
                                keyCode: settings.inputHotKeyCode,
                                modifiers: settings.inputHotKeyModifiers
                            )
                        }
                        Spacer()
                    }
                }

                Divider()

                // AI 模型配置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("AI 模型配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { showAddModelSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    if settings.modelConfigs.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "cpu")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("暂无模型配置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("添加模型") {
                                    showAddModelSheet = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        ForEach(settings.modelConfigs) { config in
                            ModelConfigRow(
                                config: config,
                                isDefault: config.isDefault,
                                onEdit: { editingModel = config },
                                onDelete: { deleteModel(config) },
                                onSetDefault: { setDefaultModel(config) }
                            )
                        }
                    }
                }

                Divider()

                // 翻译服务配置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("翻译服务配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { showAddServiceSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(settings.serviceConfigs) { config in
                        ServiceConfigRow(
                            config: config,
                            onEdit: { editingService = config },
                            onToggle: { toggleService(config) }
                        )
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddModelSheet) {
            ModelConfigEditorSheet(mode: .add) { newConfig in
                addModel(newConfig)
            }
        }
        .sheet(item: $editingModel) { config in
            ModelConfigEditorSheet(mode: .edit(config)) { updatedConfig in
                updateModel(updatedConfig)
            }
        }
        .sheet(isPresented: $showAddServiceSheet) {
            ServiceConfigEditorSheet(mode: .add) { newConfig in
                addService(newConfig)
            }
        }
        .sheet(item: $editingService) { config in
            ServiceConfigEditorSheet(mode: .edit(config)) { updatedConfig in
                updateService(updatedConfig)
            }
        }
    }

    // MARK: - 模型管理

    private func addModel(_ config: AIModelConfig) {
        var newConfig = config
        if settings.modelConfigs.isEmpty {
            newConfig = AIModelConfig(
                id: config.id,
                name: config.name,
                provider: config.provider,
                apiKey: config.apiKey,
                model: config.model,
                baseURL: config.baseURL,
                isDefault: true
            )
        }
        settings.modelConfigs.append(newConfig)
        settings.save()
    }

    private func updateModel(_ config: AIModelConfig) {
        if let index = settings.modelConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.modelConfigs[index] = config
            settings.save()
        }
    }

    private func deleteModel(_ config: AIModelConfig) {
        settings.modelConfigs.removeAll { $0.id == config.id }
        // 如果删除的是默认模型，设置第一个为默认
        if config.isDefault && !settings.modelConfigs.isEmpty {
            settings.modelConfigs[0] = AIModelConfig(
                id: settings.modelConfigs[0].id,
                name: settings.modelConfigs[0].name,
                provider: settings.modelConfigs[0].provider,
                apiKey: settings.modelConfigs[0].apiKey,
                model: settings.modelConfigs[0].model,
                baseURL: settings.modelConfigs[0].baseURL,
                isDefault: true
            )
        }
        settings.save()
    }

    private func setDefaultModel(_ config: AIModelConfig) {
        for i in 0..<settings.modelConfigs.count {
            let isDefault = settings.modelConfigs[i].id == config.id
            settings.modelConfigs[i] = AIModelConfig(
                id: settings.modelConfigs[i].id,
                name: settings.modelConfigs[i].name,
                provider: settings.modelConfigs[i].provider,
                apiKey: settings.modelConfigs[i].apiKey,
                model: settings.modelConfigs[i].model,
                baseURL: settings.modelConfigs[i].baseURL,
                isDefault: isDefault
            )
        }
        settings.save()
    }

    // MARK: - 服务管理

    private func addService(_ config: TranslateServiceConfig) {
        settings.serviceConfigs.append(config)
        settings.save()
    }

    private func updateService(_ config: TranslateServiceConfig) {
        if let index = settings.serviceConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.serviceConfigs[index] = config
            settings.save()
        }
    }

    private func toggleService(_ config: TranslateServiceConfig) {
        if let index = settings.serviceConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.serviceConfigs[index] = TranslateServiceConfig(
                id: config.id,
                name: config.name,
                serviceType: config.serviceType,
                systemPrompt: config.systemPrompt,
                userPromptTemplate: config.userPromptTemplate,
                modelConfigId: config.modelConfigId,
                isEnabled: !config.isEnabled
            )
            settings.save()
        }
    }
}

// MARK: - 模型配置行

struct ModelConfigRow: View {
    let config: AIModelConfig
    let isDefault: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 默认标记
            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: 14, height: 14)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                Text("\(config.model) · \(config.provider.displayName)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    if !isDefault {
                        Button(action: onSetDefault) {
                            Text("设为默认")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 服务配置行

struct ServiceConfigRow: View {
    let config: TranslateServiceConfig
    let onEdit: () -> Void
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: config.serviceType.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(config.isEnabled ? .primary : .secondary)
                Text(config.serviceType.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }
            }

            Toggle(
                "",
                isOn: Binding(
                    get: { config.isEnabled },
                    set: { _ in onToggle() }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 模型配置编辑器

enum ModelConfigEditorMode {
    case add
    case edit(AIModelConfig)

    var title: String {
        switch self {
        case .add: return "添加模型"
        case .edit: return "编辑模型"
        }
    }
}

/// 模型选择模式
enum ModelSelectionMode: String, CaseIterable {
    case fetch = "fetch"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .fetch: return "拉取模型"
        case .manual: return "手动输入"
        }
    }
}

struct ModelConfigEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: ModelConfigEditorMode
    let onSave: (AIModelConfig) -> Void

    @State private var name: String = ""
    @State private var provider: AIModelProvider = .openAI
    @State private var apiKey: String = ""
    @State private var model: String = "gpt-4o-mini"
    @State private var manualModel: String = ""
    @State private var baseURL: String = "https://api.openai.com/v1"
    @State private var isValidating = false
    @State private var validationResult: String?
    @State private var showAPIKey = false
    @State private var modelSelectionMode: ModelSelectionMode = .fetch
    @State private var isFetchingModels = false
    @State private var fetchedModels: [String] = []
    @State private var fetchError: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.isEmpty
            && !currentModel.isEmpty
            && !baseURL.isEmpty
    }

    private var currentModel: String {
        modelSelectionMode == .fetch ? model : manualModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(mode.title)
                    .font(.headline)
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 名称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：GPT-4", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // API 地址（移到 API Key 前面）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API 地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://api.openai.com/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                        Text("支持自定义代理地址，如 https://your-proxy.com/v1")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }

                    // API Key
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            if showAPIKey {
                                TextField("请输入 API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("请输入 API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button(action: { showAPIKey.toggle() }) {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // AI 模型
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("AI 模型")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $modelSelectionMode) {
                                ForEach(ModelSelectionMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }

                        if modelSelectionMode == .fetch {
                            HStack(spacing: 8) {
                                Picker("", selection: $model) {
                                    if fetchedModels.isEmpty {
                                        ForEach(AIModelConfig.commonModels, id: \.self) { m in
                                            Text(m).tag(m)
                                        }
                                    } else {
                                        ForEach(fetchedModels, id: \.self) { m in
                                            Text(m).tag(m)
                                        }
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Button(action: fetchModels) {
                                    if isFetchingModels {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(apiKey.isEmpty || baseURL.isEmpty || isFetchingModels)
                                .help("从 API 拉取可用模型列表")
                            }

                            if let error = fetchError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            } else if !fetchedModels.isEmpty {
                                Text("已拉取 \(fetchedModels.count) 个模型")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        } else {
                            TextField("请输入模型名称，如 gpt-4o", text: $manualModel)
                                .textFieldStyle(.roundedBorder)
                            Text("手动输入模型 ID，适用于自定义或未列出的模型")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }

                    // 校验按钮
                    HStack {
                        Spacer()
                        Button(action: validateAPI) {
                            if isValidating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("校验")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            apiKey.isEmpty || baseURL.isEmpty || currentModel.isEmpty
                                || isValidating)
                        Spacer()
                    }

                    if let result = validationResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("成功") ? .green : .red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("保存") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 520)
        .onAppear {
            if case .edit(let config) = mode {
                name = config.name
                provider = config.provider
                apiKey = config.apiKey
                model = config.model
                manualModel = config.model
                baseURL = config.baseURL
                // 检查模型是否在常用列表中
                if !AIModelConfig.commonModels.contains(config.model) {
                    modelSelectionMode = .manual
                }
            }
        }
    }

    private func fetchModels() {
        isFetchingModels = true
        fetchError = nil

        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)models" : "\(baseURL)/models"
        guard let url = URL(string: urlString) else {
            fetchError = "无效的 API 地址"
            isFetchingModels = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isFetchingModels = false

                if let error = error {
                    fetchError = "请求失败: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    fetchError = "未收到响应数据"
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let dataArray = json["data"] as? [[String: Any]]
                    {
                        let models = dataArray.compactMap { $0["id"] as? String }
                            .filter {
                                !$0.contains("embedding") && !$0.contains("whisper")
                                    && !$0.contains("tts") && !$0.contains("dall-e")
                            }
                            .sorted()

                        if models.isEmpty {
                            fetchError = "未找到可用模型"
                        } else {
                            fetchedModels = models
                            // 如果当前选择的模型不在列表中，选择第一个
                            if !models.contains(model) {
                                model = models.first ?? ""
                            }
                        }
                    } else if let json = try JSONSerialization.jsonObject(with: data)
                        as? [String: Any],
                        let errorInfo = json["error"] as? [String: Any],
                        let message = errorInfo["message"] as? String
                    {
                        fetchError = message
                    } else {
                        fetchError = "解析响应失败"
                    }
                } catch {
                    fetchError = "解析失败: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func validateAPI() {
        isValidating = true
        validationResult = nil

        let config = AIModelConfig(
            name: name,
            provider: provider,
            apiKey: apiKey,
            model: currentModel,
            baseURL: baseURL
        )

        AITranslateService.shared.validateAPIConfig(config) { result in
            isValidating = false
            switch result {
            case .success:
                validationResult = "校验成功"
            case .failure(let error):
                validationResult = error.localizedDescription
            }
        }
    }

    private func saveConfig() {
        let config: AIModelConfig
        if case .edit(let existing) = mode {
            config = AIModelConfig(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                provider: provider,
                apiKey: apiKey,
                model: currentModel,
                baseURL: baseURL,
                isDefault: existing.isDefault
            )
        } else {
            config = AIModelConfig(
                name: name.trimmingCharacters(in: .whitespaces),
                provider: provider,
                apiKey: apiKey,
                model: currentModel,
                baseURL: baseURL
            )
        }
        onSave(config)
        dismiss()
    }
}

// MARK: - 服务配置编辑器

enum ServiceConfigEditorMode {
    case add
    case edit(TranslateServiceConfig)

    var title: String {
        switch self {
        case .add: return "添加翻译服务"
        case .edit: return "编辑翻译服务"
        }
    }
}

struct ServiceConfigEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: ServiceConfigEditorMode
    let onSave: (TranslateServiceConfig) -> Void

    @State private var name: String = ""
    @State private var serviceType: TranslateServiceType = .aiTranslate
    @State private var systemPrompt: String = ""
    @State private var userPromptTemplate: String = ""
    @State private var selectedModelId: UUID?
    @State private var showTemplates = false

    private var modelConfigs: [AIModelConfig] {
        AITranslateSettings.load().modelConfigs
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && selectedModelId != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(mode.title)
                    .font(.headline)
                Spacer()

                Button("模板") {
                    showTemplates = true
                }
                .buttonStyle(.bordered)

                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 名称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：AI 翻译", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 服务类型
                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $serviceType) {
                            ForEach(TranslateServiceType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    // 使用模型
                    VStack(alignment: .leading, spacing: 6) {
                        Text("使用模型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if modelConfigs.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("请先添加 AI 模型配置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            Picker("", selection: $selectedModelId) {
                                Text("请选择模型").tag(nil as UUID?)
                                ForEach(modelConfigs) { config in
                                    Text("\(config.name) (\(config.model))").tag(config.id as UUID?)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }

                    // 角色描述
                    VStack(alignment: .leading, spacing: 6) {
                        Text("角色描述（选填）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }

                    // Prompt 模板
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt（选填）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $userPromptTemplate)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )

                        Text("可用变量: {text}, {fromLang}, {toLang}")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .padding()
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("保存") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if case .edit(let config) = mode {
                name = config.name
                serviceType = config.serviceType
                systemPrompt = config.systemPrompt
                userPromptTemplate = config.userPromptTemplate
                selectedModelId = config.modelConfigId
            }
        }
        .popover(isPresented: $showTemplates) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择模板")
                    .font(.headline)
                    .padding(.bottom, 4)

                Button("AI 翻译（默认）") {
                    applyTemplate(.defaultAITranslate)
                }
                .buttonStyle(.plain)

                Button("单词翻译（带音标）") {
                    applyTemplate(.defaultWordTranslate)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private func applyTemplate(_ config: TranslateServiceConfig) {
        name = config.name
        serviceType = config.serviceType
        systemPrompt = config.systemPrompt
        userPromptTemplate = config.userPromptTemplate
        showTemplates = false
    }

    private func saveConfig() {
        let config: TranslateServiceConfig
        if case .edit(let existing) = mode {
            config = TranslateServiceConfig(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                serviceType: serviceType,
                systemPrompt: systemPrompt,
                userPromptTemplate: userPromptTemplate,
                modelConfigId: selectedModelId,
                isEnabled: existing.isEnabled
            )
        } else {
            config = TranslateServiceConfig(
                name: name.trimmingCharacters(in: .whitespaces),
                serviceType: serviceType,
                systemPrompt: systemPrompt,
                userPromptTemplate: userPromptTemplate,
                modelConfigId: selectedModelId
            )
        }
        onSave(config)
        dismiss()
    }
}

// MARK: - 翻译快捷键按钮

struct TranslateHotKeyButton: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var showPopover: Bool
    let hotKeyType: String
    let onSave: () -> Void

    @State private var isHovered = false

    private var hasHotKey: Bool {
        keyCode != 0
    }

    var body: some View {
        Button(action: { showPopover = true }) {
            Group {
                if hasHotKey {
                    HStack(spacing: 2) {
                        ForEach(HotKeyService.modifierSymbols(for: modifiers), id: \.self) {
                            symbol in
                            KeyCapViewSettings(text: symbol)
                        }
                        KeyCapViewSettings(text: HotKeyService.keyString(for: keyCode))
                    }
                } else {
                    Text("设置快捷键")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        (isHovered && !hasHotKey) ? Color.secondary.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .popover(isPresented: $showPopover) {
            TranslateHotKeyRecorderPopover(
                keyCode: $keyCode,
                modifiers: $modifiers,
                isPresented: $showPopover,
                hotKeyType: hotKeyType,
                onSave: onSave
            )
        }
    }
}

// MARK: - 翻译快捷键录制弹窗

struct TranslateHotKeyRecorderPopover: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var isPresented: Bool
    let hotKeyType: String
    let onSave: () -> Void

    @State private var keyDownMonitor: Any?
    @State private var conflictMessage: String?

    private var hasHotKey: Bool {
        keyCode != 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("例如")
                    .foregroundColor(.secondary)
                    .font(.caption)
                KeyCapView(text: "⌃")
                KeyCapView(text: "⌥")
                KeyCapView(text: "T")
            }
            .padding(.top, 8)

            if let conflict = conflictMessage {
                Text("快捷键已被「\(conflict)」使用")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            } else {
                Text("请输入快捷键...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            if hasHotKey {
                HStack(spacing: 3) {
                    ForEach(HotKeyService.modifierSymbols(for: modifiers), id: \.self) { symbol in
                        KeyCapView(text: symbol)
                    }
                    KeyCapView(text: HotKeyService.keyString(for: keyCode))

                    Button {
                        keyCode = 0
                        modifiers = 0
                        onSave()
                        if hotKeyType == "translateSelection" {
                            HotKeyService.shared.unregisterTranslateSelectionHotKey()
                        } else {
                            HotKeyService.shared.unregisterTranslateInputHotKey()
                        }
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .frame(width: 220)
        .onAppear {
            HotKeyService.shared.suspendAllHotKeys()
            startRecording()
        }
        .onDisappear {
            stopRecording()
            HotKeyService.shared.resumeAllHotKeys()
        }
    }

    private func startRecording() {
        conflictMessage = nil
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == kVK_Escape {
                stopRecording()
                isPresented = false
                return nil
            }

            if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
                keyCode = 0
                modifiers = 0
                onSave()
                if hotKeyType == "translateSelection" {
                    HotKeyService.shared.unregisterTranslateSelectionHotKey()
                } else {
                    HotKeyService.shared.unregisterTranslateInputHotKey()
                }
                stopRecording()
                isPresented = false
                return nil
            }

            let mods = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { return event }

            let code = UInt32(event.keyCode)

            if let conflict = HotKeyService.shared.checkHotKeyConflict(
                keyCode: code, modifiers: mods, excludeType: hotKeyType)
            {
                conflictMessage = conflict
                return nil
            }

            keyCode = code
            modifiers = mods
            onSave()
            stopRecording()
            isPresented = false
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}

#Preview {
    AITranslateSettingsView()
        .frame(width: 600, height: 700)
}
