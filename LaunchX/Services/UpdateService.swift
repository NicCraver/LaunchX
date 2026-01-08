import AppKit
import Combine
import Foundation

/// 检查更新服务 - 负责从 GitHub Releases 获取版本信息并处理下载安装
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    private let repoURL = "https://api.github.com/repos/twotwoba/LaunchX/releases/latest"

    @Published var isChecking: Bool = false
    @Published var latestVersion: String?
    @Published var updateAvailable: Bool = false

    private init() {}

    /// 获取当前应用版本
    var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// 检查更新
    func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

        guard let url = URL(string: repoURL) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        // GitHub API 需要 User-Agent
        request.setValue("LaunchX-App", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false

                if let error = error {
                    print("检查更新失败: \(error.localizedDescription)")
                    if manual { self?.showErrorAlert(message: "无法连接到更新服务器") }
                    return
                }

                guard let data = data else { return }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let tagName = json["tag_name"] as? String
                    {

                        let version = tagName.replacingOccurrences(of: "v", with: "")
                        self?.latestVersion = version

                        if self?.isNewerVersion(version) == true {
                            self?.updateAvailable = true
                            self?.showUpdateAlert(version: version, json: json)
                        } else if manual {
                            self?.showUpToDateAlert()
                        }
                    }
                } catch {
                    print("解析更新数据失败: \(error)")
                    if manual { self?.showErrorAlert(message: "解析版本信息失败") }
                }
            }
        }.resume()
    }

    /// 比较版本号
    private func isNewerVersion(_ latest: String) -> Bool {
        return latest.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    /// 寻找匹配当前架构的下载地址
    private func findDownloadURL(from assets: [[String: Any]]) -> String? {
        #if arch(arm64)
            let arch = "arm64"
        #else
            let arch = "x86_64"
        #endif

        // 优先寻找匹配架构的 dmg 文件
        for asset in assets {
            if let name = asset["name"] as? String,
                let downloadUrl = asset["browser_download_url"] as? String,
                name.lowercased().hasSuffix(".dmg"),
                name.lowercased().contains(arch)
            {
                return downloadUrl
            }
        }

        // 备选：任何 dmg 文件
        return assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }?[
            "browser_download_url"] as? String
    }

    /// 弹出发现新版本提示
    private func showUpdateAlert(version: String, json: [String: Any]) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(version)"
        let body = json["body"] as? String ?? "点击下载最新版本以体验新功能。"
        alert.informativeText = "当前版本: \(currentVersion)\n\n更新内容:\n\(body)"
        alert.alertStyle = .informational

        let assets = json["assets"] as? [[String: Any]] ?? []
        let downloadURL = findDownloadURL(from: assets)

        alert.addButton(withTitle: downloadURL != nil ? "下载并更新" : "查看更新")
        alert.addButton(withTitle: "以后再说")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let urlString = downloadURL ?? json["html_url"] as? String,
                let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// 已经是最新版本提示
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本 \(currentVersion) 已经是最新版本。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    /// 错误提示
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "检查更新出错"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
