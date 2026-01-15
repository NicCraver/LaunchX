import Carbon
import SwiftUI

// MARK: - 表情包收藏设置视图

struct MemeFavoriteSettingsView: View {
    @State private var settings = MemeFavoriteSettings.load()
    @State private var showHotKeyPopover = false
    @State private var favoriteCount = MemeFavoriteService.shared.count

    private let labelWidth: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题行
                HStack {
                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.yellow)
                    Text("表情包收藏")
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
                    FavoriteHotKeyButton(settings: $settings, showPopover: $showHotKeyPopover)
                    Spacer()
                }

                // 别名设置
                HStack {
                    Text("别名:")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("sc", text: $settings.alias)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: settings.alias) { _, _ in
                            settings.save()
                        }
                    Spacer()
                }

                // 自动收藏设置
                HStack {
                    Text("复制时自动收藏:")
                        .frame(width: labelWidth, alignment: .trailing)
                    Toggle("", isOn: $settings.autoFavorite)
                        .toggleStyle(.switch)
                        .onChange(of: settings.autoFavorite) { _, _ in
                            settings.save()
                        }
                    Spacer()
                }

                // 选中动作设置
                HStack {
                    Text("选中后动作:")
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker("", selection: $settings.actionType) {
                        ForEach(MemeActionType.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: settings.actionType) { _, _ in
                        settings.save()
                    }
                    Spacer()
                }

                Divider()

                // 收藏统计
                HStack {
                    Text("已收藏数量:")
                        .frame(width: labelWidth, alignment: .trailing)
                    Text("\(favoriteCount) 个表情包")
                        .foregroundColor(.secondary)
                    Spacer()
                    if favoriteCount > 0 {
                        Button("清空收藏") {
                            clearAllFavorites()
                        }
                        .foregroundColor(.red)
                    }
                }

                // 导出导入
                HStack {
                    Text("备份与恢复:")
                        .frame(width: labelWidth, alignment: .trailing)
                    Button("导出收藏") {
                        MemeFavoriteService.shared.exportFavorites()
                    }
                    .disabled(favoriteCount == 0)
                    Button("导入收藏") {
                        MemeFavoriteService.shared.importFavorites()
                        // 延迟刷新计数
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            favoriteCount = MemeFavoriteService.shared.count
                        }
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
                            Text("输入别名或使用快捷键进入收藏模式")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("输入关键词搜索收藏的表情包")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("在表情包搜索中右键可添加到收藏")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("4.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("在收藏中右键可删除")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("5.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text("开启「复制时自动收藏」后，复制的表情包会自动加入收藏")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            favoriteCount = MemeFavoriteService.shared.count
        }
    }

    private func clearAllFavorites() {
        MemeFavoriteService.shared.clearAllFavorites()
        favoriteCount = 0
    }
}

// MARK: - 收藏快捷键按钮

struct FavoriteHotKeyButton: View {
    @Binding var settings: MemeFavoriteSettings
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
            FavoriteHotKeyRecorderPopover(settings: $settings, isPresented: $showPopover)
        }
    }
}

// MARK: - 收藏快捷键录制弹窗

struct FavoriteHotKeyRecorderPopover: View {
    @Binding var settings: MemeFavoriteSettings
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
                KeyCapView(text: "S")
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
                        HotKeyService.shared.unregisterFavoriteHotKey()
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
                HotKeyService.shared.unregisterFavoriteHotKey()
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
                keyCode: keyCode, modifiers: modifiers, excludeType: "favorite")
            {
                conflictMessage = conflict
                return nil
            }

            // 设置快捷键
            settings.hotKeyCode = keyCode
            settings.hotKeyModifiers = modifiers
            settings.save()

            // 注册快捷键
            HotKeyService.shared.registerFavoriteHotKey(keyCode: keyCode, modifiers: modifiers)

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
    MemeFavoriteSettingsView()
        .frame(width: 600, height: 500)
}
