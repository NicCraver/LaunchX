import Foundation

// MARK: - AI 模型配置

/// AI 模型提供商类型
enum AIModelProvider: String, Codable, CaseIterable {
    case openAI = "openai"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .custom: return "自定义"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .custom: return ""
        }
    }
}

/// AI 模型配置
struct AIModelConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String  // 显示名称
    var provider: AIModelProvider
    var apiKey: String
    var model: String  // 模型名称，如 gpt-4, gpt-3.5-turbo
    var baseURL: String  // API 基础 URL
    var isDefault: Bool  // 是否为默认模型

    init(
        id: UUID = UUID(),
        name: String,
        provider: AIModelProvider = .openAI,
        apiKey: String = "",
        model: String = "gpt-4o-mini",
        baseURL: String = "https://api.openai.com/v1",
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.isDefault = isDefault
    }

    // 常用模型列表
    static let commonModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4-turbo",
        "gpt-4",
        "gpt-3.5-turbo",
    ]
}

// MARK: - 翻译服务配置

/// 翻译服务类型
enum TranslateServiceType: String, Codable, CaseIterable, Identifiable {
    case aiTranslate = "ai_translate"  // AI 翻译（句子/段落）
    case wordTranslate = "word_translate"  // 单词翻译（带音标）

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aiTranslate: return "AI 翻译"
        case .wordTranslate: return "单词翻译"
        }
    }

    var iconName: String {
        switch self {
        case .aiTranslate: return "bubble.left.and.text.bubble.right"
        case .wordTranslate: return "textformat.abc"
        }
    }
}

/// 翻译服务配置
struct TranslateServiceConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var serviceType: TranslateServiceType
    var systemPrompt: String  // 系统提示词
    var userPromptTemplate: String  // 用户提示词模板，支持 {text}, {fromLang}, {toLang}
    var modelConfigId: UUID?  // 关联的模型配置 ID
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        serviceType: TranslateServiceType,
        systemPrompt: String = "",
        userPromptTemplate: String = "",
        modelConfigId: UUID? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
        self.modelConfigId = modelConfigId
        self.isEnabled = isEnabled
    }

    // 默认 AI 翻译配置
    static let defaultAITranslate = TranslateServiceConfig(
        name: "AI 翻译",
        serviceType: .aiTranslate,
        systemPrompt:
            "You are a professional translator. Translate the text accurately while maintaining the original meaning and tone. Only output the translation, no explanations.",
        userPromptTemplate: "Translate the following text from {fromLang} to {toLang}:\n\n{text}"
    )

    // 默认单词翻译配置
    static let defaultWordTranslate = TranslateServiceConfig(
        name: "单词翻译",
        serviceType: .wordTranslate,
        systemPrompt:
            "You are a dictionary assistant. For English words, provide: 1) phonetic transcription (IPA), 2) part of speech, 3) Chinese translation, 4) example sentence. For Chinese words, provide English translation with example. Format clearly.",
        userPromptTemplate:
            "Provide dictionary-style translation for this word from {fromLang} to {toLang}:\n\n{text}"
    )
}

// MARK: - 翻译语言

/// 支持的语言
enum TranslateLanguage: String, Codable, CaseIterable {
    case auto = "auto"
    case chinese = "zh"
    case english = "en"

    var displayName: String {
        switch self {
        case .auto: return "自动识别"
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var languageName: String {
        switch self {
        case .auto: return "auto-detect"
        case .chinese: return "Chinese"
        case .english: return "English"
        }
    }
}

// MARK: - 翻译历史记录

/// 翻译历史记录
struct TranslateHistoryItem: Identifiable, Codable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let fromLang: TranslateLanguage
    let toLang: TranslateLanguage
    let serviceType: TranslateServiceType
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        fromLang: TranslateLanguage,
        toLang: TranslateLanguage,
        serviceType: TranslateServiceType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.fromLang = fromLang
        self.toLang = toLang
        self.serviceType = serviceType
        self.createdAt = createdAt
    }
}

// MARK: - AI 翻译设置

/// AI 翻译设置
struct AITranslateSettings: Codable {
    var isEnabled: Bool
    var alias: String

    // 选词翻译快捷键
    var selectionHotKeyCode: UInt32
    var selectionHotKeyModifiers: UInt32

    // 输入翻译快捷键
    var inputHotKeyCode: UInt32
    var inputHotKeyModifiers: UInt32

    // 模型配置列表
    var modelConfigs: [AIModelConfig]

    // 翻译服务配置列表
    var serviceConfigs: [TranslateServiceConfig]

    // 默认语言设置
    var defaultFromLang: TranslateLanguage
    var defaultToLang: TranslateLanguage

    // 历史记录数量限制
    var historyLimit: Int

    // 面板尺寸
    var panelWidth: CGFloat
    var panelHeight: CGFloat

    static let `default` = AITranslateSettings(
        isEnabled: true,
        alias: "tr",
        selectionHotKeyCode: 0,
        selectionHotKeyModifiers: 0,
        inputHotKeyCode: 0,
        inputHotKeyModifiers: 0,
        modelConfigs: [],
        serviceConfigs: [
            .defaultAITranslate,
            .defaultWordTranslate,
        ],
        defaultFromLang: .auto,
        defaultToLang: .auto,
        historyLimit: 100,
        panelWidth: 600,
        panelHeight: 400
    )

    static func load() -> AITranslateSettings {
        if let data = UserDefaults.standard.data(forKey: "aiTranslateSettings"),
            let settings = try? JSONDecoder().decode(AITranslateSettings.self, from: data)
        {
            return settings
        }
        return .default
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "aiTranslateSettings")
        }
    }
}
