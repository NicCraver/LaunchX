## Context

当前剪贴板功能存在两个关键问题：

1. **纯文本粘贴快捷键不工作**：`ClipboardPanelManager.pasteSelectedAsPlainText()` 方法依赖于剪贴板面板已打开且有选中项，导致全局快捷键无法触发。
2. **富文本格式丢失**：`ClipboardService.writeToClipboard()` 对文本类型只写入纯文本（`pasteboard.setString`），无论 `asPlainText` 参数值如何，导致回车和 ⌘+回车行为一致。

当前架构：
- `HotKeyService` 负责全局快捷键注册和回调
- `ClipboardPanelManager` 管理剪贴板面板的显示和交互
- `ClipboardService` 负责剪贴板数据的监控、存储和粘贴
- `ClipboardItem` 数据模型存储剪贴板项的元数据和内容

## Goals / Non-Goals

**Goals:**
- 修复纯文本粘贴全局快捷键，使其能在任何时候直接操作系统剪贴板
- 修复富文本格式的保存和恢复，确保直接粘贴保留格式，纯文本粘贴去除格式
- 保持现有 API 接口不变，最小化对其他模块的影响
- 确保向后兼容，不影响已保存的剪贴板历史数据

**Non-Goals:**
- 不改变剪贴板面板的 UI 设计
- 不添加新的剪贴板功能（如格式转换选项）
- 不优化剪贴板监控性能
- 不修改剪贴板历史的存储容量限制

## Decisions

### 决策 1：纯文本粘贴快捷键直接操作系统剪贴板

**方案 A（选择）**：修改 `ClipboardPanelManager.pasteSelectedAsPlainText()` 逻辑，当面板未打开或无选中项时，直接读取系统剪贴板最新内容并转为纯文本粘贴。

**方案 B（拒绝）**：在 `ClipboardService` 中添加新方法 `pasteSystemClipboardAsPlainText()`，由 HotKeyService 直接调用。

**选择理由**：
- 方案 A 保持现有调用链不变，只修改内部逻辑
- 方案 A 更符合用户预期：快捷键应该"智能"工作，优先使用选中项，回退到系统剪贴板
- 方案 B 会增加 API 复杂度，且需要修改 HotKeyService 的回调逻辑

### 决策 2：扩展 ClipboardItem 数据模型存储富文本

**方案 A（选择）**：添加 `rtfData: Data?` 和 `htmlData: Data?` 字段存储富文本格式。

**方案 B（拒绝）**：使用 `[String: Data]` 字典存储所有格式类型。

**选择理由**：
- 方案 A 类型安全，明确支持的格式类型
- macOS 剪贴板主要使用 RTF 和 HTML 两种富文本格式
- 方案 A 更容易序列化和反序列化
- 方案 B 过于灵活，可能导致格式类型不一致

### 决策 3：修改 writeToClipboard 方法支持富文本

**实现策略**：
1. 当 `asPlainText = false` 时，按优先级写入多种格式：RTF → HTML → 纯文本
2. 当 `asPlainText = true` 时，只写入纯文本
3. 使用 `NSPasteboard.setData(_:forType:)` 写入不同格式类型

**格式优先级**：
```
NSPasteboard.PasteboardType.rtf (最高优先级)
NSPasteboard.PasteboardType.html
NSPasteboard.PasteboardType.string (纯文本)
```

### 决策 4：向后兼容旧数据

**策略**：
- 旧的 ClipboardItem 没有 `rtfData` 和 `htmlData` 字段，这些字段为 optional
- 读取旧数据时，这些字段为 nil，不影响纯文本粘贴
- 新监控到的剪贴板内容会自动保存富文本格式

## Risks / Trade-offs

### 风险 1：富文本数据增加存储空间
**影响**：RTF 和 HTML 数据可能比纯文本大 2-5 倍
**缓解措施**：
- 保持现有的容量限制机制（`ClipboardCapacityLimit`）
- 用户可以通过设置控制历史记录数量
- 大多数文本内容的富文本数据不会显著增加存储

### 风险 2：某些应用的富文本格式不兼容
**影响**：部分应用可能使用非标准的富文本格式
**缓解措施**：
- 优先使用 macOS 标准格式（RTF、HTML）
- 如果富文本数据无法解析，回退到纯文本
- 保留纯文本作为最后的兜底方案

### 风险 3：纯文本粘贴快捷键读取系统剪贴板可能与预期不符
**影响**：用户可能期望粘贴 LaunchX 历史中的某项，但实际粘贴的是系统剪贴板最新内容
**缓解措施**：
- 这是合理的行为：全局快捷键应该操作全局状态（系统剪贴板）
- 如果用户想粘贴历史项，应该先打开面板选择
- 文档中明确说明快捷键的行为

## 实现流程图

### 纯文本粘贴快捷键流程
```
用户按下快捷键
    ↓
HotKeyService.onPlainTextPasteHotKeyPressed
    ↓
ClipboardPanelManager.pasteSelectedAsPlainText()
    ↓
检查面板是否打开且有选中项？
    ├─ 是 → 使用选中项
    │         ↓
    │    ClipboardService.pasteAsPlainText(selectedItem)
    │
    └─ 否 → 读取系统剪贴板
              ↓
         创建临时 ClipboardItem（只包含纯文本）
              ↓
         ClipboardService.pasteAsPlainText(tempItem)
```

### 富文本写入流程
```
writeToClipboard(item, asPlainText)
    ↓
清空剪贴板
    ↓
asPlainText == true？
    ├─ 是 → 只写入纯文本
    │         pasteboard.setString(text, forType: .string)
    │
    └─ 否 → 按优先级写入多种格式
              ├─ 如果有 rtfData
              │    pasteboard.setData(rtfData, forType: .rtf)
              ├─ 如果有 htmlData
              │    pasteboard.setData(htmlData, forType: .html)
              └─ 写入纯文本（兜底）
                   pasteboard.setString(text, forType: .string)
```

## Migration Plan

**部署步骤**：
1. 修改 `ClipboardItem` 数据模型，添加富文本字段
2. 修改 `ClipboardService` 监控逻辑，保存富文本数据
3. 修改 `ClipboardService.writeToClipboard()` 方法
4. 修改 `ClipboardPanelManager.pasteSelectedAsPlainText()` 方法
5. 测试各种场景（面板打开/关闭、有/无选中项、富文本/纯文本内容）

**回滚策略**：
- 如果出现问题，通过 Git 回滚到修改前的版本
- 新增的字段为 optional，不会导致旧数据无法读取
- 回滚后，富文本数据会被忽略，但不影响纯文本功能

**测试重点**：
- 纯文本粘贴快捷键在面板未打开时的行为
- 富文本内容的保存和恢复（测试 Pages、Word、浏览器等应用）
- 回车和 ⌘+回车的行为差异
- 向后兼容性（读取旧的剪贴板历史数据）

## Open Questions

无待解决问题。设计方案已明确，可以开始实现。
