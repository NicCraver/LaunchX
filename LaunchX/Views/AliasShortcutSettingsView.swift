import Carbon
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 别名与快捷键设置视图

struct AliasShortcutSettingsView: View {
    @StateObject private var viewModel = AliasShortcutViewModel()
    @State private var searchText = ""
    @State private var isDragTargeted = false
    @FocusState private var focusedField: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索应用、扩展、文档、文件夹与别名...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)

                Spacer()

                // 添加按钮
                Button(action: { viewModel.showFilePicker() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加应用或文件夹")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 列表表头
            HStack(spacing: 12) {
                Text("名称")
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                Text("别名")
                    .frame(width: 60, alignment: .leading)
                Text("打开/执行")
                    .frame(width: 110, alignment: .center)
                Text("进入扩展")
                    .frame(width: 110, alignment: .center)
                Spacer()
                    .frame(width: 30)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // 列表内容
            if viewModel.customItems.isEmpty {
                // 空状态
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 自定义分类
                        SectionHeader(
                            title: "自定义",
                            count: viewModel.customItems.count,
                            isExpanded: $viewModel.customExpanded
                        )

                        if viewModel.customExpanded {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) {
                                index, item in
                                CustomItemRow(
                                    item: binding(for: item),
                                    viewModel: viewModel,
                                    isEvenRow: index % 2 == 0,
                                    focusedField: $focusedField
                                )
                            }
                        }

                        // 系统命令（占位）
                        SectionHeader(
                            title: "系统命令",
                            count: nil,
                            isExpanded: .constant(false)
                        )

                        // 网页直达（占位）
                        SectionHeader(
                            title: "网页直达",
                            count: nil,
                            isExpanded: .constant(false)
                        )

                        // 实用工具（占位）
                        SectionHeader(
                            title: "实用工具",
                            count: nil,
                            isExpanded: .constant(false)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                // 点击任何区域时移除焦点
                focusedField = nil
            }
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            viewModel.handleDrop(providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                .padding(4)
        )
    }

    // MARK: - 辅助视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "plus.square.dashed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("拖拽应用或文件夹到此处")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("或点击右上角 + 按钮添加")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("添加项目") {
                viewModel.showFilePicker()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 辅助方法

    private var filteredItems: [CustomItem] {
        if searchText.isEmpty {
            return viewModel.customItems
        }
        let lowercasedSearch = searchText.lowercased()
        return viewModel.customItems.filter { item in
            item.name.lowercased().contains(lowercasedSearch)
                || (item.alias?.lowercased().contains(lowercasedSearch) ?? false)
                || item.path.lowercased().contains(lowercasedSearch)
        }
    }

    private func binding(for item: CustomItem) -> Binding<CustomItem> {
        Binding(
            get: {
                viewModel.customItems.first { $0.id == item.id } ?? item
            },
            set: { newValue in
                viewModel.updateItem(newValue)
            }
        )
    }
}

// MARK: - 分类标题组件

struct SectionHeader: View {
    let title: String
    let count: Int?
    @Binding var isExpanded: Bool

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let count = count {
                    Text("(\(count))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}

// MARK: - 列表行组件

struct CustomItemRow: View {
    @Binding var item: CustomItem
    @ObservedObject var viewModel: AliasShortcutViewModel
    let isEvenRow: Bool
    var focusedField: FocusState<UUID?>.Binding

    @State private var aliasText: String = ""
    @State private var showOpenHotKeyPopover = false
    @State private var showExtensionHotKeyPopover = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标和名称
            HStack(spacing: 8) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 20, height: 20)

                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

            // 别名输入 - 悬浮显示边框样式
            AliasTextField(
                text: $aliasText,
                placeholder: "别名",
                itemId: item.id,
                focusedField: focusedField
            )
            .frame(width: 80)
            .onAppear {
                aliasText = item.alias ?? ""
            }
            .onChange(of: aliasText) { _, newValue in
                var updatedItem = item
                updatedItem.alias = newValue.isEmpty ? nil : newValue
                viewModel.updateItem(updatedItem)
            }

            // 打开/执行快捷键
            HotKeyButton(
                hotKey: item.openHotKey,
                onTap: { showOpenHotKeyPopover = true }
            )
            .frame(width: 110)
            .popover(isPresented: $showOpenHotKeyPopover) {
                HotKeyRecorderPopover(
                    hotKey: Binding(
                        get: { item.openHotKey },
                        set: { newValue in
                            item.openHotKey = newValue
                            viewModel.updateItem(item)
                        }
                    ),
                    itemId: item.id,
                    isExtensionHotKey: false,
                    isPresented: $showOpenHotKeyPopover
                )
            }

            // 进入扩展快捷键
            if item.isIDE {
                HotKeyButton(
                    hotKey: item.extensionHotKey,
                    onTap: { showExtensionHotKeyPopover = true }
                )
                .frame(width: 110)
                .popover(isPresented: $showExtensionHotKeyPopover) {
                    HotKeyRecorderPopover(
                        hotKey: Binding(
                            get: { item.extensionHotKey },
                            set: { newValue in
                                item.extensionHotKey = newValue
                                viewModel.updateItem(item)
                            }
                        ),
                        itemId: item.id,
                        isExtensionHotKey: true,
                        isPresented: $showExtensionHotKeyPopover
                    )
                }
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 110)
            }

            // 删除按钮
            Button(action: { viewModel.deleteItem(item) }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 30)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isEvenRow ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .contentShape(Rectangle())
    }
}

// MARK: - 别名输入框

struct AliasTextField: View {
    @Binding var text: String
    let placeholder: String
    let itemId: UUID
    var focusedField: FocusState<UUID?>.Binding

    @State private var isHovered = false

    private var isFocused: Bool {
        focusedField.wrappedValue == itemId
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .focused(focusedField, equals: itemId)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        (isHovered || isFocused) ? Color.secondary.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - 快捷键按钮

struct HotKeyButton: View {
    let hotKey: HotKeyConfig?
    let onTap: () -> Void

    @State private var isHovered = false

    // 固定宽度：5个按键帽的最大宽度
    private let fixedWidth: CGFloat = 100

    var body: some View {
        Button(action: onTap) {
            Group {
                if let hotKey = hotKey {
                    // 已设置快捷键：显示按键帽样式
                    HStack(spacing: 2) {
                        ForEach(
                            HotKeyService.modifierSymbols(for: hotKey.modifiers), id: \.self
                        ) { symbol in
                            KeyCapView(text: symbol)
                        }
                        KeyCapView(text: HotKeyService.keyString(for: hotKey.keyCode))
                    }
                } else {
                    // 未设置：只显示文字
                    Text("快捷键")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: fixedWidth)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        // 只有未设置快捷键时悬浮才显示边框
                        (isHovered && hotKey == nil)
                            ? Color.secondary.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 按键帽视图

struct KeyCapView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(3)
    }
}

// MARK: - ViewModel

class AliasShortcutViewModel: ObservableObject {
    @Published var customItems: [CustomItem] = []
    @Published var customExpanded: Bool = true

    init() {
        loadConfig()
    }

    // MARK: - 配置加载和保存

    private func loadConfig() {
        let config = CustomItemsConfig.load()
        customItems = config.customItems
    }

    private func saveConfig() {
        var config = CustomItemsConfig.load()
        config.customItems = customItems
        config.save()

        // 重新加载快捷键
        HotKeyService.shared.reloadCustomHotKeys(from: config)
    }

    // MARK: - 项目操作

    func updateItem(_ item: CustomItem) {
        if let index = customItems.firstIndex(where: { $0.id == item.id }) {
            customItems[index] = item
            saveConfig()
        }
    }

    func deleteItem(_ item: CustomItem) {
        customItems.removeAll { $0.id == item.id }
        saveConfig()
    }

    func deleteItems(at offsets: IndexSet) {
        customItems.remove(atOffsets: offsets)
        saveConfig()
    }

    func addItem(path: String) {
        // 检查是否已存在
        guard !customItems.contains(where: { $0.path == path }) else { return }

        // 验证路径
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }

        // 只允许 .app 或目录
        guard path.hasSuffix(".app") || isDir.boolValue else { return }

        let item = CustomItem(path: path)
        customItems.append(item)
        saveConfig()
    }

    // MARK: - 拖拽处理

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                    data, _ in
                    guard let data = data as? Data,
                        let url = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }

                    DispatchQueue.main.async {
                        self.addItem(path: url.path)
                    }
                }
                handled = true
            }
        }

        return handled
    }

    // MARK: - 文件选择器

    func showFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application, .folder]
        panel.message = "选择要添加的应用或文件夹"
        panel.prompt = "添加"

        if panel.runModal() == .OK {
            for url in panel.urls {
                addItem(path: url.path)
            }
        }
    }

    // MARK: - 冲突检测

    func checkConflict(keyCode: UInt32, modifiers: UInt32, excludingItemId: UUID) -> String? {
        return HotKeyService.shared.checkConflict(
            keyCode: keyCode,
            modifiers: modifiers,
            excludingItemId: excludingItemId
        )
    }
}

// MARK: - Preview

#Preview {
    AliasShortcutSettingsView()
        .frame(width: 600, height: 400)
}
