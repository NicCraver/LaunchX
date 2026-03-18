import SwiftUI

// MARK: - KeyCap View Component

/// 通用按键显示组件，用于显示键盘按键的视觉表示
struct KeyCapView: View {
    let text: String
    let size: KeyCapSize

    init(text: String, size: KeyCapSize = .medium) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(size.cornerRadius)
            .shadow(color: size.hasShadow ? .black.opacity(0.1) : .clear, radius: 1, x: 0, y: 1)
    }
}

// MARK: - KeyCap Size

enum KeyCapSize {
    case small      // 用于紧凑显示
    case medium     // 用于设置界面
    case large      // 用于弹窗和强调显示

    var fontSize: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 12
        case .large: return 13
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 3
        case .medium: return 4
        case .large: return 4
        }
    }

    var hasShadow: Bool {
        return self == .large
    }
}

// MARK: - Backward Compatibility Wrappers

/// 向后兼容：小尺寸 KeyCap（用于 AliasShortcutSettingsView）
struct KeyCapViewSmall: View {
    let text: String

    var body: some View {
        KeyCapView(text: text, size: .small)
    }
}

/// 向后兼容：设置界面尺寸 KeyCap（用于 SettingsView）
struct KeyCapViewSettings: View {
    let text: String

    var body: some View {
        KeyCapView(text: text, size: .medium)
    }
}

/// 向后兼容：大尺寸 KeyCap（用于 HotKeyRecorderPopover）
struct KeyCapViewLarge: View {
    let text: String

    var body: some View {
        KeyCapView(text: text, size: .large)
    }
}
