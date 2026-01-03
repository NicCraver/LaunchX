import AppKit
import Carbon
import Combine
import Foundation

/// Snippet 服务 - 负责监听键盘输入和文本替换
final class SnippetService: ObservableObject {
    static let shared = SnippetService()

    // MARK: - Published 属性

    @Published private(set) var snippets: [SnippetItem] = []
    @Published private(set) var isMonitoring: Bool = false

    // MARK: - 私有属性

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var inputBuffer: String = ""
    private let maxBufferSize = 50  // 最大缓冲区大小

    // 数据存储路径
    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let snippetDir = appSupport.appendingPathComponent("LaunchX/Snippets", isDirectory: true)
        try? FileManager.default.createDirectory(at: snippetDir, withIntermediateDirectories: true)
        return snippetDir
    }()

    private let snippetsFileURL: URL

    private init() {
        self.snippetsFileURL = storageURL.appendingPathComponent("snippets.json")
        loadSnippets()
        print("[SnippetService] Initialized with \(snippets.count) snippets")
    }

    // MARK: - 监听控制

    /// 开始监听键盘输入
    func startMonitoring() {
        guard !isMonitoring else { return }

        let settings = SnippetSettings.load()
        guard settings.isEnabled else {
            print("[SnippetService] Monitoring disabled in settings")
            return
        }

        // 检查是否有辅助功能权限
        guard checkAccessibilityPermission() else {
            print("[SnippetService] No accessibility permission")
            return
        }

        // 创建事件监听
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // 使用闭包捕获 self
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<SnippetService>.fromOpaque(refcon).takeUnretainedValue()
            return service.handleKeyEvent(proxy: proxy, type: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: refcon
            )
        else {
            print("[SnippetService] Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        isMonitoring = true
        print("[SnippetService] Started monitoring keyboard input")
    }

    /// 停止监听
    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        inputBuffer = ""
        isMonitoring = false
        print("[SnippetService] Stopped monitoring")
    }

    /// 重启监听
    func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    // MARK: - 事件处理

    private func handleKeyEvent(
        proxy: CGEventTapProxy, type: CGEventType, event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // 如果事件 tap 被禁用，重新启用
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // 只处理 keyDown 事件
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // 忽略带有修饰键的按键（除了 Shift）
        let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        if flags.contains(modifierMask) {
            return Unmanaged.passUnretained(event)
        }

        // 处理特殊按键
        if keyCode == 51 {  // Backspace
            if !inputBuffer.isEmpty {
                inputBuffer.removeLast()
            }
            return Unmanaged.passUnretained(event)
        }

        if keyCode == 36 || keyCode == 76 {  // Return / Enter
            inputBuffer = ""
            return Unmanaged.passUnretained(event)
        }

        if keyCode == 53 {  // Escape
            inputBuffer = ""
            return Unmanaged.passUnretained(event)
        }

        if keyCode == 48 {  // Tab
            inputBuffer = ""
            return Unmanaged.passUnretained(event)
        }

        if keyCode == 49 {  // Space
            inputBuffer = ""
            return Unmanaged.passUnretained(event)
        }

        // 获取按键字符
        guard let character = getCharacterFromKeyCode(keyCode: keyCode, flags: flags) else {
            return Unmanaged.passUnretained(event)
        }

        // 添加到缓冲区
        inputBuffer.append(character)

        // 限制缓冲区大小
        if inputBuffer.count > maxBufferSize {
            inputBuffer.removeFirst(inputBuffer.count - maxBufferSize)
        }

        // 检查是否匹配任何 snippet
        if let matchedSnippet = findMatchingSnippet() {
            // 找到匹配，执行替换
            DispatchQueue.main.async { [weak self] in
                self?.performReplacement(snippet: matchedSnippet)
            }
            // 阻止原始按键事件
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    /// 从 keyCode 获取字符
    private func getCharacterFromKeyCode(keyCode: Int64, flags: CGEventFlags) -> Character? {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let event = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        else {
            return nil
        }

        // 应用 Shift 修饰键
        if flags.contains(.maskShift) {
            event.flags = .maskShift
        }

        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)

        guard length > 0 else { return nil }
        return Character(UnicodeScalar(chars[0])!)
    }

    /// 查找匹配的 snippet
    private func findMatchingSnippet() -> SnippetItem? {
        for snippet in snippets where snippet.isEnabled {
            if inputBuffer.hasSuffix(snippet.keyword) {
                return snippet
            }
        }
        return nil
    }

    /// 执行文本替换
    private func performReplacement(snippet: SnippetItem) {
        let keyword = snippet.keyword
        let replacement = snippet.processedContent

        // 1. 删除已输入的关键词（包括最后一个字符，因为那个字符被我们阻止了）
        let deleteCount = keyword.count - 1  // -1 因为最后一个字符没有输入
        deleteCharacters(count: deleteCount)

        // 2. 等待删除完成后插入替换文本
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.insertText(replacement)
            self?.inputBuffer = ""
        }

        print("[SnippetService] Replaced '\(keyword)' with '\(replacement)'")
    }

    /// 删除指定数量的字符（模拟 Backspace）
    private func deleteCharacters(count: Int) {
        guard count > 0 else { return }

        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<count {
            // Backspace key down
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
            keyDown?.post(tap: .cghidEventTap)

            // Backspace key up
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    /// 插入文本
    private func insertText(_ text: String) {
        // 使用剪贴板方式插入（更可靠）
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 模拟 Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // V
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        // 恢复之前的剪贴板内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    /// 检查辅助功能权限
    private func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options =
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return trusted
    }

    // MARK: - Snippet 管理

    /// 添加新 snippet
    func addSnippet(_ snippet: SnippetItem) {
        snippets.insert(snippet, at: 0)
        saveSnippets()

        NotificationCenter.default.post(
            name: NSNotification.Name("SnippetsDidChange"), object: nil)
    }

    /// 更新 snippet
    func updateSnippet(_ snippet: SnippetItem) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            var updated = snippet
            updated = SnippetItem(
                id: snippet.id,
                name: snippet.name,
                keyword: snippet.keyword,
                content: snippet.content,
                isEnabled: snippet.isEnabled,
                createdAt: snippet.createdAt,
                updatedAt: Date()
            )
            snippets[index] = updated
            saveSnippets()

            NotificationCenter.default.post(
                name: NSNotification.Name("SnippetsDidChange"), object: nil)
        }
    }

    /// 删除 snippet
    func removeSnippet(_ snippet: SnippetItem) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()

        NotificationCenter.default.post(
            name: NSNotification.Name("SnippetsDidChange"), object: nil)
    }

    /// 删除多个 snippets
    func removeSnippets(_ snippetsToRemove: [SnippetItem]) {
        for snippet in snippetsToRemove {
            snippets.removeAll { $0.id == snippet.id }
        }
        saveSnippets()

        NotificationCenter.default.post(
            name: NSNotification.Name("SnippetsDidChange"), object: nil)
    }

    /// 切换启用状态
    func toggleEnabled(_ snippet: SnippetItem) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].isEnabled.toggle()
            saveSnippets()

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SnippetsDidChange"), object: nil)
            }
        }
    }

    /// 检查关键词是否已存在
    func isKeywordExists(_ keyword: String, excludingId: UUID? = nil) -> Bool {
        return snippets.contains { snippet in
            if let excludeId = excludingId, snippet.id == excludeId {
                return false
            }
            return snippet.keyword == keyword
        }
    }

    // MARK: - 搜索

    /// 搜索 snippets
    func search(query: String) -> [SnippetItem] {
        guard !query.isEmpty else { return snippets }

        let lowercased = query.lowercased()
        return snippets.filter { snippet in
            snippet.name.lowercased().contains(lowercased)
                || snippet.keyword.lowercased().contains(lowercased)
                || snippet.content.lowercased().contains(lowercased)
        }
    }

    // MARK: - 持久化

    private func loadSnippets() {
        guard let data = try? Data(contentsOf: snippetsFileURL),
            let loadedSnippets = try? JSONDecoder().decode([SnippetItem].self, from: data)
        else {
            // 如果没有数据，添加一些示例 snippets
            addDefaultSnippets()
            return
        }
        snippets = loadedSnippets
    }

    private func saveSnippets() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: snippetsFileURL)
        }
    }

    /// 添加默认示例 snippets
    private func addDefaultSnippets() {
        let defaults = [
            SnippetItem(
                name: "箭头",
                keyword: "::",
                content: ":="
            ),
            SnippetItem(
                name: "当前日期",
                keyword: "//date",
                content: "{date}"
            ),
            SnippetItem(
                name: "当前时间",
                keyword: "//time",
                content: "{time}"
            ),
            SnippetItem(
                name: "日期时间",
                keyword: "//now",
                content: "{datetime}"
            ),
        ]

        snippets = defaults
        saveSnippets()
    }
}
