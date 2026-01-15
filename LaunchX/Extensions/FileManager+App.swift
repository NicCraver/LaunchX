import CoreServices
import Foundation

extension FileManager {
    /// 获取应用包的本地化中文名称（支持"企业微信"、"微信"等）
    /// 如果找不到中文名称，或者本地化名称仅为 ASCII（如 WeCom），则返回 nil，以便调用方回退到文件系统显示名
    public func getChineseAppName(at appPath: String) -> String? {
        let appURL = URL(fileURLWithPath: appPath)

        // Method 1: 检查 InfoPlist.strings 中的中文本地化
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
        let lprojDirs = ["zh-Hans.lproj", "zh_CN.lproj", "zh-Hant.lproj", "zh_TW.lproj"]

        for lproj in lprojDirs {
            let stringsURL = resourcesURL.appendingPathComponent(lproj).appendingPathComponent(
                "InfoPlist.strings")
            guard fileExists(atPath: stringsURL.path),
                let data = contents(atPath: stringsURL.path)
            else { continue }

            // 尝试作为 plist 解析
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: String],
                let displayName = plist["CFBundleDisplayName"] ?? plist["CFBundleName"],
                !displayName.isOnlyASCII
            {
                return displayName
            }

            // 尝试作为 UTF-16 编码的 strings 文件手动解析（常见于 .strings 文件）
            if let str = String(data: data, encoding: .utf16) {
                let patterns = [
                    "\"CFBundleDisplayName\"\\s*=\\s*\"([^\"]+)\"",
                    "\"CFBundleName\"\\s*=\\s*\"([^\"]+)\"",
                ]

                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern),
                        let match = regex.firstMatch(
                            in: str, range: NSRange(str.startIndex..., in: str)),
                        let range = Range(match.range(at: 1), in: str)
                    {
                        let result = String(str[range])
                        if !result.isOnlyASCII {
                            return result
                        }
                    }
                }
            }
        }

        // Method 2: 检查 Info.plist 中的 CFBundleDisplayName（部分应用如企业微信直接写在主 plist）
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        if let infoPlistData = contents(atPath: infoPlistURL.path),
            let plist = try? PropertyListSerialization.propertyList(
                from: infoPlistData, format: nil) as? [String: Any]
        {
            if let displayName = plist["CFBundleDisplayName"] as? String,
                !displayName.isOnlyASCII
            {
                return displayName
            }
        }

        // Method 3: 使用 Spotlight 元数据（适用于活动监视器等系统应用）
        if let mdItem = MDItemCreate(nil, appPath as CFString),
            let displayName = MDItemCopyAttribute(mdItem, kMDItemDisplayName) as? String,
            !displayName.isOnlyASCII
        {
            return displayName
        }

        return nil
    }

    /// 获取应用显示名称的通用方法
    public func getAppDisplayName(at path: String) -> String {
        return getChineseAppName(at: path)
            ?? displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
    }
}

extension String {
    /// 判断字符串是否仅包含 ASCII 字符
    fileprivate var isOnlyASCII: Bool {
        return self.utf8.count == self.count
    }
}

extension FileManager {
    /// 解压 zip 文件到指定目录
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", sourceURL.path, "-d", destinationURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "FileManager",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "解压失败，错误码: \(process.terminationStatus)"]
            )
        }
    }
}
