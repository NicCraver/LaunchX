import Carbon
import SwiftUI

// MARK: - 高级扩展类型

enum AdvancedExtensionType: String, CaseIterable, Identifiable {
    case bookmarkSearch = "搜索书签"
    case terminalCommand = "执行终端命令"
    case clipboard = "剪贴板与 Snippet"
    case twoFactorAuth = "2FA 短信"
    case aiTranslate = "AI 翻译"

    var id: String { rawValue }

    /// 资源图标名称
    var iconImageName: String {
        switch self {
        case .bookmarkSearch: return "Extension_bookmark"
        case .terminalCommand: return "Extension_terminal"
        case .clipboard: return "Extension_clipboard"
        case .twoFactorAuth: return "Extension_2FA"
        case .aiTranslate: return "Extension_ai_translate"
        }
    }
}

// MARK: - 高级扩展设置视图

struct AdvancedExtensionsView: View {
    @State private var selectedExtension: AdvancedExtensionType = .bookmarkSearch

    var body: some View {
        HSplitView {
            // 左侧：扩展列表
            extensionList
                .frame(minWidth: 180, maxWidth: 200)

            // 右侧：扩展设置
            extensionSettings
                .frame(minWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 左侧扩展列表

    private var extensionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AdvancedExtensionType.allCases) { type in
                ExtensionSidebarItem(
                    iconImageName: type.iconImageName,
                    title: type.rawValue,
                    isSelected: selectedExtension == type
                ) {
                    selectedExtension = type
                }
            }
            Spacer()
        }
        .padding(.top, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - 右侧扩展设置

    @ViewBuilder
    private var extensionSettings: some View {
        switch selectedExtension {
        case .bookmarkSearch:
            BookmarkSearchSettingsView()
        case .terminalCommand:
            ComingSoonView(title: "执行终端命令", description: "快速执行常用终端命令")
        case .clipboard:
            ComingSoonView(title: "剪贴板与 Snippet", description: "管理剪贴板历史和代码片段")
        case .twoFactorAuth:
            ComingSoonView(title: "2FA 短信", description: "快速获取手机短信验证码")
        case .aiTranslate:
            ComingSoonView(title: "AI 翻译", description: "使用 AI 进行智能翻译")
        }
    }
}

// MARK: - 即将推出占位视图

struct ComingSoonView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.medium)

            Text(description)
                .foregroundColor(.secondary)

            Text("即将推出")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 书签搜索设置视图

struct BookmarkSearchSettingsView: View {
    @State private var settings = BookmarkSettings.load()
    @State private var bookmarkCount: Int = 0
    @State private var safariAccessible: Bool = true
    @State private var showHotKeyPopover: Bool = false

    private let labelWidth: CGFloat = 140

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "bookmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    Text("搜索书签")
                        .font(.headline)
                    Spacer()

                    // 启用开关
                    Toggle("", isOn: $settings.isEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: settings.isEnabled) { _, _ in
                            settings.save()
                        }
                }

                Divider()

                // 快捷键设置
                HStack {
                    Text("直接打开扩展快捷键:")
                        .frame(width: labelWidth, alignment: .trailing)
                    BookmarkHotKeyButton(settings: $settings, showPopover: $showHotKeyPopover)
                    Spacer()
                }

