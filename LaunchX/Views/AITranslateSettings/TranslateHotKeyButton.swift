import Carbon
import SwiftUI

// MARK: - 翻译快捷键按钮

struct TranslateHotKeyButton: View {
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
        Button(action: { showPopover = true }) {
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
            TranslateHotKeyRecorderPopover(
                keyCode: $keyCode,
                modifiers: $modifiers,
                isPresented: $showPopover,
                hotKeyType: hotKeyType,
                onSave: onSave
            )
        }
    }
}

