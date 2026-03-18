import Carbon
import SwiftUI
import UniformTypeIdentifiers

enum WebLinkEditMode: Identifiable {
    case add
    case edit(ToolItem)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let tool): return tool.id.uuidString
        }
    }
}
struct WebLinkEditorSheet: View {
    @Binding var isPresented: Bool
    var existingTool: ToolItem?
    var onSave: (ToolItem) -> Void

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var defaultUrl: String = ""  // 默认 URL（用户未输入 query 时使用）
    @State private var alias: String = ""
    @State private var showInSearchPanel: Bool = false  // 是否在搜索面板中显示
    @State private var urlError: String?
    @State private var iconData: Data?
    @State private var iconError: String?
    @State private var isFetchingIcon: Bool = false  // 是否正在获取图标
    @FocusState private var isUrlFieldFocused: Bool  // URL 输入框焦点状态

    private var isEditing: Bool {
        existingTool != nil
    }

    private var isValid: Bool {
        !name.isEmpty && !url.isEmpty && isValidURL(url)
    }

    /// URL 是否包含 {query} 占位符
    private var supportsQuery: Bool {
        url.contains("{query}")
    }

    /// 当前显示的图标
    private var displayIcon: NSImage {
        if let data = iconData, let image = NSImage(data: data) {
            image.size = NSSize(width: 48, height: 48)
            return image
        }
        let defaultIcon =
            NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        defaultIcon.size = NSSize(width: 48, height: 48)
        return defaultIcon
    }

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text(isEditing ? "编辑网页直达" : "添加网页直达")
                .font(.title3)
                .fontWeight(.semibold)

