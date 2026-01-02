import Carbon
import SwiftUI

// MARK: - 剪贴板设置视图

struct ClipboardSettingsView: View {
    @State private var settings = ClipboardSettings.load()
    @State private var showHotKeyPopover = false
    @State private var showPlainTextHotKeyPopover = false
    @State private var ignoredApps: [IgnoredAppInfo] = []
    @State private var showAppPicker = false
    @State private var itemCount: Int = 0
    @State private var totalSize: Int64 = 0

    private let labelWidth: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题行
                HStack {
                    Image("Extension_clipboard")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text("剪贴板")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $settings.isEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: settings.isEnabled) { _, newValue in
                            settings.save()
                            if newValue {
                                ClipboardService.shared.startMonitoring()
                            } else {
                                ClipboardService.shared.stopMonitoring()
                            }
                        }
                }

                Divider()

                // 快捷键设置
                Group {
                    HStack {
                        Text("打开剪贴板快捷键:")
                            .frame(width: labelWidth, alignment: .trailing)
                        ClipboardHotKeyButton(
                            keyCode: $settings.hotKeyCode,
                            modifiers: $settings.hotKeyModifiers,
                            showPopover: $showHotKeyPopover,
                            hotKeyType: "clipboard"
                        ) {
                            settings.save()
                            HotKeyService.shared.registerClipboardHotKey(
                                keyCode: settings.hotKeyCode,
                                modifiers: settings.hotKeyModifiers
                            )
                        }
                        Spacer()
                    }

                    HStack {
                        Text("纯文本粘贴快捷键:")
                            .frame(width: labelWidth, alignment: .trailing)
                        ClipboardHotKeyButton(
                            keyCode: $settings.plainTextHotKeyCode,
                            modifiers: $settings.plainTextHotKeyModifiers,
                            showPopover: $showPlainTextHotKeyPopover,
                            hotKeyType: "plainTextPaste"
                        ) {
                            settings.save()
                            HotKeyService.shared.registerPlainTextPasteHotKey(
                                keyCode: settings.plainTextHotKeyCode,
                                modifiers: settings.plainTextHotKeyModifiers
                            )
                        }
                        Spacer()
                    }
                }

                Divider()

                // 行为设置
                Group {
                    HStack {
                        Text("鼠标点击粘贴:")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("", selection: $settings.clickMode) {
                            ForEach(ClipboardClickMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                        .onChange(of: settings.clickMode) { _, _ in
                            settings.save()
                        }
                        Spacer()
                    }
                }

                Divider()

                // 存储设置
                Group {
                    HStack {
                        Text("记录保留条数:")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("", selection: $settings.historyLimit) {
                            ForEach(ClipboardHistoryLimit.allCases, id: \.self) { limit in
                                Text(limit.displayName).tag(limit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .onChange(of: settings.historyLimit) { _, _ in
                            settings.save()
                        }
                        Spacer()
                    }

                    HStack {
                        Text("记录保留时长:")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("", selection: $settings.retentionDays) {
                            ForEach(ClipboardRetentionDays.allCases, id: \.self) { days in
                                Text(days.displayName).tag(days)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .onChange(of: settings.retentionDays) { _, _ in
                            settings.save()
                        }
                        Spacer()
                    }

                    HStack {
                        Text("剪贴板容量限制:")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("", selection: $settings.capacityLimit) {
                            ForEach(ClipboardCapacityLimit.allCases, id: \.self) { limit in
                                Text(limit.displayName).tag(limit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .onChange(of: settings.capacityLimit) { _, _ in
                            settings.save()
                        }
                        Spacer()
                    }

                    // 统计信息
                    HStack {
                        Text("")
                            .frame(width: labelWidth, alignment: .trailing)
                        Text(
                            "已存储 \(itemCount) 条记录，占用 \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Divider()

                // 忽略应用列表
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("忽略以下应用")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { showAppPicker = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    Text("来自以下应用的剪贴板内容将不会被记录")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(ignoredApps, id: \.bundleId) { app in
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(app.name)
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { removeIgnoredApp(app.bundleId) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            loadIgnoredApps()
            updateStats()
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(onSelect: addIgnoredApp)
        }
    }

    private func loadIgnoredApps() {
        ignoredApps = settings.ignoredAppBundleIds.compactMap { bundleId in
            guard
                let appURL = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: bundleId)
            else {
                // 对于找不到应用的 Bundle ID，使用默认信息
                return IgnoredAppInfo(
                    bundleId: bundleId,
                    name: bundleId.components(separatedBy: ".").last ?? bundleId,
                    icon: NSImage(
                        systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
                )
            }
            let bundle = Bundle(url: appURL)
            let name =
                bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle?.infoDictionary?["CFBundleName"] as? String
                ?? bundleId
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return IgnoredAppInfo(bundleId: bundleId, name: name, icon: icon)
        }
    }

    private func addIgnoredApp(_ bundleId: String) {
        guard !settings.ignoredAppBundleIds.contains(bundleId) else { return }
        settings.ignoredAppBundleIds.append(bundleId)
        settings.save()
        loadIgnoredApps()
    }

    private func removeIgnoredApp(_ bundleId: String) {
        settings.ignoredAppBundleIds.removeAll { $0 == bundleId }
        settings.save()
        loadIgnoredApps()
    }

    private func updateStats() {
        itemCount = ClipboardService.shared.items.count
        totalSize = ClipboardService.shared.totalSize
    }
}

// MARK: - 忽略应用信息

struct IgnoredAppInfo {
    let bundleId: String
    let name: String
    let icon: NSImage
}

// MARK: - 剪贴板快捷键按钮

struct ClipboardHotKeyButton: View {
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
        Button(action: {
            showPopover = true
        }) {
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
            ClipboardHotKeyRecorderPopover(
                keyCode: $keyCode,
                modifiers: $modifiers,
                isPresented: $showPopover,
                hotKeyType: hotKeyType,
                onSave: onSave
            )
        }
    }
}

// MARK: - 剪贴板快捷键录制弹窗

struct ClipboardHotKeyRecorderPopover: View {
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
            // 示例提示
            HStack(spacing: 4) {
                Text("例如")
                    .foregroundColor(.secondary)
                    .font(.caption)
                KeyCapView(text: "⌃")
                KeyCapView(text: "⌥")
                KeyCapView(text: "V")
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
                    ForEach(HotKeyService.modifierSymbols(for: modifiers), id: \.self) { symbol in
                        KeyCapView(text: symbol)
                    }
                    KeyCapView(text: HotKeyService.keyString(for: keyCode))

                    Button {
                        keyCode = 0
                        modifiers = 0
                        onSave()
                        if hotKeyType == "clipboard" {
                            HotKeyService.shared.unregisterClipboardHotKey()
                        } else {
                            HotKeyService.shared.unregisterPlainTextPasteHotKey()
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
                if hotKeyType == "clipboard" {
                    HotKeyService.shared.unregisterClipboardHotKey()
                } else {
                    HotKeyService.shared.unregisterPlainTextPasteHotKey()
                }
                stopRecording()
                isPresented = false
                return nil
            }

            let mods = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { return event }

            let code = UInt32(event.keyCode)

            // 检查冲突
            if let conflict = HotKeyService.shared.checkHotKeyConflict(
                keyCode: code, modifiers: mods, excludeType: hotKeyType)
            {
                conflictMessage = conflict
                return nil
            }

            // 设置快捷键
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

// MARK: - 应用选择器

struct AppPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    @State private var apps: [InstalledAppInfo] = []
    @State private var searchText = ""
    @State private var isLoading = true

    var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("选择应用")
                    .font(.headline)
                Spacer()
                Button("取消") {
                    dismiss()
                }
            }
            .padding()

            // 搜索框
            TextField("搜索应用", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            // 应用列表
            if isLoading {
                Spacer()
                ProgressView("加载应用列表...")
                Spacer()
            } else {
                List(filteredApps, id: \.bundleId) { app in
                    Button(action: {
                        onSelect(app.bundleId)
                        dismiss()
                    }) {
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text(app.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadAllInstalledApps()
        }
    }

    private func loadAllInstalledApps() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var allApps: [InstalledAppInfo] = []
            var seenBundleIds = Set<String>()

            // 扫描的目录
            let appDirectories = [
                "/Applications",
                "/System/Applications",
                NSHomeDirectory() + "/Applications",
            ]

            let fileManager = FileManager.default

            for directory in appDirectories {
                guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
                    continue
                }

                for item in contents {
                    guard item.hasSuffix(".app") else { continue }

                    let appPath = (directory as NSString).appendingPathComponent(item)
                    let appURL = URL(fileURLWithPath: appPath)

                    // 获取 bundle 信息
                    guard let bundle = Bundle(url: appURL),
                        let bundleId = bundle.bundleIdentifier,
                        !seenBundleIds.contains(bundleId)
                    else {
                        continue
                    }

                    seenBundleIds.insert(bundleId)

                    // 获取应用名称
                    let name =
                        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? (item as NSString).deletingPathExtension

                    // 获取图标
                    let icon = NSWorkspace.shared.icon(forFile: appPath)

                    allApps.append(InstalledAppInfo(bundleId: bundleId, name: name, icon: icon))
                }
            }

            // 按名称排序
            allApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.apps = allApps
                self.isLoading = false
            }
        }
    }
}

struct InstalledAppInfo {
    let bundleId: String
    let name: String
    let icon: NSImage
}

#Preview {
    ClipboardSettingsView()
        .frame(width: 600, height: 700)
}
