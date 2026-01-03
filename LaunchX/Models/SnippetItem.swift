import Foundation

// MARK: - Snippet 项目

/// Snippet 项目（文本片段）
struct SnippetItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String  // 片段名称
    var keyword: String  // 触发关键词（如 "::date", ";;email"）
    var content: String  // 替换内容
    var isEnabled: Bool  // 是否启用
    var createdAt: Date  // 创建时间
    var updatedAt: Date  // 更新时间

    init(
        id: UUID = UUID(),
        name: String,
        keyword: String,
        content: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.content = content
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - 动态内容支持

    /// 处理动态内容（如日期、时间等）
    var processedContent: String {
        var result = content

        let now = Date()
        let calendar = Calendar.current

        // 日期格式化
        let dateFormatter = DateFormatter()

        // {date} - 当前日期 (yyyy-MM-dd)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))

        // {date_cn} - 中文日期 (yyyy年MM月dd日)
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        result = result.replacingOccurrences(
            of: "{date_cn}", with: dateFormatter.string(from: now))

        // {time} - 当前时间 (HH:mm:ss)
        dateFormatter.dateFormat = "HH:mm:ss"
        result = result.replacingOccurrences(of: "{time}", with: dateFormatter.string(from: now))

        // {time_short} - 当前时间 (HH:mm)
        dateFormatter.dateFormat = "HH:mm"
        result = result.replacingOccurrences(
            of: "{time_short}", with: dateFormatter.string(from: now))

        // {datetime} - 日期时间 (yyyy-MM-dd HH:mm:ss)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        result = result.replacingOccurrences(
            of: "{datetime}", with: dateFormatter.string(from: now))

        // {year} - 当前年份
        result = result.replacingOccurrences(
            of: "{year}", with: String(calendar.component(.year, from: now)))

        // {month} - 当前月份
        result = result.replacingOccurrences(
            of: "{month}", with: String(format: "%02d", calendar.component(.month, from: now)))

        // {day} - 当前日期
        result = result.replacingOccurrences(
            of: "{day}", with: String(format: "%02d", calendar.component(.day, from: now)))

        // {weekday} - 星期几
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = calendar.component(.weekday, from: now)
        result = result.replacingOccurrences(of: "{weekday}", with: "星期\(weekdays[weekday - 1])")

        // {timestamp} - Unix 时间戳
        result = result.replacingOccurrences(
            of: "{timestamp}", with: String(Int(now.timeIntervalSince1970)))

        // {uuid} - 生成新的 UUID
        result = result.replacingOccurrences(of: "{uuid}", with: UUID().uuidString)

        // {uuid_short} - 短 UUID（前 8 位）
        result = result.replacingOccurrences(
            of: "{uuid_short}", with: String(UUID().uuidString.prefix(8)))

        return result
    }

    // MARK: - 显示相关

    /// 内容预览（最多显示 50 个字符）
    var contentPreview: String {
        let cleaned =
            content
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 50 {
            return String(cleaned.prefix(50)) + "..."
        }
        return cleaned
    }

    /// 是否包含动态变量
    var hasDynamicContent: Bool {
        let dynamicPatterns = [
            "{date}", "{date_cn}", "{time}", "{time_short}", "{datetime}",
            "{year}", "{month}", "{day}", "{weekday}",
            "{timestamp}", "{uuid}", "{uuid_short}",
        ]
        return dynamicPatterns.contains { content.contains($0) }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SnippetItem, rhs: SnippetItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Snippet 设置

/// Snippet 设置
struct SnippetSettings: Codable {
    var isEnabled: Bool  // 是否启用 Snippet 功能
    var alias: String  // 搜索别名（如 "sn"）

    static let `default` = SnippetSettings(
        isEnabled: true,
        alias: "sn"
    )

    static func load() -> SnippetSettings {
        if let data = UserDefaults.standard.data(forKey: "snippetSettings"),
            let settings = try? JSONDecoder().decode(SnippetSettings.self, from: data)
        {
            return settings
        }
        return .default
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "snippetSettings")
        }
    }
}
