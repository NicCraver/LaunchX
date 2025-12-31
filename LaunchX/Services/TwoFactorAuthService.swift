import AppKit
import Foundation
import SQLite3

// MARK: - 2FA 验证码项目

struct TwoFactorCodeItem: Identifiable, Hashable {
    let id: UUID
    let code: String
    let sender: String
    let fullMessage: String
    let receivedAt: Date
    let messageRowId: Int64  // 用于删除

    init(code: String, sender: String, fullMessage: String, receivedAt: Date, messageRowId: Int64) {
        self.id = UUID()
        self.code = code
        self.sender = sender
        self.fullMessage = fullMessage
        self.receivedAt = receivedAt
        self.messageRowId = messageRowId
    }

    /// 格式化的接收时间
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: receivedAt, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
        hasher.combine(messageRowId)
    }

    static func == (lhs: TwoFactorCodeItem, rhs: TwoFactorCodeItem) -> Bool {
        lhs.code == rhs.code && lhs.messageRowId == rhs.messageRowId
    }
}

// MARK: - 2FA 设置

struct TwoFactorAuthSettings: Codable {
    var isEnabled: Bool
    var alias: String  // 别名，如 "2fa"
    var deleteAfterCopy: Bool  // 复制后删除短信
    var timeSpanMinutes: Int  // 搜索时间范围（分钟）
    var hotKeyCode: UInt32  // 快捷键 keyCode
    var hotKeyModifiers: UInt32  // 快捷键修饰键

    static let `default` = TwoFactorAuthSettings(
        isEnabled: true,
        alias: "2fa",
        deleteAfterCopy: false,
        timeSpanMinutes: 60,  // 默认最近 1 小时
        hotKeyCode: 0,
        hotKeyModifiers: 0
    )

    static func load() -> TwoFactorAuthSettings {
        if let data = UserDefaults.standard.data(forKey: "twoFactorAuthSettings"),
            let settings = try? JSONDecoder().decode(TwoFactorAuthSettings.self, from: data)
        {
            return settings
        }
        return .default
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "twoFactorAuthSettings")
        }
    }
}

// MARK: - 2FA 服务

final class TwoFactorAuthService {
    static let shared = TwoFactorAuthService()

    private let chatDbPath: String
    private var db: OpaquePointer?