                // 别名
                HStack {
                    Text("别名:")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("bk", text: $settings.alias)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: settings.alias) { _, _ in
                            settings.save()
                        }
                    Spacer()
                }

                // 打开浏览器
                HStack {
                    Text("打开浏览器:")
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker("", selection: $settings.openWith) {
                        ForEach(BookmarkOpenWith.allCases, id: \.self) { option in
                            HStack(spacing: 6) {
                                Image(nsImage: resizeIcon(option.icon, to: 16))
                                Text(option.displayName)
                            }
                            .tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .onChange(of: settings.openWith) { _, _ in
                        settings.save()
                    }
                    Spacer()
                }

                Divider()

                // 搜索浏览器
                VStack(alignment: .leading, spacing: 10) {
                    Text("搜索浏览器")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Safari
                    BrowserToggleRow(
                        source: .safari,
                        isEnabled: settings.enabledSources.contains(.safari),
                        isAccessible: safariAccessible
                    ) { enabled in
                        updateSourceEnabled(.safari, enabled: enabled)
                    }

                    // Chrome
                    BrowserToggleRow(
                        source: .chrome,
                        isEnabled: settings.enabledSources.contains(.chrome),
                        isAccessible: true
                    ) { enabled in
                        updateSourceEnabled(.chrome, enabled: enabled)
                    }

                    // 书签统计和刷新
                    HStack {
                        Text("已索引书签: \(bookmarkCount) 个")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("刷新") {
                            refreshBookmarks()
                        }
                        .font(.caption)
                    }
                    .padding(.top, 4)
                }

                // 权限提示
                if !safariAccessible {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("需要完全磁盘访问权限才能读取 Safari 书签")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("打开设置") {
                            openFullDiskAccessSettings()
                        }
                        .font(.caption)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            checkAccess()
            refreshBookmarks()
        }
    }

    private func resizeIcon(_ icon: NSImage, to size: CGFloat) -> NSImage {
        let resized = NSImage(size: NSSize(width: size, height: size))
        resized.lockFocus()
        icon.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .copy,
            fraction: 1.0)
        resized.unlockFocus()
        return resized
    }

    private func updateSourceEnabled(_ source: BookmarkSource, enabled: Bool) {
        if enabled {
            if !settings.enabledSources.contains(source) {
                settings.enabledSources.append(source)
            }
        } else {
            settings.enabledSources.removeAll { $0 == source }
        }
        settings.save()
        refreshBookmarks()
    }

    private func checkAccess() {
        safariAccessible = BookmarkService.shared.checkFullDiskAccess()
    }

    private func refreshBookmarks() {
        BookmarkService.shared.clearCache()
        let bookmarks = BookmarkService.shared.getAllBookmarks(forceReload: true)
        bookmarkCount = bookmarks.count
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 书签快捷键按钮（与网页直达样式一致）

struct BookmarkHotKeyButton: View {
    @Binding var settings: BookmarkSettings
    @Binding var showPopover: Bool
    @State private var isHovered = false

    private var hasHotKey: Bool {
        settings.hotKeyCode != 0
    }

    var body: some View {
        Button(action: {
            showPopover = true
        }) {
            Group {
                if hasHotKey {
                    HStack(spacing: 2) {
                        ForEach(
                            HotKeyService.modifierSymbols(for: settings.hotKeyModifiers), id: \.self
                        ) { symbol in
                            KeyCapViewSettings(text: symbol)
                        }
                        KeyCapViewSettings(text: HotKeyService.keyString(for: settings.hotKeyCode))
                    }
                } else {
                    Text("快捷键")
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
            BookmarkHotKeyRecorderPopover(settings: $settings, isPresented: $showPopover)
        }
    }
}

// MARK: - 书签快捷键录制弹窗

struct BookmarkHotKeyRecorderPopover: View {
    @Binding var settings: BookmarkSettings
    @Binding var isPresented: Bool
    @State private var keyDownMonitor: Any?
    @State private var conflictMessage: String?

    private var hasHotKey: Bool {
        settings.hotKeyCode != 0
    }

    var body: some View {
        VStack(spacing: 12) {
            // 示例提示
            HStack(spacing: 4) {
                Text("例如")
                    .foregroundColor(.secondary)
                    .font(.caption)
                KeyCapView(text: "⌃")
                KeyCapView(text: "⌥")
                KeyCapView(text: "B")
            }
            .padding(.top, 8)

            // 提示文字或冲突信息
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
                    ForEach(
                        HotKeyService.modifierSymbols(for: settings.hotKeyModifiers), id: \.self
                    ) { symbol in
                        KeyCapView(text: symbol)
                    }
                    KeyCapView(text: HotKeyService.keyString(for: settings.hotKeyCode))

                    Button {
                        settings.hotKeyCode = 0
                        settings.hotKeyModifiers = 0
                        settings.save()
                        HotKeyService.shared.unregisterBookmarkHotKey()
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
                settings.hotKeyCode = 0
                settings.hotKeyModifiers = 0
                settings.save()
                HotKeyService.shared.unregisterBookmarkHotKey()
                stopRecording()
                isPresented = false
                return nil
            }

            let modifiers = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return event }

            let keyCode = UInt32(event.keyCode)

            // 检查冲突
            if let conflict = HotKeyService.shared.checkConflict(
                keyCode: keyCode, modifiers: modifiers, excludingMainHotKey: false)
            {
                conflictMessage = conflict
                return nil
            }

            // 设置快捷键
            settings.hotKeyCode = keyCode
            settings.hotKeyModifiers = modifiers
            settings.save()
            HotKeyService.shared.registerBookmarkHotKey(keyCode: keyCode, modifiers: modifiers)
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

// MARK: - 浏览器开关行

struct BrowserToggleRow: View {
    let source: BookmarkSource
    let isEnabled: Bool
    let isAccessible: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { isEnabled },
                    set: { onToggle($0) }
                )
            )
            .toggleStyle(.checkbox)
            .disabled(!isAccessible)

            Image(nsImage: source.icon)

            Text(source.displayName)
                .font(.system(size: 13))
                .opacity(isAccessible ? 1 : 0.5)

            if !isAccessible {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 扩展侧边栏项

struct ExtensionSidebarItem: View {
    let iconImageName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(iconImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(.horizontal, 8)
    }
}

#Preview {
    AdvancedExtensionsView()
        .frame(width: 700, height: 500)
}
