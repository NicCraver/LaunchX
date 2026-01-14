import AppKit
import Foundation

/// 表情包搜索服务 - 负责网络请求、HTML 解析和图片缓存
final class MemeSearchService {
    static let shared = MemeSearchService()

    // MARK: - 图片缓存

    private let imageCache = NSCache<NSString, NSImage>()
    private let dataCache = NSCache<NSString, NSData>()  // 用于缓存 GIF 原始数据
    private var activeTasks: [String: URLSessionDataTask] = [:]
    private let taskQueue = DispatchQueue(label: "com.launchx.meme.tasks")

    private init() {
        // 设置缓存限制
        imageCache.countLimit = 100
        dataCache.countLimit = 50
    }

    // MARK: - 搜索表情包

    /// 搜索表情包
    /// - Parameters:
    ///   - keyword: 搜索关键词
    ///   - completion: 完成回调，返回表情包列表或错误
    func search(keyword: String, completion: @escaping (Result<[MemeItem], Error>) -> Void) {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(.success([]))
            return
        }

        // URL 编码关键词
        guard
            let encodedKeyword = keyword.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed)
        else {
            completion(.failure(MemeSearchError.invalidKeyword))
            return
        }

        let urlString = "https://www.doutupk.com/search?keyword=\(encodedKeyword)"
        guard let url = URL(string: urlString) else {
            completion(.failure(MemeSearchError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                    let html = String(data: data, encoding: .utf8)
                else {
                    completion(.failure(MemeSearchError.noData))
                    return
                }

                // 解析 HTML
                let memes = self.parseHTML(html)
                completion(.success(memes))
            }
        }
        task.resume()
    }

    // MARK: - HTML 解析

    /// 解析 HTML 提取表情包信息
    private func parseHTML(_ html: String) -> [MemeItem] {
        var memes: [MemeItem] = []

        // 找到图片搜索结果区域 - 在 random_picture div 内
        guard let randomPictureRange = html.range(of: "class=\"random_picture\"") else {
            return memes
        }

        let searchArea = String(html[randomPictureRange.lowerBound...])

        // 分割每个图片项 - 每个 <a class="col-xs-6 col-md-2" 是一个图片
        let items = searchArea.components(separatedBy: "<a class=\"col-xs-6 col-md-2\"")

        for (index, item) in items.enumerated() {
            // 跳过第一个（分割前的内容）
            if index == 0 { continue }
            // 限制数量，避免加载过多
            if memes.count >= 72 { break }

            // 提取图片 URL (data-original 属性)
            guard let imageURL = extractAttribute(from: item, attribute: "data-original") else {
                continue
            }

            // 检测是否为 GIF
            let isGif = item.contains("class=\"gif\"")

            // 提取描述文字 (在 <p style="display: none"> 中)
            let description = extractDescription(from: item)

            let meme = MemeItem(
                imageURL: imageURL,
                description: description,
                isGif: isGif
            )
            memes.append(meme)
        }

        return memes
    }

    /// 提取 HTML 属性值
    private func extractAttribute(from html: String, attribute: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
            let match = regex.firstMatch(
                in: html, options: [], range: NSRange(html.startIndex..., in: html)),
            let range = Range(match.range(at: 1), in: html)
        else {
            return nil
        }
        return String(html[range])
    }

    /// 提取描述文字
    private func extractDescription(from html: String) -> String {
        // 查找 <p style="display: none">...</p>
        let pattern = "<p[^>]*style=\"display: none\"[^>]*>([^<]*)</p>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(
                in: html, options: [], range: NSRange(html.startIndex..., in: html)),
            let range = Range(match.range(at: 1), in: html)
        else {
            return ""
        }
        return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 图片加载

    /// 加载图片（带缓存）
    /// - Parameters:
    ///   - url: 图片 URL
    ///   - completion: 完成回调，返回图片和原始数据（GIF 需要原始数据）
    func loadImage(url: String, completion: @escaping (NSImage?, Data?) -> Void) {
        let cacheKey = url as NSString

        // 检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            let cachedData = dataCache.object(forKey: cacheKey) as Data?
            completion(cachedImage, cachedData)
            return
        }

        // 处理协议 - 确保使用 HTTPS（ATS 要求）
        var imageURLString = url
        if imageURLString.hasPrefix("//") {
            imageURLString = "https:" + imageURLString
        } else if imageURLString.hasPrefix("http://") {
            // 将 http 转换为 https，避免 ATS 阻止请求
            imageURLString = imageURLString.replacingOccurrences(of: "http://", with: "https://")
        }

        guard let imageURL = URL(string: imageURLString) else {
            completion(nil, nil)
            return
        }

        // 取消之前的同 URL 请求
        taskQueue.sync {
            activeTasks[url]?.cancel()
        }

        var request = URLRequest(url: imageURL)
        request.timeoutInterval = 10
        // 设置 Referer，某些图片服务器可能需要
        request.setValue("https://www.doutupk.com", forHTTPHeaderField: "Referer")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            self.taskQueue.sync {
                self.activeTasks.removeValue(forKey: url)
            }

            DispatchQueue.main.async {
                guard error == nil,
                    let data = data,
                    let image = NSImage(data: data)
                else {
                    completion(nil, nil)
                    return
                }

                // 缓存图片和数据
                self.imageCache.setObject(image, forKey: cacheKey)
                self.dataCache.setObject(data as NSData, forKey: cacheKey)

                completion(image, data)
            }
        }

        taskQueue.sync {
            activeTasks[url] = task
        }
        task.resume()
    }

    /// 取消图片加载
    func cancelLoad(url: String) {
        taskQueue.sync {
            activeTasks[url]?.cancel()
            activeTasks.removeValue(forKey: url)
        }
    }

    /// 取消所有图片加载
    func cancelAllLoads() {
        taskQueue.sync {
            for (_, task) in activeTasks {
                task.cancel()
            }
            activeTasks.removeAll()
        }
    }

    /// 清除缓存
    func clearCache() {
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
    }

    /// 获取缓存的原始数据（用于 GIF）
    func getCachedData(for url: String) -> Data? {
        return dataCache.object(forKey: url as NSString) as Data?
    }

    // MARK: - 复制到剪贴板

    /// 将图片复制到剪贴板
    /// - Parameters:
    ///   - image: 图片
    ///   - isGif: 是否为 GIF
    ///   - gifData: GIF 原始数据
    func copyToClipboard(image: NSImage, isGif: Bool, gifData: Data?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if isGif, let data = gifData {
            // GIF 需要保存为临时文件，然后将文件 URL 写入剪贴板
            // 这样其他应用（如微信、钉钉）才能正确识别并保持动画
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "meme_\(UUID().uuidString).gif"
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try data.write(to: fileURL)

                // 写入文件 URL（主要方式，大多数应用支持）
                pasteboard.writeObjects([fileURL as NSURL])

                // 同时写入原始 GIF 数据（某些应用可能需要）
                let gifType = NSPasteboard.PasteboardType(rawValue: "com.compuserve.gif")
                pasteboard.setData(data, forType: gifType)

            } catch {
                // 如果保存失败，回退到直接写入数据
                let gifType = NSPasteboard.PasteboardType(rawValue: "com.compuserve.gif")
                pasteboard.setData(data, forType: gifType)
                pasteboard.writeObjects([image])
            }
        } else {
            // 静态图片，写入 PNG 格式
            if let tiffData = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData),
                let pngData = bitmap.representation(using: .png, properties: [:])
            {
                pasteboard.setData(pngData, forType: .png)
            }
            // 同时写入 TIFF 格式作为后备
            pasteboard.writeObjects([image])
        }
    }
}

// MARK: - 错误类型

enum MemeSearchError: LocalizedError {
    case invalidKeyword
    case invalidURL
    case noData
    case parseError
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidKeyword:
            return "无效的搜索关键词"
        case .invalidURL:
            return "无效的 URL"
        case .noData:
            return "未获取到数据"
        case .parseError:
            return "解析失败"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}
