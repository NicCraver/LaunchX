import SwiftUI

// MARK: - Snippet 设置视图

struct SnippetSettingsView: View {
    @State private var settings = SnippetSettings.load()
    @ObservedObject private var snippetService = SnippetService.shared
    @State private var searchText = ""
    @State private var selectedSnippet: SnippetItem?
    @State private var showAddSheet = false
    @State private var showDeleteAlert = false
    @State private var snippetToDelete: SnippetItem?

    private var filteredSnippets: [SnippetItem] {
        if searchText.isEmpty {
            return snippetService.snippets
        }
        return snippetService.search(query: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行
            HStack(spacing: 12) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.orange)
                Text("Snippet")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: settings.isEnabled) { _, newValue in
                        settings.save()
                        if newValue {
                            SnippetService.shared.startMonitoring()
                        } else {
                            SnippetService.shared.stopMonitoring()
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // 工具栏
            HStack(spacing: 12) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索 Snippet...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                Spacer()

                // 添加按钮
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Snippet 列表
            if snippetService.snippets.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无 Snippet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击 + 添加新的文本片段")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(filteredSnippets) { snippet in
                        SnippetRowView(
                            snippet: snippet,
                            onEdit: {
                                selectedSnippet = snippet
                            },
                            onDelete: {
                                snippetToDelete = snippet
                                showDeleteAlert = true
                            },
                            onToggle: {
                                snippetService.toggleEnabled(snippet)
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // 底部说明
            VStack(alignment: .leading, spacing: 8) {
                Text("使用说明")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("动态变量")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("{date} {time} {datetime}")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("其他变量")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("{year} {month} {day} {weekday}")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("UUID")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("{uuid} {uuid_short}")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showAddSheet) {
            SnippetEditorSheet(mode: .add) { newSnippet in
                snippetService.addSnippet(newSnippet)
            }
        }
        .sheet(item: $selectedSnippet) { snippet in
            SnippetEditorSheet(mode: .edit(snippet)) { updatedSnippet in
                snippetService.updateSnippet(updatedSnippet)
            }
        }
        .alert("删除 Snippet", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let snippet = snippetToDelete {
                    snippetService.removeSnippet(snippet)
                }
            }
        } message: {
            if let snippet = snippetToDelete {
                Text("确定要删除「\(snippet.name)」吗？此操作无法撤销。")
            }
        }
    }
}

// MARK: - Snippet 行视图

struct SnippetRowView: View {
    let snippet: SnippetItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 启用状态指示
            Circle()
                .fill(snippet.isEnabled ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snippet.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(snippet.isEnabled ? .primary : .secondary)

                    if snippet.hasDynamicContent {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 8) {
                    // 关键词
                    Text(snippet.keyword)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)

                    // 箭头
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    // 替换内容预览
                    Text(snippet.contentPreview)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 操作按钮（悬停时显示）
            if isHovered {
                HStack(spacing: 8) {
                    Button {
                        onToggle()
                    } label: {
                        Image(systemName: snippet.isEnabled ? "pause.circle" : "play.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help(snippet.isEnabled ? "禁用" : "启用")

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("编辑")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

// MARK: - Snippet 编辑器弹窗

enum SnippetEditorMode {
    case add
    case edit(SnippetItem)

    var title: String {
        switch self {
        case .add: return "添加 Snippet"
        case .edit: return "编辑 Snippet"
        }
    }
}

struct SnippetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: SnippetEditorMode
    let onSave: (SnippetItem) -> Void

    @State private var name: String = ""
    @State private var keyword: String = ""
    @State private var content: String = ""
    @State private var isEnabled: Bool = true
    @State private var keywordError: String?

    private var existingId: UUID? {
        if case .edit(let snippet) = mode {
            return snippet.id
        }
        return nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !keyword.trimmingCharacters(in: .whitespaces).isEmpty
            && !content.isEmpty
            && keywordError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(mode.title)
                    .font(.headline)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // 表单
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 名称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：邮箱签名", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 关键词
                    VStack(alignment: .leading, spacing: 6) {
                        Text("触发关键词")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：;;sig 或 //email", text: $keyword)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: keyword) { _, newValue in
                                validateKeyword(newValue)
                            }
                        if let error = keywordError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("输入此关键词后将自动替换为下方内容")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }

                    // 替换内容
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("替换内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            // 动态变量提示
                            Menu {
                                Button("{date} - 日期 (2024-01-01)") {
                                    insertVariable("{date}")
                                }
                                Button("{date_cn} - 中文日期 (2024年01月01日)") {
                                    insertVariable("{date_cn}")
                                }
                                Divider()
                                Button("{time} - 时间 (14:30:00)") {
                                    insertVariable("{time}")
                                }
                                Button("{time_short} - 短时间 (14:30)") {
                                    insertVariable("{time_short}")
                                }
                                Button("{datetime} - 日期时间") {
                                    insertVariable("{datetime}")
                                }
                                Divider()
                                Button("{year} - 年份") {
                                    insertVariable("{year}")
                                }
                                Button("{month} - 月份") {
                                    insertVariable("{month}")
                                }
                                Button("{day} - 日期") {
                                    insertVariable("{day}")
                                }
                                Button("{weekday} - 星期") {
                                    insertVariable("{weekday}")
                                }
                                Divider()
                                Button("{uuid} - UUID") {
                                    insertVariable("{uuid}")
                                }
                                Button("{uuid_short} - 短 UUID") {
                                    insertVariable("{uuid_short}")
                                }
                                Button("{timestamp} - 时间戳") {
                                    insertVariable("{timestamp}")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("插入变量")
                                }
                                .font(.caption)
                            }
                            .menuStyle(.borderlessButton)
                        }

                        TextEditor(text: $content)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }

                    // 启用状态
                    Toggle("启用此 Snippet", isOn: $isEnabled)
                        .toggleStyle(.switch)

                    // 预览
                    if !content.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("预览效果")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(previewContent)
                                .font(.system(size: 12))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("保存") {
                    saveSnippet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if case .edit(let snippet) = mode {
                name = snippet.name
                keyword = snippet.keyword
                content = snippet.content
                isEnabled = snippet.isEnabled
            }
        }
    }

    private var previewContent: String {
        let preview = SnippetItem(
            name: name,
            keyword: keyword,
            content: content,
            isEnabled: isEnabled
        )
        return preview.processedContent
    }

    private func validateKeyword(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            keywordError = nil
            return
        }

        if SnippetService.shared.isKeywordExists(trimmed, excludingId: existingId) {
            keywordError = "此关键词已被使用"
        } else if trimmed.count < 2 {
            keywordError = "关键词至少需要 2 个字符"
        } else {
            keywordError = nil
        }
    }

    private func insertVariable(_ variable: String) {
        content += variable
    }

    private func saveSnippet() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespaces)

        let snippet: SnippetItem
        if case .edit(let existing) = mode {
            snippet = SnippetItem(
                id: existing.id,
                name: trimmedName,
                keyword: trimmedKeyword,
                content: content,
                isEnabled: isEnabled,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
        } else {
            snippet = SnippetItem(
                name: trimmedName,
                keyword: trimmedKeyword,
                content: content,
                isEnabled: isEnabled
            )
        }

        onSave(snippet)
        dismiss()
    }
}

#Preview {
    SnippetSettingsView()
        .frame(width: 600, height: 700)
}