            // 图标和基本信息
            HStack(alignment: .top, spacing: 20) {
                // 图标选择区域
                VStack(spacing: 8) {
                    // 图标预览
                    Button(action: selectIcon) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(width: 80, height: 80)

                            if isFetchingIcon {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(nsImage: displayIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                            }

                            // 编辑提示
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                        .background(
                                            Circle().fill(Color.white).frame(width: 16, height: 16))
                                }
                            }
                            .frame(width: 80, height: 80)
                            .padding(4)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("点击选择图标")
                    .disabled(isFetchingIcon)

                    // 清除图标按钮
                    if iconData != nil {
                        Button("移除图标") {
                            iconData = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let error = iconError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                    }
                }

                // 表单字段
                VStack(alignment: .leading, spacing: 14) {
                    // 名称
                    VStack(alignment: .leading, spacing: 4) {
                        Text("名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：GitHub", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL（支持 {query} 占位符）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://github.com/search?q={query}", text: $url)
                            .textFieldStyle(.roundedBorder)
                            .focused($isUrlFieldFocused)
                            .onChange(of: url) { _, newValue in
                                validateURL(newValue)
                            }
                            .onChange(of: isUrlFieldFocused) { _, isFocused in
                                // 失去焦点时尝试获取图标
                                if !isFocused && iconData == nil {
                                    fetchFaviconIfNeeded()
                                }
                            }
                            .onSubmit {
                                // 回车时尝试获取图标
                                if iconData == nil {
                                    fetchFaviconIfNeeded()
                                }
                            }
                        if let error = urlError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // 默认 URL（仅当主 URL 包含 {query} 时显示）
                    if supportsQuery {
                        TextField("未输入关键词时跳转到此 URL（可选）", text: $defaultUrl)
                            .textFieldStyle(.roundedBorder)

                        // 显示在搜索面板开关
                        HStack {
                            Toggle(isOn: $showInSearchPanel) {
                                Text("显示在搜索面板")
                            }
                            .toggleStyle(.switch)

                            Spacer()
                        }
                        .help("开启后，搜索时会在结果中显示此网页直达，可直接用搜索内容作为关键词")
                    }

                    // 别名
                    VStack(alignment: .leading, spacing: 4) {
                        Text("别名（可选）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：gh", text: $alias)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            // 图标说明
            Text("支持 PNG、JPG 格式，建议使用 128×128 像素的正方形图片，最大 500KB")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // 按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "保存" : "添加") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            if let tool = existingTool {
                name = tool.name
                url = tool.url ?? ""
                defaultUrl = tool.defaultUrl ?? ""
                alias = tool.alias ?? ""
                iconData = tool.iconData
                showInSearchPanel = tool.showInSearchPanel ?? false
            }
        }
    }

    // MARK: - 图标选择

    private func selectIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg]
        panel.message = "选择图标图片（PNG 或 JPG，最大 500KB）"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            loadIcon(from: url)
        }
    }

    private func loadIcon(from url: URL) {
        iconError = nil

        do {
            let data = try Data(contentsOf: url)

            // 检查文件大小（最大 500KB）
            if data.count > 500 * 1024 {
                iconError = "图片过大，请选择小于 500KB 的图片"
                return
            }

            // 验证是否为有效图片
            guard let image = NSImage(data: data) else {
                iconError = "无法读取图片"
                return
            }

            // 调整图片大小并转换为 PNG
            let resizedData = resizeAndConvertToPNG(image: image, maxSize: 128)
            iconData = resizedData

        } catch {
            iconError = "读取文件失败"
        }
    }

    /// 调整图片大小并转换为 PNG 格式
    private func resizeAndConvertToPNG(image: NSImage, maxSize: CGFloat) -> Data? {
        let originalSize = image.size

        // 计算缩放后的尺寸（保持宽高比）
        var newSize = originalSize
        if originalSize.width > maxSize || originalSize.height > maxSize {
            let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
            newSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }

        // 创建新的图片
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0)
        newImage.unlockFocus()

        // 转换为 PNG 数据
        guard let tiffData = newImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }

        return pngData
    }

    // MARK: - URL 验证

    private func validateURL(_ urlString: String) {
        if urlString.isEmpty {
            urlError = nil
            return
        }

        var normalizedURL = urlString
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }

        if URL(string: normalizedURL) != nil {
            urlError = nil
        } else {
            urlError = "请输入有效的 URL"
        }
    }

    private func isValidURL(_ urlString: String) -> Bool {
        var normalizedURL = urlString
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }
        return URL(string: normalizedURL) != nil
    }

    // MARK: - 自动获取网站图标

    private func fetchFaviconIfNeeded() {
        guard !url.isEmpty, isValidURL(url) else { return }
        guard !isFetchingIcon else { return }

        // 规范化 URL
        var normalizedURL = url
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }

        // 提取域名
        guard let parsedURL = URL(string: normalizedURL),
            let host = parsedURL.host
        else { return }

        isFetchingIcon = true
        iconError = nil

        // 尝试多种 favicon 获取方式
        Task {
            if let data = await fetchFavicon(for: host) {
                await MainActor.run {
                    self.iconData = data
                    self.isFetchingIcon = false
                }
            } else {
                await MainActor.run {
                    self.isFetchingIcon = false
                    // 静默失败，不显示错误
                }
            }
        }
    }

    private func fetchFavicon(for host: String) async -> Data? {
        // 尝试的 favicon URL 列表（按优先级排序）
        let faviconURLs = [
            "https://\(host)/apple-touch-icon.png",
            "https://\(host)/apple-touch-icon-precomposed.png",
            "https://\(host)/favicon-32x32.png",
            "https://\(host)/favicon-16x16.png",
            "https://\(host)/favicon.png",
            "https://\(host)/favicon.ico",
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",  // Google favicon 服务
        ]

        for urlString in faviconURLs {
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                // 检查响应状态码
                if let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200
                {
                    // 验证是否为有效图片
                    if let image = NSImage(data: data), image.isValid {
                        // 检查图片大小（至少 16x16）
                        if image.size.width >= 16 && image.size.height >= 16 {
                            print("[WebLinkEditor] Favicon fetched from: \(urlString)")
                            return data
                        }
                    }
                }
            } catch {
                // 继续尝试下一个 URL
                continue
            }
        }

        return nil
    }

    // MARK: - 保存

    private func save() {
        var normalizedURL = url
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }

        // 处理默认 URL
        var normalizedDefaultUrl: String? = nil
        if supportsQuery && !defaultUrl.isEmpty {
            var tempUrl = defaultUrl
            if !tempUrl.hasPrefix("http://") && !tempUrl.hasPrefix("https://") {
                tempUrl = "https://" + tempUrl
            }
            normalizedDefaultUrl = tempUrl
        }

        var tool: ToolItem
        if let existing = existingTool {
            tool = existing
            tool.name = name
            tool.url = normalizedURL
            tool.defaultUrl = normalizedDefaultUrl
            tool.alias = alias.isEmpty ? nil : alias
            tool.iconData = iconData
            // 只有支持 query 的才保存 showInSearchPanel
            tool.showInSearchPanel = supportsQuery ? showInSearchPanel : nil
        } else {
            tool = ToolItem.webLink(
                name: name,
                url: normalizedURL,
                alias: alias.isEmpty ? nil : alias,
                iconData: iconData,
                showInSearchPanel: supportsQuery ? showInSearchPanel : nil
            )
            tool.defaultUrl = normalizedDefaultUrl
        }

        onSave(tool)
        isPresented = false
    }
}
