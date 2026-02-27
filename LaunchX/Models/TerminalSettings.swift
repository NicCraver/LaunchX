import AppKit
import Foundation

enum TerminalType: String, Codable, CaseIterable, Identifiable {
    case appleTerminal = "Terminal"
    case iterm2 = "iTerm2"
    case warp = "Warp"
    case ghostty = "Ghostty"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .appleTerminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp"
        case .ghostty: return "com.mitchellh.ghostty"
        }
    }

    var isInstalled: Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: self.bundleIdentifier)
            != nil
    }

    var displayName: String {
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: self.bundleIdentifier),
            let bundle = Bundle(url: url),
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        {
            return name
        }
        return self.rawValue
    }
}

struct TerminalSettings: Codable {
    var selectedTerminal: TerminalType = .appleTerminal

    static let `default` = TerminalSettings()

    static func load() -> TerminalSettings {
        if let data = UserDefaults.standard.data(forKey: "terminalSettings"),
            let settings = try? JSONDecoder().decode(TerminalSettings.self, from: data)
        {
            // 如果已保存的终端未安装，回退到默认
            if !settings.selectedTerminal.isInstalled && settings.selectedTerminal != .appleTerminal
            {
                return .default
            }
            return settings
        }
        return .default
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "terminalSettings")
        }
    }
}
