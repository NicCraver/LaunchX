import AppKit
import Foundation
import UniformTypeIdentifiers

/// 表情包收藏服务 - 负责收藏管理和本地存储
final class MemeFavoriteService {
    static let shared = MemeFavoriteService()

    // MARK: - 存储路径

    private let favoritesDirectory: URL
    private let imagesDirectory: URL
    private let dataFile: URL

    // MARK: - 缓存

    private var favorites: [MemeFavoriteItem] = []
    private let imageCache = NSCache<NSString, NSImage>()

    private init() {
        // 设置存储目录
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("LaunchX", isDirectory: true)
        favoritesDirectory = appDirectory.appendingPathComponent("MemeFavorites", isDirectory: true)
        imagesDirectory = favoritesDirectory.appendingPathComponent("Images", isDirectory: true)
        dataFile = favoritesDirectory.appendingPathComponent("favorites.json")

        // 创建目录
        try? FileManager.default.createDirectory(
            at: imagesDirectory, withIntermediateDirectories: true)

        // 加载收藏数据
        loadFavorites()

        // 设置缓存限制
        imageCache.countLimit = 100
    }

    // MARK: - 数据加载与保存

    private func loadFavorites() {
        guard FileManager.default.fileExists(atPath: dataFile.path) else {
            favorites = []
            return
        }

        do {
            let data = try Data(contentsOf: dataFile)
            favorites = try JSONDecoder().decode([MemeFavoriteItem].self, from: data)
        } catch {
            print("MemeFavoriteService: Failed to load favorites - \(error)")
            favorites = []
        }
    }

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            try data.write(to: dataFile)
        } catch {
            print("MemeFavoriteService: Failed to save favorites - \(error)")
        }
    }

    // MARK: - 收藏管理

    /// 添加收藏
    /// - Parameters:
    ///   - meme: 表情包项
    ///   - imageData: 图片数据
    ///   - searchKeyword: 搜索关键词
    /// - Returns: 是否添加成功
    @discardableResult
    func addFavorite(meme: MemeItem, imageData: Data, searchKeyword: String) -> Bool {
        // 检查是否已收藏（通过原始 URL 去重）
        if favorites.contains(where: { $0.originalURL == meme.imageURL }) {
            print("MemeFavoriteService: Meme already favorited")
            return false
        }

        // 生成唯一文件名
        let fileExtension = meme.isGif ? "gif" : "png"
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let filePath = imagesDirectory.appendingPathComponent(fileName)

        // 保存图片到本地
        do {
            try imageData.write(to: filePath)
        } catch {
            print("MemeFavoriteService: Failed to save image - \(error)")
            return false
        }

        // 创建收藏项
        let favorite = MemeFavoriteItem(
            imageFileName: fileName,
            description: meme.description,
            searchKeyword: searchKeyword,
            isGif: meme.isGif,
            originalURL: meme.imageURL
        )

        // 添加到列表（新的在前面）
        favorites.insert(favorite, at: 0)
        saveFavorites()

        return true
    }

    /// 添加收藏（通过独立参数）
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - description: 描述文字
    ///   - searchKeyword: 搜索关键词
    ///   - isGif: 是否为 GIF
    ///   - originalURL: 原始 URL
    /// - Returns: 是否添加成功
    @discardableResult
    func addFavorite(
        imageData: Data, description: String, searchKeyword: String, isGif: Bool,
        originalURL: String
    ) -> Bool {
        // 检查是否已收藏（通过原始 URL 去重）
        if favorites.contains(where: { $0.originalURL == originalURL }) {
            print("MemeFavoriteService: Meme already favorited")
            return false
        }

        // 生成唯一文件名
        let fileExtension = isGif ? "gif" : "png"
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let filePath = imagesDirectory.appendingPathComponent(fileName)

        // 保存图片到本地
        do {
            try imageData.write(to: filePath)
        } catch {
            print("MemeFavoriteService: Failed to save image - \(error)")
            return false
        }

        // 创建收藏项
        let favorite = MemeFavoriteItem(
            imageFileName: fileName,
            description: description,
            searchKeyword: searchKeyword,
            isGif: isGif,
            originalURL: originalURL
        )

        // 添加到列表（新的在前面）
        favorites.insert(favorite, at: 0)
        saveFavorites()

        return true
    }

    /// 删除收藏
    /// - Parameter id: 收藏项 ID
    /// - Returns: 是否删除成功
    @discardableResult
    func removeFavorite(id: UUID) -> Bool {
        guard let index = favorites.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let favorite = favorites[index]

        // 删除本地图片文件
        let filePath = imagesDirectory.appendingPathComponent(favorite.imageFileName)
        try? FileManager.default.removeItem(at: filePath)

        // 从缓存中移除
        imageCache.removeObject(forKey: favorite.imageFileName as NSString)

        // 从列表中移除
        favorites.remove(at: index)
        saveFavorites()

        return true
    }

    /// 检查是否已收藏
    func isFavorited(url: String) -> Bool {
        return favorites.contains(where: { $0.originalURL == url })
    }

    /// 获取收藏项（通过原始 URL）
    func getFavorite(byURL url: String) -> MemeFavoriteItem? {
        return favorites.first(where: { $0.originalURL == url })
    }

    /// 获取所有收藏
    func getAllFavorites() -> [MemeFavoriteItem] {
        return favorites
    }

    /// 搜索收藏（通过关键词或描述）
    func searchFavorites(keyword: String) -> [MemeFavoriteItem] {
        guard !keyword.isEmpty else {
            return favorites
        }

        let keywordLower = keyword.lowercased()
        return favorites.filter { favorite in
            favorite.searchKeyword.lowercased().contains(keywordLower)
                || favorite.description.lowercased().contains(keywordLower)
        }
    }

    /// 获取收藏数量
    var count: Int {
        return favorites.count
    }

    // MARK: - 图片加载

    /// 加载收藏的图片
    func loadFavoriteImage(
        favorite: MemeFavoriteItem, completion: @escaping (NSImage?, Data?) -> Void
    ) {
        let cacheKey = favorite.imageFileName as NSString

        // 检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            let filePath = imagesDirectory.appendingPathComponent(favorite.imageFileName)
            let data = try? Data(contentsOf: filePath)
            completion(cachedImage, data)
            return
        }

        // 从本地加载
        let filePath = imagesDirectory.appendingPathComponent(favorite.imageFileName)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try Data(contentsOf: filePath)
                guard let image = NSImage(data: data) else {
                    DispatchQueue.main.async {
                        completion(nil, nil)
                    }
                    return
                }

                // 缓存图片
                self.imageCache.setObject(image, forKey: cacheKey)

                DispatchQueue.main.async {
                    completion(image, data)
                }
            } catch {
                print("MemeFavoriteService: Failed to load image - \(error)")
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
            }
        }
    }

    /// 获取收藏图片的本地 URL
    func getFavoriteImageURL(favorite: MemeFavoriteItem) -> URL {
        return imagesDirectory.appendingPathComponent(favorite.imageFileName)
    }

    // MARK: - 复制到剪贴板

    /// 将收藏的图片复制到剪贴板
    func copyFavoriteToClipboard(favorite: MemeFavoriteItem, completion: @escaping (Bool) -> Void) {
        loadFavoriteImage(favorite: favorite) { image, data in
            guard let image = image else {
                completion(false)
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            if favorite.isGif, let gifData = data {
                // GIF 需要保存为临时文件
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "meme_\(UUID().uuidString).gif"
                let fileURL = tempDir.appendingPathComponent(fileName)

                do {
                    try gifData.write(to: fileURL)
                    pasteboard.writeObjects([fileURL as NSURL])

                    let gifType = NSPasteboard.PasteboardType(rawValue: "com.compuserve.gif")
                    pasteboard.setData(gifData, forType: gifType)
                    completion(true)
                } catch {
                    pasteboard.writeObjects([image])
                    completion(true)
                }
            } else {
                // 静态图片
                if let tiffData = image.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiffData),
                    let pngData = bitmap.representation(using: .png, properties: [:])
                {
                    pasteboard.setData(pngData, forType: .png)
                }
                pasteboard.writeObjects([image])
                completion(true)
            }
        }
    }

    // MARK: - 清理

    /// 清除所有收藏
    func clearAllFavorites() {
        // 删除所有图片文件
        for favorite in favorites {
            let filePath = imagesDirectory.appendingPathComponent(favorite.imageFileName)
            try? FileManager.default.removeItem(at: filePath)
        }

        // 清空列表和缓存
        favorites.removeAll()
        imageCache.removeAllObjects()
        saveFavorites()
    }

    // MARK: - 导出导入

    /// 导出收藏为 zip 文件
    func exportFavorites() {
        guard !favorites.isEmpty else {
            showAlert(title: "导出失败", message: "没有收藏的表情包可供导出", style: .warning)
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "LaunchX_MemeFavorites_\(formatDate(Date())).zip"
        savePanel.title = "导出表情包收藏"
        savePanel.message = "请选择备份文件的保存位置"

        savePanel.begin { [weak self] result in
            guard let self = self, result == .OK, let url = savePanel.url else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.createExportZip(to: url)
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "导出成功",
                            message:
                                "已导出 \(self.favorites.count) 个表情包收藏至：\n\(url.lastPathComponent)"
                        )
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "导出失败",
                            message: "发生错误：\(error.localizedDescription)",
                            style: .critical
                        )
                    }
                }
            }
        }
    }

    /// 导入收藏的 zip 文件
    func importFavorites() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.zip]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "导入表情包收藏"
        openPanel.message = "请选择要导入的表情包收藏备份文件 (.zip)"

        openPanel.begin { [weak self] result in
            guard let self = self, result == .OK, let url = openPanel.url else { return }

            // 确认弹窗
            let alert = NSAlert()
            alert.messageText = "确认导入收藏？"
            alert.informativeText = "导入将合并到现有收藏中（不会删除已有收藏，重复的将被跳过）"
            alert.addButton(withTitle: "确认导入")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let importedCount = try self.importFromZip(from: url)
                        DispatchQueue.main.async {
                            self.showAlert(
                                title: "导入成功",
                                message: "成功导入 \(importedCount) 个表情包收藏"
                            )
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.showAlert(
                                title: "导入失败",
                                message: "无效的备份文件或读取错误：\(error.localizedDescription)",
                                style: .critical
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 导出导入辅助方法

    private func createExportZip(to url: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemeFavoritesExport_\(UUID().uuidString)")

        // 创建临时目录
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 复制图片文件
        let imagesExportDir = tempDir.appendingPathComponent("Images")
        try FileManager.default.createDirectory(
            at: imagesExportDir, withIntermediateDirectories: true)

        for favorite in favorites {
            let sourceFile = imagesDirectory.appendingPathComponent(favorite.imageFileName)
            let destFile = imagesExportDir.appendingPathComponent(favorite.imageFileName)
            if FileManager.default.fileExists(atPath: sourceFile.path) {
                try FileManager.default.copyItem(at: sourceFile, to: destFile)
            }
        }

        // 导出元数据
        let metadata = ExportMetadata(
            version: "1.0",
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            count: favorites.count
        )
        let metadataFile = tempDir.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataFile)

        // 导出收藏数据
        let favoritesFile = tempDir.appendingPathComponent("favorites.json")
        let favoritesData = try JSONEncoder().encode(favorites)
        try favoritesData.write(to: favoritesFile)

        // 创建 zip 文件
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(
            readingItemAt: tempDir,
            options: .forUploading,
            error: &error
        ) { zipURL in
            try? FileManager.default.copyItem(at: zipURL, to: url)
        }

        if let error = error {
            throw error
        }
    }

    private func importFromZip(from url: URL) throws -> Int {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemeFavoritesImport_\(UUID().uuidString)")

        // 创建临时目录
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 解压 zip 文件
        try FileManager.default.unzipItem(at: url, to: tempDir)

        // 读取收藏数据
        let favoritesFile = tempDir.appendingPathComponent("favorites.json")
        guard FileManager.default.fileExists(atPath: favoritesFile.path) else {
            throw NSError(
                domain: "MemeFavoriteService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无效的备份文件：缺少 favorites.json"]
            )
        }

        let favoritesData = try Data(contentsOf: favoritesFile)
        let importedFavorites = try JSONDecoder().decode(
            [MemeFavoriteItem].self, from: favoritesData)

        let imagesImportDir = tempDir.appendingPathComponent("Images")
        var importedCount = 0

        for importedFavorite in importedFavorites {
            // 跳过已存在的收藏（通过原始 URL 去重）
            if favorites.contains(where: { $0.originalURL == importedFavorite.originalURL }) {
                continue
            }

            // 复制图片文件
            let sourceFile = imagesImportDir.appendingPathComponent(importedFavorite.imageFileName)
            guard FileManager.default.fileExists(atPath: sourceFile.path) else {
                continue
            }

            // 生成新的文件名以避免冲突
            let fileExtension = importedFavorite.isGif ? "gif" : "png"
            let newFileName = "\(UUID().uuidString).\(fileExtension)"
            let destFile = imagesDirectory.appendingPathComponent(newFileName)

            do {
                try FileManager.default.copyItem(at: sourceFile, to: destFile)

                // 创建新的收藏项（使用新文件名）
                let newFavorite = MemeFavoriteItem(
                    imageFileName: newFileName,
                    description: importedFavorite.description,
                    searchKeyword: importedFavorite.searchKeyword,
                    isGif: importedFavorite.isGif,
                    originalURL: importedFavorite.originalURL
                )

                favorites.insert(newFavorite, at: 0)
                importedCount += 1
            } catch {
                print(
                    "MemeFavoriteService: Failed to import image \(importedFavorite.imageFileName) - \(error)"
                )
            }
        }

        if importedCount > 0 {
            saveFavorites()
        }

        return importedCount
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style = .informational) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }

    /// 导出元数据
    private struct ExportMetadata: Codable {
        let version: String
        let exportDate: Date
        let appVersion: String?
        let count: Int
    }
}
