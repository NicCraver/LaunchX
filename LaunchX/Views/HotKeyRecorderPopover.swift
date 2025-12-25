import Carbon
import SwiftUI

// MARK: - 快捷键录制弹窗

struct HotKeyRecorderPopover: View {
    @Binding var hotKey: HotKeyConfig?
    let itemId: UUID
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
                KeyCapViewLarge(text: "SPACE")
            }
            .padding(.top, 8)

            // 提示文字或冲突信息
            if let conflict = conflictMessage {
                Text("快捷键已被「\(conflict)」使用")
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                Text("请输入快捷键...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // 已设置快捷键时显示当前快捷键和删除按钮
            if let currentHotKey = hotKey {
                HStack(spacing: 4) {
                    ForEach(
                        HotKeyService.modifierSymbols(for: currentHotKey.modifiers), id: \.self
                    ) { symbol in
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
        .frame(width: 220)
        .onAppear {
            startRecording()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - 录制逻辑

    private func startRecording() {
        conflictMessage = nil

        // 监控本地按键事件
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in

            // Escape 取消录制
            if event.keyCode == kVK_Escape {
                stopRecording()
                isPresented = false
                return nil
            }

            // Delete 或 Backspace 清除快捷键
            if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
                hotKey = nil
                stopRecording()
                isPresented = false
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
                excludingItemId: itemId
            ) {
                conflictMessage = conflict
                return nil
            }

            // 设置快捷键，成功后自动关闭弹窗
            hotKey = HotKeyConfig(keyCode: keyCode, modifiers: modifiers)
            conflictMessage = nil
            stopRecording()
            isPresented = false
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

// MARK: - 大号按键帽视图

struct KeyCapViewLarge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("测试")
    }
    .popover(isPresented: .constant(true)) {
        HotKeyRecorderPopover(
            hotKey: .constant(HotKeyConfig(keyCode: 37, modifiers: 256)),
            itemId: UUID(),
            isPresented: .constant(true)
        )
    }
}
