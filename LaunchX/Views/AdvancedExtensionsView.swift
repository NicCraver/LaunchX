import SwiftUI

enum AdvancedExtensionType: String, CaseIterable, Identifiable {
    case clipboard = "剪贴板"
    case snippet = "Snippet"
    case aiTranslate = "AI 翻译"
    case bookmarkSearch = "搜索书签"
    case twoFactorAuth = "2FA 短信"
    case terminal = "终端"

    var id: String { rawValue }

    private static var isMacOS26OrLater: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    static var availableCases: [AdvancedExtensionType] {
        if isMacOS26OrLater {
            return allCases.filter { $0 != .twoFactorAuth }
        }
        return allCases
    }

    var iconImageName: String? {
        return nil
    }

    var sfSymbolName: String {
        switch self {
        case .clipboard: return "doc.on.clipboard.fill"
        case .snippet: return "chevron.left.forwardslash.chevron.right"
        case .aiTranslate: return "character.bubble.fill"
        case .bookmarkSearch: return "bookmark.fill"
        case .twoFactorAuth: return "lock.shield.fill"
        case .terminal: return "terminal.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .clipboard: return .blue
        case .snippet: return .orange
        case .aiTranslate: return .indigo
        case .bookmarkSearch: return .pink
        case .twoFactorAuth: return .green
        case .terminal: return .gray
        }
    }
}

struct AdvancedExtensionsView: View {
    @State private var selectedExtension: AdvancedExtensionType = .clipboard

    var body: some View {
        HSplitView {
            extensionList
                .frame(minWidth: 180, maxWidth: 200)

            extensionSettings
                .frame(minWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var extensionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AdvancedExtensionType.availableCases) { type in
                ExtensionSidebarItem(
                    type: type,
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

    @ViewBuilder
    private var extensionSettings: some View {
        switch selectedExtension {
        case .bookmarkSearch:
            BookmarkSearchSettingsView()
        case .clipboard:
            ClipboardSettingsView()
        case .snippet:
            SnippetSettingsView()
        case .twoFactorAuth:
            TwoFactorAuthSettingsView()
        case .aiTranslate:
            AITranslateSettingsView()
        case .terminal:
            TerminalSettingsView()
        }
    }
}

struct ExtensionSidebarItem: View {
    let iconImageName: String?
    let sfSymbolName: String
    let iconColor: Color
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(
        type: AdvancedExtensionType,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.iconImageName = type.iconImageName
        self.sfSymbolName = type.sfSymbolName
        self.iconColor = type.iconColor
        self.title = type.rawValue
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: sfSymbolName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .frame(width: 14, alignment: .center)
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
