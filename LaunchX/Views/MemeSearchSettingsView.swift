import Carbon
import SwiftUI

// MARK: - 表情包搜索设置视图

struct MemeSearchSettingsView: View {
    @State private var settings = MemeSearchSettings.load()
    @State private var showHotKeyPopover = false

    private let labelWidth: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题行
                HStack {
                    Image(systemName: "face.smiling")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.orange)
                    Text("表情包搜索")
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
                HStack {
                    Text("直接打开扩展快捷键:")
                        .frame(width: labelWidth, alignment: .trailing)
                    MemeHotKeyButton(settings: $settings, showPopover: $showHotKeyPopover)
                    Spacer()
                }

                // 别名设置
                HStack {
                    Text("别名:")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("bqb", text: $settings.alias)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: settings.alias) { _, _ in
                            settings.save()
                        }
                    Spacer()
                }

                Divider()

                // 使用说明
                VStack(alignment: .leading, spacing: 10) {
                    Text("使用说明")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("输入别名或使用快捷键进入表情包搜索模式")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("输入关键词搜索表情包")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("使用方向键移动选择，回车复制到剪贴板")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("4.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("也可以双击表情包直接复制")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // 数据来源说明
                VStack(alignment: .leading, spacing: 6) {
                    Text("数据来源")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("表情包数据来自 doutupk.com，仅供娱乐使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

// MARK: - 表情包快捷键按钮

struct MemeHotKeyButton: View {
    @Binding var settings: MemeSearchSettings
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
            MemeHotKeyRecorderPopover(settings: $settings, isPresented: $showPopover)
        }
    }
}

// MARK: - 表情包快捷键录制弹窗

struct MemeHotKeyRecorderPopover: View {
    @Binding var settings: MemeSearchSettings
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
                KeyCapView(text: "M")
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
                        HotKeyService.shared.unregisterMemeHotKey()
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
            startListening()
        }
        .onDisappear {
            stopListening()
            HotKeyService.shared.resumeAllHotKeys()
        }
    }

    private func startListening() {
        conflictMessage = nil
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc 键取消
            if event.keyCode == kVK_Escape {
                stopListening()
                isPresented = false
                return nil
            }

            // Delete 键清除快捷键
            if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
                settings.hotKeyCode = 0
                settings.hotKeyModifiers = 0
                settings.save()
                HotKeyService.shared.unregisterMemeHotKey()
                stopListening()
                isPresented = false
                return nil
            }

            // 使用 Carbon 修饰键格式
            let modifiers = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return event }

            let keyCode = UInt32(event.keyCode)

            // 检查快捷键冲突
            if let conflict = HotKeyService.shared.checkHotKeyConflict(
                keyCode: keyCode, modifiers: modifiers, excludeType: "meme")
            {
                conflictMessage = conflict
                return nil
            }

            // 设置快捷键
            settings.hotKeyCode = keyCode
            settings.hotKeyModifiers = modifiers
            settings.save()

            // 注册快捷键
            HotKeyService.shared.registerMemeHotKey(keyCode: keyCode, modifiers: modifiers)

            stopListening()
            isPresented = false
            return nil
        }
    }

    private func stopListening() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}

#Preview {
    MemeSearchSettingsView()
        .frame(width: 600, height: 500)
}
