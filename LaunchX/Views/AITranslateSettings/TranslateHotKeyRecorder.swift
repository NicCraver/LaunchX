import Carbon
import SwiftUI

// MARK: - 翻译快捷键录制弹窗

struct TranslateHotKeyRecorderPopover: View {
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
            HStack(spacing: 4) {
                Text("例如")
                    .foregroundColor(.secondary)
                    .font(.caption)
                KeyCapView(text: "⌃")
                KeyCapView(text: "⌥")
                KeyCapView(text: "T")
            }
            .padding(.top, 8)

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
                        if hotKeyType == "translateSelection" {
                            HotKeyService.shared.unregisterTranslateSelectionHotKey()
                        } else {
                            HotKeyService.shared.unregisterTranslateInputHotKey()
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
                if hotKeyType == "translateSelection" {
                    HotKeyService.shared.unregisterTranslateSelectionHotKey()
                } else {
                    HotKeyService.shared.unregisterTranslateInputHotKey()
                }
                stopRecording()
                isPresented = false
                return nil
            }

            let mods = HotKeyService.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { return event }

            let code = UInt32(event.keyCode)

            if let conflict = HotKeyService.shared.checkHotKeyConflict(
                keyCode: code, modifiers: mods, excludeType: hotKeyType)
            {
                conflictMessage = conflict
                return nil
            }

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

#Preview {
    AITranslateSettingsView()
        .frame(width: 600, height: 700)
}
