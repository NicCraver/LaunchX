import Carbon
import SwiftUI

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

