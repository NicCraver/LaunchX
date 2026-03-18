import Carbon
import SwiftUI

// MARK: - Extension HotKey Button Component

/// 扩展快捷键按钮组件（用于书签、2FA 等扩展设置）
struct ExtensionHotKeyButton: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var showPopover: Bool
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
                        ForEach(
                            HotKeyService.modifierSymbols(for: modifiers), id: \.self
                        ) { symbol in
                            KeyCapView(text: symbol, size: .medium)
                        }
                        KeyCapView(text: HotKeyService.keyString(for: keyCode), size: .medium)
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
    }
}

// MARK: - Extension HotKey Recorder Popover Component

/// 扩展快捷键录制弹窗组件（用于书签、2FA 等扩展设置）
struct ExtensionHotKeyRecorderPopover: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var isPresented: Bool
    @State private var keyDownMonitor: Any?
    @State private var conflictMessage: String?

    let exampleKey: String
    let onSave: () -> Void
    let onUnregister: () -> Void
    let onRegister: (UInt32, UInt32) -> Void
    let checkConflict: (UInt32, UInt32) -> String?

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
                KeyCapView(text: "⌃", size: .small)
                KeyCapView(text: "⌥", size: .small)
                KeyCapView(text: exampleKey, size: .small)
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
                        HotKeyService.modifierSymbols(for: modifiers), id: \.self
                    ) { symbol in
                        KeyCapView(text: symbol, size: .small)
                    }
                    KeyCapView(text: HotKeyService.keyString(for: keyCode), size: .small)

                    Button {
                        keyCode = 0
                        modifiers = 0
                        onSave()
                        onUnregister()
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
                onUnregister()
                stopRecording()
                isPresented = false
                return nil
            }

            let eventModifiers = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard eventModifiers != 0 else { return event }

            let eventKeyCode = UInt32(event.keyCode)

            // 检查冲突
            if let conflict = checkConflict(eventKeyCode, eventModifiers) {
                conflictMessage = conflict
                return nil
            }

            // 设置快捷键
            keyCode = eventKeyCode
            modifiers = eventModifiers
            onSave()
            onRegister(eventKeyCode, eventModifiers)
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
