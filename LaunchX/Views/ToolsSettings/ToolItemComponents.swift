import Carbon
import SwiftUI

struct ToolItemRow: View {
    @Binding var tool: ToolItem
    let viewModel: ToolsViewModel  // 移除 @ObservedObject 避免不必要的重绘
    let isEvenRow: Bool
    var focusedField: FocusState<UUID?>.Binding
    var onEdit: (() -> Void)?

    @State private var aliasText: String = ""
    @State private var showHotKeyPopover = false
    @State private var showExtensionHotKeyPopover = false
    @State private var displayIcon: NSImage?  // 缓存图标

    /// 是否显示打开快捷键（实用工具不显示）
    private var showOpenHotKey: Bool {
        tool.type != .utility
    }

    /// 是否显示进入扩展快捷键
    private var showExtensionHotKey: Bool {
        tool.type == .utility || tool.isIDE || tool.supportsQueryExtension
    }

    /// 是否可以删除（内置工具不能删除）
    private var canDelete: Bool {
        !tool.isBuiltIn
    }

    /// 当前显示的图标（优先使用缓存）
    private var currentIcon: NSImage {
        displayIcon ?? tool.type.defaultIcon
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标和名称
            HStack(spacing: 8) {
                Image(nsImage: currentIcon)
                    .resizable()
                    .frame(width: 20, height: 20)

                if tool.type == .webLink, let onEdit = onEdit {
                    // 网页直达：点击名称可编辑
                    Button(action: onEdit) {
                        Text(tool.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .help("点击编辑")
                } else if tool.type == .systemCommand {
                    // 系统命令：显示动态名称
                    Text(tool.displayName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(tool.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // 显示在搜索面板的标识
                if tool.showInSearchPanel == true {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .help("已配置为默认搜索")
                }
            }
            .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)

            // 别名输入（内置工具只读）
            if tool.isBuiltIn {
                Text(tool.alias ?? "-")
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
            } else {
                ToolAliasTextField(
                    text: $aliasText,
                    placeholder: "别名",
                    toolId: tool.id,
                    focusedField: focusedField
                )
                .frame(width: 70)
                .onAppear {
                    aliasText = tool.alias ?? ""
                }
                .onChange(of: tool.alias) { _, newValue in
                    // 当 tool.alias 被外部更新时（如编辑弹窗），同步更新本地状态
                    let newAlias = newValue ?? ""
                    if aliasText != newAlias {
                        aliasText = newAlias
                    }
                }
                .onChange(of: aliasText) { _, newValue in
                    var updatedTool = tool
                    updatedTool.alias = newValue.isEmpty ? nil : newValue
                    viewModel.updateTool(updatedTool)
                }
            }

            // 打开快捷键（实用工具不显示）
            if showOpenHotKey {
                ToolHotKeyButton(
                    hotKey: tool.hotKey,
                    onTap: { showHotKeyPopover = true }
                )
                .frame(width: 130)
                .popover(isPresented: $showHotKeyPopover) {
                    ToolHotKeyRecorderPopover(
                        hotKey: Binding(
                            get: { tool.hotKey },
                            set: { newValue in
                                tool.hotKey = newValue
                                viewModel.updateTool(tool)
                            }
                        ),
                        toolId: tool.id,
                        isExtensionHotKey: false,
                        isPresented: $showHotKeyPopover
                    )
                }
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 130)
            }

            // 进入扩展快捷键
            if showExtensionHotKey {
                ToolHotKeyButton(
                    hotKey: tool.extensionHotKey,
                    onTap: { showExtensionHotKeyPopover = true }
                )
                .frame(width: 130)
                .popover(isPresented: $showExtensionHotKeyPopover) {
                    ToolHotKeyRecorderPopover(
                        hotKey: Binding(
                            get: { tool.extensionHotKey },
                            set: { newValue in
                                tool.extensionHotKey = newValue
                                viewModel.updateTool(tool)
                            }
                        ),
                        toolId: tool.id,
                        isExtensionHotKey: true,
                        isPresented: $showExtensionHotKeyPopover
                    )
                }
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 130)
            }

            // 启用开关
            Toggle(
                "",
                isOn: Binding(
                    get: { tool.isEnabled },
                    set: { newValue in
                        var updatedTool = tool
                        updatedTool.isEnabled = newValue
                        viewModel.updateTool(updatedTool)
                    }
                )
            )
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .scaleEffect(0.7)
            .frame(width: 44)

            // 删除按钮（内置工具不显示）
            if canDelete {
                Button(action: { viewModel.deleteTool(tool) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 30)
            } else {
                Spacer()
                    .frame(width: 30)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isEvenRow ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .contentShape(Rectangle())
        .onAppear {
            // 使用全局缓存加载图标
            IconCacheManager.shared.loadIcon(for: tool) { icon in
                self.displayIcon = icon
            }
        }
    }
}

// MARK: - 别名输入框

struct ToolAliasTextField: View {
    @Binding var text: String
    let placeholder: String
    let toolId: UUID
    var focusedField: FocusState<UUID?>.Binding

    @State private var isHovered = false

    private var isFocused: Bool {
        focusedField.wrappedValue == toolId
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .focused(focusedField, equals: toolId)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        (isHovered || isFocused) ? Color.secondary.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - 快捷键按钮

struct ToolHotKeyButton: View {
    let hotKey: HotKeyConfig?
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Group {
                if let hotKey = hotKey {
                    HStack(spacing: 2) {
                        ForEach(HotKeyService.modifierSymbols(for: hotKey.modifiers), id: \.self) {
                            symbol in
                            KeyCapView(text: symbol, size: .small)
                        }
                        KeyCapView(text: HotKeyService.keyString(for: hotKey.keyCode), size: .small)
                    }
                } else {
                    Text("快捷键")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        (isHovered && hotKey == nil) ? Color.secondary.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 快捷键录制弹窗

struct ToolHotKeyRecorderPopover: View {
    @Binding var hotKey: HotKeyConfig?
    let toolId: UUID
    let isExtensionHotKey: Bool
    @Binding var isPresented: Bool

    @State private var conflictMessage: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 12) {
            // 示例提示
            HStack(spacing: 4) {
                Text("例子")
                    .foregroundColor(.secondary)
                KeyCapViewLarge(text: "⌘")
                KeyCapViewLarge(text: "⇧")
                KeyCapViewLarge(text: "K")
            }
            .padding(.top, 8)

            // 提示文字或冲突信息
            if let conflict = conflictMessage {
                Text("快捷键已被「\(conflict)」使用")
                    .foregroundColor(.red)
                    .font(.system(size: 13))
            } else {
                Text("请输入快捷键...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // 已设置快捷键时显示
            if let currentHotKey = hotKey {
                HStack(spacing: 4) {
                    ForEach(HotKeyService.modifierSymbols(for: currentHotKey.modifiers), id: \.self)
                    { symbol in
                        KeyCapViewLarge(text: symbol)
                    }
                    KeyCapViewLarge(text: HotKeyService.keyString(for: currentHotKey.keyCode))

                    // 删除按钮
                    Button {
                        hotKey = nil
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(width: 280)
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

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Escape 取消
            if event.keyCode == kVK_Escape {
                self.stopRecording()
                self.isPresented = false
                return nil
            }

            // Delete 清除
            if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
                self.hotKey = nil
                self.stopRecording()
                self.isPresented = false
                return nil
            }

            // 必须有修饰键
            let modifiers = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else {
                return event
            }

            let keyCode = UInt32(event.keyCode)

            // 检查冲突
            if let conflict = HotKeyService.shared.checkConflict(
                keyCode: keyCode,
                modifiers: modifiers,
                excludingItemId: self.toolId,
                excludingIsExtension: self.isExtensionHotKey
            ) {
                self.conflictMessage = conflict
                return nil
            }

            // 设置快捷键
            self.hotKey = HotKeyConfig(keyCode: keyCode, modifiers: modifiers)
            self.stopRecording()
            self.isPresented = false
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
