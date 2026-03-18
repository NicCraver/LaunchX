import Carbon
import Combine
import SwiftUI
import UniformTypeIdentifiers


struct ToolsSettingsView: View {
    @StateObject private var viewModel = ToolsViewModel()
    @State private var searchText = ""
    @State private var isDragTargeted = false
    @FocusState private var focusedField: UUID?
    @State private var webLinkEditMode: WebLinkEditMode? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏（只有搜索框）
            HStack {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索工具...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 列表表头
            HStack(spacing: 12) {
                Text("名称")
                    .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                Text("别名")
                    .frame(width: 70, alignment: .leading)
                Text("快捷键")
                    .frame(width: 130, alignment: .center)
                Text("进入扩展")
                    .frame(width: 130, alignment: .center)
                Text("启用")
                    .frame(width: 44, alignment: .center)
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
            if viewModel.tools.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 自定义应用分类（始终显示）
                        ToolSectionHeader(
                            title: "自定义",
                            count: viewModel.appTools.count,
                            isExpanded: $viewModel.appExpanded,
                            onAdd: {
                                viewModel.showFilePicker()
                            }
                        )

                        if viewModel.appExpanded {
                            if filteredAppTools.isEmpty && searchText.isEmpty {
                                // 空状态提示
                                HStack {
                                    Text("点击右侧 + 添加应用或文件夹")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(Array(filteredAppTools.enumerated()), id: \.element.id) {
                                    index, tool in
                                    ToolItemRow(
                                        tool: binding(for: tool),
                                        viewModel: viewModel,
                                        isEvenRow: index % 2 == 0,
                                        focusedField: $focusedField,
                                        onEdit: nil
                                    )
                                }
                            }
                        }

                        // 网页直达分类
                        ToolSectionHeader(
                            title: "网页直达",
                            count: viewModel.webLinkTools.count,
                            isExpanded: $viewModel.webLinkExpanded,
                            onAdd: {
                                webLinkEditMode = .add
                            }
                        )

                        if viewModel.webLinkExpanded {
                            if filteredWebLinkTools.isEmpty && searchText.isEmpty {
                                // 空状态提示
                                HStack {
                                    Text("点击右侧 + 添加网页直达")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(Array(filteredWebLinkTools.enumerated()), id: \.element.id)
                                { index, tool in
                                    ToolItemRow(
                                        tool: binding(for: tool),
                                        viewModel: viewModel,
                                        isEvenRow: index % 2 == 0,
                                        focusedField: $focusedField,
                                        onEdit: {
                                            webLinkEditMode = .edit(tool)
                                        }
                                    )
                                }
                            }
                        }

                        // 实用工具分类（无添加按钮）
                        ToolSectionHeader(
                            title: "实用工具",
                            count: viewModel.utilityTools.count,
                            isExpanded: $viewModel.utilityExpanded,
                            onAdd: nil
                        )

                        if viewModel.utilityExpanded && !viewModel.utilityTools.isEmpty {
                            ForEach(Array(filteredUtilityTools.enumerated()), id: \.element.id) {
                                index, tool in
                                ToolItemRow(
                                    tool: binding(for: tool),
                                    viewModel: viewModel,
                                    isEvenRow: index % 2 == 0,
                                    focusedField: $focusedField,
                                    onEdit: nil
                                )
                            }
                        }

                        // 系统命令分类（无添加按钮）
                        ToolSectionHeader(
                            title: "系统命令",
                            count: viewModel.systemCommandTools.count,
                            isExpanded: $viewModel.systemCommandExpanded,
                            onAdd: nil
                        )

                        if viewModel.systemCommandExpanded && !viewModel.systemCommandTools.isEmpty
                        {
                            ForEach(
                                Array(filteredSystemCommandTools.enumerated()), id: \.element.id
                            ) { index, tool in
                                ToolItemRow(
                                    tool: binding(for: tool),
                                    viewModel: viewModel,
                                    isEvenRow: index % 2 == 0,
                                    focusedField: $focusedField,
                                    onEdit: nil
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
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
        .sheet(item: $webLinkEditMode) { mode in
            switch mode {
            case .add:
                WebLinkEditorSheet(
                    isPresented: Binding(
                        get: { webLinkEditMode != nil },
                        set: { if !$0 { webLinkEditMode = nil } }
                    ),
                    existingTool: nil,
                    onSave: { tool in
                        viewModel.addTool(tool)
                    }
                )
            case .edit(let tool):
                WebLinkEditorSheet(
                    isPresented: Binding(
                        get: { webLinkEditMode != nil },
                        set: { if !$0 { webLinkEditMode = nil } }
                    ),
                    existingTool: tool,
                    onSave: { updatedTool in
                        viewModel.updateTool(updatedTool)
                    }
                )
            }
        }
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

            HStack(spacing: 12) {
                Button("添加应用") {
                    viewModel.showFilePicker()
                }
                .buttonStyle(.borderedProminent)

                Button("添加网页") {
                    webLinkEditMode = .add
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 过滤方法

    private func filterTools(_ tools: [ToolItem]) -> [ToolItem] {
        if searchText.isEmpty { return tools }
        let lowercased = searchText.lowercased()
        return tools.filter { tool in
            tool.name.lowercased().contains(lowercased)
                || (tool.alias?.lowercased().contains(lowercased) ?? false)
                || (tool.path?.lowercased().contains(lowercased) ?? false)
                || (tool.url?.lowercased().contains(lowercased) ?? false)
        }
    }

    private var filteredAppTools: [ToolItem] {
        filterTools(viewModel.appTools)
    }

    private var filteredWebLinkTools: [ToolItem] {
        filterTools(viewModel.webLinkTools)
    }

    private var filteredUtilityTools: [ToolItem] {
        filterTools(viewModel.utilityTools)
    }

    private var filteredSystemCommandTools: [ToolItem] {
        filterTools(viewModel.systemCommandTools)
    }

    private func binding(for tool: ToolItem) -> Binding<ToolItem> {
        Binding(
            get: {
                viewModel.tools.first { $0.id == tool.id } ?? tool
            },
            set: { newValue in
                viewModel.updateTool(newValue)
            }
        )
    }
}

// MARK: - 分类标题组件

struct ToolSectionHeader: View {
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    var onAdd: (() -> Void)?  // 可选的添加按钮回调

    var body: some View {
        HStack {
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

                    Text("(\(count))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // 添加按钮（仅当 onAdd 不为 nil 时显示）
            if let onAdd = onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("添加")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}