    // 验证码正则表达式（匹配 4-8 位数字验证码）
    private let codePatterns: [NSRegularExpression] = {
        let patterns = [
            // 常见验证码格式
            "(?:验证码|校验码|确认码|动态码|安全码|授权码|取件码|提取码)[：:是为]?\\s*([0-9]{4,8})",
            "(?:code|Code|CODE)[：:is\\s]*([0-9]{4,8})",
            "([0-9]{4,8})\\s*(?:是|为)?(?:您的)?(?:验证码|校验码|确认码|动态码)",
            // 纯数字（4-8位，前后有空格或特殊字符分隔）
            "(?:^|\\s|[【\\[\\(（])([0-9]{4,8})(?:$|\\s|[】\\]\\)）])",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    private init() {
        self.chatDbPath = NSHomeDirectory() + "/Library/Messages/chat.db"
    }

    // MARK: - 权限检查

    /// 检查是否有完全磁盘访问权限
    func checkFullDiskAccess() -> Bool {
        let fileManager = FileManager.default
        return fileManager.isReadableFile(atPath: chatDbPath)
    }

    // MARK: - 获取验证码

    /// 获取最近的 2FA 验证码
    func getRecentCodes(timeSpanMinutes: Int = 60) -> [TwoFactorCodeItem] {
        guard openDatabase() else {
            print("[TwoFactorAuthService] Failed to open database")
            return []
        }
        defer { closeDatabase() }

        var codes: [TwoFactorCodeItem] = []

        // 计算时间范围（macOS 使用 Core Data 时间戳，从 2001-01-01 开始）
        let now = Date()
        let timeSpan = TimeInterval(timeSpanMinutes * 60)
        let startTime = now.timeIntervalSinceReferenceDate - timeSpan
        let startTimeNano = Int64(startTime * 1_000_000_000)

        // 查询最近的短信（SMS，非 iMessage）
        // is_from_me = 0 表示收到的消息
        // service = 'SMS' 表示短信
        let query = """
            SELECT
                m.ROWID,
                m.text,
                m.attributedBody,
                m.date,
                h.id as sender
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.is_from_me = 0
                AND m.date > ?
            ORDER BY m.date DESC
            LIMIT 100
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print(
                "[TwoFactorAuthService] Failed to prepare statement: \(String(cString: sqlite3_errmsg(db)))"
            )
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, startTimeNano)

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(statement, 0)

            // 获取消息文本
            var messageText: String?

            // 首先尝试 text 列
            if let textPtr = sqlite3_column_text(statement, 1) {
                messageText = String(cString: textPtr)
            }

            // 如果 text 为空，尝试从 attributedBody 解析（macOS Ventura+）
            if messageText == nil || messageText?.isEmpty == true {
                if let blobPointer = sqlite3_column_blob(statement, 2) {
                    let blobSize = sqlite3_column_bytes(statement, 2)
                    let data = Data(bytes: blobPointer, count: Int(blobSize))
                    messageText = extractTextFromAttributedBody(data)
                }
            }

            guard let text = messageText, !text.isEmpty else { continue }

            // 获取发送者
            var sender = "未知"
            if let senderPtr = sqlite3_column_text(statement, 4) {
                sender = String(cString: senderPtr)
            }

            // 获取时间
            let dateValue = sqlite3_column_int64(statement, 3)
            let receivedAt = Date(timeIntervalSinceReferenceDate: Double(dateValue) / 1_000_000_000)

            // 尝试提取验证码
            if let code = extractVerificationCode(from: text) {
                let item = TwoFactorCodeItem(
                    code: code,
                    sender: sender,
                    fullMessage: text,
                    receivedAt: receivedAt,
                    messageRowId: rowId
                )
                codes.append(item)
            }
        }

        return codes
    }

    // MARK: - 删除消息

    /// 删除指定的消息（需要写入权限）
    func deleteMessage(rowId: Int64) -> Bool {
        // 注意：直接删除 chat.db 中的消息可能会导致同步问题
        // 这里只是标记为已读或使用其他方式处理
        // 实际删除需要通过 Apple Script 或其他方式

        let script = """
            tell application "Messages"
                -- Messages app doesn't provide direct deletion API
                -- This is a placeholder for future implementation
            end tell
            """

        // 由于 Messages app 没有提供删除 API，这里返回 false
        // 未来可以考虑使用其他方式实现
        print("[TwoFactorAuthService] Message deletion is not supported yet")
        return false
    }

    // MARK: - 私���方法

    private func openDatabase() -> Bool {
        guard sqlite3_open_v2(chatDbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("[TwoFactorAuthService] Cannot open database at \(chatDbPath)")
            return false
        }
        return true
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    /// 从 attributedBody 中提取文本（macOS Ventura+）
    private func extractTextFromAttributedBody(_ data: Data) -> String? {
        // attributedBody 是一个 NSKeyedArchiver 归档的 NSAttributedString
        // 需要解档才能获取文本

        // 尝试使用 NSKeyedUnarchiver 解档
        do {
            // 首先检查是否是 streamtyped 格式
            if data.count > 0 {
                // 尝试作为 NSAttributedString 解档
                if let attributedString = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSAttributedString.self, from: data)
                {
                    return attributedString.string
                }

                // 如果失败，尝试查找纯文本
                // attributedBody 中的文本通常在特定位置
                if let string = String(data: data, encoding: .utf8) {
                    // 清理控制字符
                    let cleaned = string.components(separatedBy: CharacterSet.controlCharacters)
                        .joined()
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }
        }
        return nil
    }

    /// 从消息文本中提取验证码
    private func extractVerificationCode(from text: String) -> String? {
        for pattern in codePatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                // 获取捕获组（验证码数字）
                if match.numberOfRanges > 1 {
                    let codeRange = match.range(at: 1)
                    if let swiftRange = Range(codeRange, in: text) {
                        return String(text[swiftRange])
                    }
                }
            }
        }

        // 如果没有匹配到特定模式，尝试查找独立的 4-8 位数字
        let fallbackPattern = try? NSRegularExpression(pattern: "\\b([0-9]{4,8})\\b", options: [])
        if let pattern = fallbackPattern {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if match.numberOfRanges > 1 {
                    let codeRange = match.range(at: 1)
                    if let swiftRange = Range(codeRange, in: text) {
                        let code = String(text[swiftRange])
                        // 额外检查：确保消息看起来像是验证码短信
                        let keywords = [
                            "验证", "码", "code", "Code", "CODE", "校验", "确认", "动态", "安全", "登录", "注册",
                        ]
                        let lowerText = text.lowercased()
                        if keywords.contains(where: { lowerText.contains($0.lowercased()) }) {
                            return code
                        }
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - 复制到剪贴板

extension TwoFactorCodeItem {
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
    }
}
