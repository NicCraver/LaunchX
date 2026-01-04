import AppKit
import Combine
import Foundation

/// AI 翻译服务 - 负责调用 AI API 进行翻译
final class AITranslateService: ObservableObject {
    static let shared = AITranslateService()

    // MARK: - Published 属性

    @Published private(set) var isTranslating: Bool = false
    @Published private(set) var history: [TranslateHistoryItem] = []
    @Published var currentHistoryIndex: Int = -1

    // MARK: - 私有属性

    private var activeTasks: [UUID: URLSessionDataTask] = [:]

    // 数据存储路径
    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let translateDir = appSupport.appendingPathComponent(
            "LaunchX/Translate", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: translateDir, withIntermediateDirectories: true)
        return translateDir
    }()

    private let historyFileURL: URL

    private init() {
        self.historyFileURL = storageURL.appendingPathComponent("history.json")
        loadHistory()
        print("[AITranslateService] Initialized with \(history.count) history items")
    }

    // MARK: - 翻译方法

    /// 执行翻译
    func translate(
        text: String,
        fromLang: TranslateLanguage,
        toLang: TranslateLanguage,
        serviceConfig: TranslateServiceConfig,
        modelConfig: AIModelConfig,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(TranslateError.emptyText))
            return
        }

        guard !modelConfig.apiKey.isEmpty else {
            completion(.failure(TranslateError.noAPIKey))
            return
        }

        // 使用服务配置的 ID 作为任务标识
        let taskId = serviceConfig.id

        // 构建请求
        let actualFromLang = fromLang == .auto ? detectLanguage(text) : fromLang
        let actualToLang: TranslateLanguage
        if toLang == .auto {
            actualToLang = actualFromLang == .chinese ? .english : .chinese
        } else {
            actualToLang = toLang
        }

        let userPrompt =
            serviceConfig.userPromptTemplate
            .replacingOccurrences(of: "{text}", with: text)
            .replacingOccurrences(of: "{fromLang}", with: actualFromLang.languageName)
            .replacingOccurrences(of: "{toLang}", with: actualToLang.languageName)

        let messages: [[String: String]] = [
            ["role": "system", "content": serviceConfig.systemPrompt],
            ["role": "user", "content": userPrompt],
        ]

        let requestBody: [String: Any] = [
            "model": modelConfig.model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 2000,
        ]

        // 构建 URL
        var baseURL = modelConfig.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        let urlString = "\(baseURL)/chat/completions"

        guard let url = URL(string: urlString) else {
            isTranslating = false
            completion(.failure(TranslateError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(modelConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) {
            [weak self] data, response, error in
            DispatchQueue.main.async {
                // 移除已完成的任务
                self?.activeTasks.removeValue(forKey: taskId)
                self?.updateTranslatingState()

                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled {
                        return
                    }
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(TranslateError.noData))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // 检查错误响应
                        if let error = json["error"] as? [String: Any],
                            let message = error["message"] as? String
                        {
                            completion(.failure(TranslateError.apiError(message)))
                            return
                        }

                        // 解析成功响应
                        if let choices = json["choices"] as? [[String: Any]],
                            let firstChoice = choices.first,
                            let message = firstChoice["message"] as? [String: Any],
                            let content = message["content"] as? String
                        {
                            let translatedText = content.trimmingCharacters(
                                in: .whitespacesAndNewlines)

                            // 保存到历史记录（只保存第一个服务的结果）
                            if serviceConfig.serviceType == .aiTranslate {
                                self?.addToHistory(
                                    sourceText: text,
                                    translatedText: translatedText,
                                    fromLang: actualFromLang,
                                    toLang: actualToLang,
                                    serviceType: serviceConfig.serviceType
                                )
                            }

                            completion(.success(translatedText))
                            return
                        }
                    }
                    completion(.failure(TranslateError.parseError))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        // 保存任务并启动
        activeTasks[taskId] = task
        updateTranslatingState()
        task.resume()
    }

    private func updateTranslatingState() {
        isTranslating = !activeTasks.isEmpty
    }

    /// 取消当前翻译
    func cancelTranslation() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        isTranslating = false
    }

    // MARK: - 语言检测

    /// 简单的语言检测（基于字符）
    func detectLanguage(_ text: String) -> TranslateLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .english }

        var chineseCount = 0
        var englishCount = 0

        for char in trimmed {
            if char.unicodeScalars.first.map({ $0.value >= 0x4E00 && $0.value <= 0x9FFF }) == true {
                chineseCount += 1
            } else if char.isLetter && char.isASCII {
                englishCount += 1
            }
        }

        return chineseCount > englishCount ? .chinese : .english
    }

    /// 检测是否为单个单词
    func isSingleWord(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 没有空格且长度合理的被视为单词
        return !trimmed.contains(" ") && trimmed.count <= 30
    }

    // MARK: - 历史记录管理

    private func addToHistory(
        sourceText: String,
        translatedText: String,
        fromLang: TranslateLanguage,
        toLang: TranslateLanguage,
        serviceType: TranslateServiceType
    ) {
        let item = TranslateHistoryItem(
            sourceText: sourceText,
            translatedText: translatedText,
            fromLang: fromLang,
            toLang: toLang,
            serviceType: serviceType
        )

        history.insert(item, at: 0)

        // 限制历史记录数量
        let settings = AITranslateSettings.load()
        if history.count > settings.historyLimit {
            history = Array(history.prefix(settings.historyLimit))
        }

        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        currentHistoryIndex = -1
        saveHistory()
    }

    func navigateHistory(direction: Int) -> TranslateHistoryItem? {
        guard !history.isEmpty else { return nil }

        let newIndex = currentHistoryIndex + direction
        if newIndex >= -1 && newIndex < history.count {
            currentHistoryIndex = newIndex
            if currentHistoryIndex >= 0 {
                return history[currentHistoryIndex]
            }
        }
        return nil
    }

    func resetHistoryNavigation() {
        currentHistoryIndex = -1
    }

    // MARK: - 持久化

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
            let loadedHistory = try? JSONDecoder().decode([TranslateHistoryItem].self, from: data)
        else {
            return
        }
        history = loadedHistory
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyFileURL)
        }
    }

    // MARK: - API 校验

    /// 校验 API 配置是否有效
    func validateAPIConfig(
        _ config: AIModelConfig,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard !config.apiKey.isEmpty else {
            completion(.failure(TranslateError.noAPIKey))
            return
        }

        var baseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        let urlString = "\(baseURL)/chat/completions"

        guard let url = URL(string: urlString) else {
            completion(.failure(TranslateError.invalidURL))
            return
        }

        // 使用简单的 chat completions 请求来校验
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(.success(true))
                    } else if httpResponse.statusCode == 401 {
                        completion(.failure(TranslateError.invalidAPIKey))
                    } else if httpResponse.statusCode == 404 {
                        completion(.failure(TranslateError.apiError("模型不存在或 API 地址错误")))
                    } else {
                        // 尝试解析错误信息
                        if let data = data,
                            let json = try? JSONSerialization.jsonObject(with: data)
                                as? [String: Any],
                            let error = json["error"] as? [String: Any],
                            let message = error["message"] as? String
                        {
                            completion(.failure(TranslateError.apiError(message)))
                        } else {
                            completion(
                                .failure(TranslateError.apiError("HTTP \(httpResponse.statusCode)"))
                            )
                        }
                    }
                } else {
                    completion(.failure(TranslateError.noData))
                }
            }
        }.resume()
    }

    // MARK: - 选词翻译

    /// 获取当前选中的文本
    func getSelectedText() -> String? {
        // 保存当前剪贴板内容
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // 清空剪贴板
        pasteboard.clearContents()

        // 等待一小段时间确保剪贴板清空
        usleep(50000)  // 50ms

        // 模拟 Cmd+C 复制选中文本
        // 使用 combinedSessionState 以支持全屏应用
        let source = CGEventSource(stateID: .combinedSessionState)

        // 按下 C + Cmd
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // C key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        // 松开 C + Cmd
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)

        // 等待复制完成 - 使用循环检测剪贴板变化
        var selectedText: String? = nil
        let maxWaitTime: UInt32 = 300000  // 300ms
        let checkInterval: UInt32 = 20000  // 20ms
        var waited: UInt32 = 0

        while waited < maxWaitTime {
            usleep(checkInterval)
            waited += checkInterval

            // 检查剪贴板是否有变化
            if pasteboard.changeCount != previousChangeCount {
                selectedText = pasteboard.string(forType: .string)
                if selectedText != nil && !selectedText!.isEmpty {
                    break
                }
            }
        }

        // 如果没检测到变化，再尝试读取一次
        if selectedText == nil || selectedText?.isEmpty == true {
            selectedText = pasteboard.string(forType: .string)
        }

        // 恢复之前的剪贴板内容
        pasteboard.clearContents()
        if let previous = previousContents {
            pasteboard.setString(previous, forType: .string)
        }

        print(
            "[AITranslateService] getSelectedText: \(selectedText ?? "nil"), waited: \(waited/1000)ms"
        )

        return selectedText
    }
}

// MARK: - 翻译错误

enum TranslateError: LocalizedError {
    case emptyText
    case noAPIKey
    case invalidAPIKey
    case invalidURL
    case noData
    case parseError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "请输入要翻译的文本"
        case .noAPIKey:
            return "请先配置 API Key"
        case .invalidAPIKey:
            return "API Key 无效"
        case .invalidURL:
            return "无效的 API 地址"
        case .noData:
            return "未收到响应数据"
        case .parseError:
            return "响应解析失败"
        case .apiError(let message):
            return "API 错误: \(message)"
        }
    }
}
