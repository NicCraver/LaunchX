## 1. 扩展 ClipboardItem 数据模型

- [ ] 1.1 在 ClipboardItem 结构体中添加 `rtfData: Data?` 字段用于存储 RTF 格式数据
- [ ] 1.2 在 ClipboardItem 结构体中添加 `htmlData: Data?` 字段用于存储 HTML 格式数据
- [ ] 1.3 更新 ClipboardItem 的 Codable 实现以支持新字段的序列化和反序列化
- [ ] 1.4 验证向后兼容性：确保能正确读取不包含新字段的旧数据

## 2. 修改剪贴板监控逻辑

- [ ] 2.1 在 ClipboardService 的监控方法中，检测并读取 RTF 格式数据（NSPasteboard.PasteboardType.rtf）
- [ ] 2.2 在 ClipboardService 的监控方法中，检测并读取 HTML 格式数据（NSPasteboard.PasteboardType.html）
- [ ] 2.3 创建 ClipboardItem 时同时保存纯文本、RTF 和 HTML 数据
- [ ] 2.4 测试从不同应用（Pages、Word、浏览器）复制富文本内容的保存效果

## 3. 修改剪贴板写入逻辑

- [ ] 3.1 修改 ClipboardService.writeToClipboard() 方法，添加富文本格式写入逻辑
- [ ] 3.2 当 asPlainText = false 时，按优先级写入 RTF、HTML 和纯文本格式
- [ ] 3.3 当 asPlainText = true 时，只写入纯文本格式
- [ ] 3.4 确保 pasteboard.clearContents() 后正确写入多种格式
- [ ] 3.5 测试富文本粘贴到不同应用的格式保留效果

## 4. 修复纯文本粘贴快捷键逻辑

- [ ] 4.1 修改 ClipboardPanelManager.pasteSelectedAsPlainText() 方法
- [ ] 4.2 添加逻辑：检查面板是否打开且有选中项
- [ ] 4.3 如果有选中项，使用选中项执行纯文本粘贴
- [ ] 4.4 如果无选中项，读取系统剪贴板内容并创建临时 ClipboardItem
- [ ] 4.5 使用临时 ClipboardItem 执行纯文本粘贴
- [ ] 4.6 测试快捷键在面板未打开时的行为

## 5. 修复剪贴板面板粘贴行为

- [ ] 5.1 验证 ClipboardPanelViewController 中回车键调用 pasteItem() 方法
- [ ] 5.2 验证 ClipboardPanelViewController 中 ⌘+回车键调用 pasteItemAsPlainText() 方法
- [ ] 5.3 确保 pasteItem() 使用 asPlainText = false 调用 writeToClipboard()
- [ ] 5.4 确保 pasteItemAsPlainText() 使用 asPlainText = true 调用 writeToClipboard()
- [ ] 5.5 测试回车和 ⌘+回车的行为差异

## 6. 测试和验证

- [ ] 6.1 测试纯文本粘贴快捷键在各种场景下的触发（面板打开/关闭、有/无选中项）
- [ ] 6.2 测试富文本内容的保存和恢复（从 Pages、Word、浏览器等应用复制）
- [ ] 6.3 测试回车直接粘贴保留格式，⌘+回车纯文本粘贴去除格式
- [ ] 6.4 测试向后兼容性：读取旧的剪贴板历史数据
- [ ] 6.5 测试不同类型内容（纯文本、富文本、图片、文件）的粘贴行为
- [ ] 6.6 验证剪贴板容量限制机制仍然正常工作
