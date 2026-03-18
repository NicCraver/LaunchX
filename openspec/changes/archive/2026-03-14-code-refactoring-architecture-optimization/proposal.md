## Why

随着项目功能的增长，代码库出现了明显的技术债务：最大的文件达到 4910 行（SearchPanelViewController），多个文件超过 1000 行，存在大量重复代码模式（如快捷键录制、设置视图结构），以及未使用的代码。这导致代码难以维护、测试困难、新功能开发效率降低。需要进行系统性的架构优化和代码重构，提高代码质量和可维护性。

## What Changes

- 拆分超大文件（SearchPanelViewController 4910行、ToolsSettingsView 1417行、ClipboardPanelViewController 1405行、HotKeyService 1367行）为更小的、职责单一的模块
- 提取重复的 UI 组件模式（快捷键录制器、设置视图布局、图标调整工具）为可复用组件
- 创建共享工具类（ImageUtils、HotKeyRecorderComponent、SettingsViewHelpers）
- 移除未使用的代码和注释（TODO、FIXME、已注释的旧代码）
- 优化文件组织结构，按功能域分组（Views/Components、Views/Settings、Services/Core、Services/Features）
- 统一代码风格和命名约定
- 改进依赖注入和服务定位模式

## Capabilities

### New Capabilities
- `shared-ui-components`: 可复用的 UI 组件库（快捷键录制器、设置布局、通用视图元素）
- `utility-helpers`: 共享工具类和辅助方法（图像处理、字符串处理、数据转换）
- `modular-architecture`: 模块化架构模式和文件组织规范

### Modified Capabilities
<!-- 这是纯重构，不改变功能需求，因此没有 capability 的需求变更 -->

## Impact

### 受影响的代码

**需要拆分的大文件**：
- `Views/SearchPanelViewController.swift` (4910行) → 拆分为 SearchPanelViewController + ResultCellView + SearchPanelExtensions
- `Views/ToolsSettingsView.swift` (1417行) → 拆分为 ToolsSettingsView + ToolItemRow + ToolEditorView
- `Views/ClipboardPanelViewController.swift` (1405行) → 拆分为 ClipboardPanelViewController + ClipboardCellView + ClipboardExtensions
- `Services/HotKeyService.swift` (1367行) → 拆分为 HotKeyService + HotKeyRegistry + HotKeyValidator
- `Views/AITranslatePanelViewController.swift` (1332行) → 拆分为 AITranslatePanelViewController + TranslateCellView + TranslateExtensions
- `Views/AdvancedExtensionsView.swift` (1002行) → 提取各扩展设置视图到独立文件

**需要提取的共享组件**：
- 快捷键录制器组件（在 BookmarkSearchSettingsView、TwoFactorAuthSettingsView、HotKeyRecorderPopover 中重复）
- 设置视图布局模式（标题行、开关、标签对齐）
- 图标调整工具（resizeIcon 方法在多个视图中重复）

**新增的目录结构**：
- `LaunchX/Views/Components/` - 共享 UI 组件
- `LaunchX/Views/Settings/Extensions/` - 扩展设置视图
- `LaunchX/Utilities/` - 工具类和辅助方法
- `LaunchX/Services/Core/` - 核心服务
- `LaunchX/Services/Features/` - 功能服务

### 风险和缓解

**风险**：
- 大规模重构可能引入回归 bug
- 文件移动可能破坏 git 历史追踪
- 团队成员需要适应新的文件组织

**缓解措施**：
- 每个重构步骤后运行完整测试套件
- 使用 git mv 保留文件历史
- 保持功能行为完全不变（纯重构）
- 分阶段进行，每个阶段可独立回滚

### 回滚计划

- 每个重构阶段创建独立的 git commit
- 保留原始文件的备份分支
- 如果发现问题，可以逐个 commit 回滚
- 重构不改变公共 API，不影响外部依赖
