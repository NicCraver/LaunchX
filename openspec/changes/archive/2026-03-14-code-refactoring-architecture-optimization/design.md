## Context

LaunchX 项目经过多次功能迭代后，代码库出现了明显的架构问题：

**当前状态**：
- SearchPanelViewController: 4910 行，包含搜索逻辑、UI 渲染、数据源、代理方法、结果处理
- ToolsSettingsView: 1417 行，包含工具列表、编辑器、验证逻辑
- ClipboardPanelViewController: 1405 行，类似 SearchPanel 的结构问题
- HotKeyService: 1367 行，管理所有快捷键注册、冲突检测、回调
- 12 个视图文件中重复实现快捷键录制器组件
- 8 个视图文件中重复实现图标调整方法
- 51 个文件包含 TODO/FIXME 注释

**约束**：
- 必须保持功能完全不变（纯重构）
- 不能破坏现有的公共 API
- 需要保持 git 历史可追踪
- 重构必须分阶段进行，每阶段可独立测试和回滚

## Goals / Non-Goals

**Goals:**
- 将超大文件拆分为职责单一的模块（目标：单文件不超过 500 行）
- 提取重复的 UI 组件为可复用组件库
- 创建共享工具类，消除代码重复
- 优化文件组织结构，提高代码可发现性
- 移除未使用的代码和过时的注释
- 建立清晰的模块边界和依赖关系

**Non-Goals:**
- 不改变任何功能行为或用户体验
- 不重写核心算法或业务逻辑
- 不引入新的第三方依赖
- 不进行性能优化（除非重构自然带来）
- 不修改数据模型或存储格式
- 不改变现有的测试覆盖率

## Decisions

### 决策 1: 文件拆分策略 - 按职责垂直切分

**选择**: 将大文件按职责垂直切分为多个文件，而不是按类型水平切分

**理由**:
- SearchPanelViewController 拆分为：
  - `SearchPanelViewController.swift` - 核心控制器逻辑（~500行）
  - `SearchPanelViewController+DataSource.swift` - NSTableViewDataSource 实现
  - `SearchPanelViewController+Delegate.swift` - 各种 Delegate 实现
  - `ResultCellView.swift` - 结果单元格视图
  - `SearchPanelViewModel.swift` - 搜索状态和业务逻辑
- 保持相关代码在同一目录，便于查找和维护
- 使用 extension 文件保持类的完整性

**替代方案**:
- 方案 A: 按类型水平切分（所有 ViewController 一起，所有 View 一起）→ 拒绝，相关代码分散
- 方案 B: 完全重写为 MVVM 架构 → 拒绝，超出重构范围，风险太大

### 决策 2: 共享组件提取 - 创建 Components 目录

**选择**: 创建 `Views/Components/` 目录，提取可复用组件

**提取的组件**:
```swift
// Views/Components/HotKeyRecorder.swift
struct HotKeyRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    let onConflict: (String) -> Void
}

// Views/Components/SettingsRow.swift
struct SettingsRow<Content: View>: View {
    let label: String
    let labelWidth: CGFloat
    @ViewBuilder let content: () -> Content
}

// Views/Components/KeyCapView.swift
struct KeyCapView: View {
    let text: String
}
```

**理由**:
- 快捷键录制器在 12 个地方重复实现，代码几乎完全相同
- 设置行布局模式在所有设置视图中重复
- 提取后可以统一修复 bug 和改进 UI

**替代方案**:
- 方案 A: 使用继承创建基类 → 拒绝，Swift/SwiftUI 推荐组合而非继承
- 方案 B: 保持重复，使用代码片段 → 拒绝，无法统一维护

### 决策 3: 工具类组织 - 创建 Utilities 目录

**选择**: 创建 `Utilities/` 目录，按功能分类工具类

**目录结构**:
```
Utilities/
├── ImageUtils.swift          // 图标调整、图像处理
├── StringUtils.swift          // 字符串处理、格式化
├── KeyCodeUtils.swift         // 键码转换、快捷键字符串
├── ValidationUtils.swift      // 输入验证、URL 验证
└── Extensions/
    ├── NSImage+Resize.swift
    └── String+Validation.swift
```

**理由**:
- `resizeIcon` 方法在 8 个视图中重复实现
- 键码转换逻辑在多个地方重复
- 集中管理便于测试和维护

### 决策 4: 服务层重组 - 按核心/功能分类

**选择**: 将 Services 目录重组为 Core 和 Features

**新结构**:
```
Services/
├── Core/                      // 核心基础服务
│   ├── HotKeyService.swift
│   ├── PermissionService.swift
│   └── PanelManager.swift
├── Features/                  // 功能服务
│   ├── Search/
│   │   ├── SearchEngine/
│   │   └── IDERecentProjectsService.swift
│   ├── Clipboard/
│   │   ├── ClipboardService.swift
│   │   └── ClipboardPanelManager.swift
│   ├── AITranslate/
│   │   ├── AITranslateService.swift
│   │   └── AITranslatePanelManager.swift
│   └── Bookmark/
│       └── BookmarkService.swift
└── Backup/
    └── BackupService.swift
```

**理由**:
- 清晰区分核心服务和功能服务
- 功能服务按域分组，便于查找
- 为未来的模块化做准备

### 决策 5: HotKeyService 拆分 - 职责分离

**选择**: 将 HotKeyService (1367行) 拆分为三个类

**拆分方案**:
```swift
// HotKeyService.swift (~400行)
// 主服务类，协调其他组件
class HotKeyService {
    private let registry: HotKeyRegistry
    private let validator: HotKeyValidator
}

// HotKeyRegistry.swift (~400行)
// 负责快捷键注册和管理
class HotKeyRegistry {
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void)
    func unregister(keyCode: UInt32, modifiers: UInt32)
}

// HotKeyValidator.swift (~300行)
// 负责冲突检测和验证
class HotKeyValidator {
    func checkConflict(keyCode: UInt32, modifiers: UInt32) -> String?
    func isValidCombination(keyCode: UInt32, modifiers: UInt32) -> Bool
}
```

**理由**:
- 单一职责原则：注册、验证、管理分离
- 便于单元测试
- 降低单个文件的复杂度

## Risks / Trade-offs

### 风险 1: 大规模文件移动可能引入回归 bug
**风险**: 重构过程中可能意外改变行为
**缓解**:
- 每个拆分步骤后运行完整测试套件
- 使用 git diff 仔细检查每个改动
- 先拆分，后优化，避免同时进行多种改动
- 保持每个 commit 的改动范围小且聚焦

### 风险 2: 文件移动破坏 git blame 历史
**风险**: 重构后难以追踪代码历史
**缓解**:
- 使用 `git mv` 而不是删除+创建
- 在 commit message 中记录文件移动关系
- 使用 `git log --follow` 追踪文件历史
- 保留原始文件路径的注释

### 风险 3: 团队成员需要适应新结构
**风险**: 开发者找不到代码位置
**缓解**:
- 创建迁移指南文档（旧路径 → 新路径）
- 在 PR 中详细说明文件移动
- 保留 1-2 周的过渡期，允许询问
- 更新 README 和开发文档

### Trade-off: 文件数量增加 vs 单文件复杂度降低
**Trade-off**: 文件从 ~100 个增加到 ~150 个
**接受理由**:
- 单文件复杂度大幅降低（4910行 → 500行以下）
- 现代 IDE 的文件导航功能强大
- 清晰的目录结构比文件数量更重要
- 便于并行开发和代码审查

### Trade-off: 提取共享组件的抽象成本
**Trade-off**: 共享组件需要更通用的 API
**接受理由**:
- 当前重复代码维护成本更高
- 统一的组件便于修复 bug
- 可以逐步优化组件 API
- 提高代码复用率

## Migration Plan

### 阶段 1: 提取共享组件（1-2天）
1. 创建 `Views/Components/` 目录
2. 提取 HotKeyRecorderView 组件
3. 提取 SettingsRow 组件
4. 提取 KeyCapView 组件
5. 更新所有使用方，逐个替换
6. 测试所有设置视图

### 阶段 2: 创建工具类（1天）
1. 创建 `Utilities/` 目录
2. 提取 ImageUtils
3. 提取 KeyCodeUtils
4. 更新所有使用方
5. 移除重复代码

### 阶段 3: 拆分 SearchPanelViewController（2-3天）
1. 提取 ResultCellView
2. 创建 SearchPanelViewModel
3. 拆分 DataSource extension
4. 拆分 Delegate extensions
5. 测试搜索功能

### 阶段 4: 拆分其他大文件（3-4天）
1. 拆分 ToolsSettingsView
2. 拆分 ClipboardPanelViewController
3. 拆分 HotKeyService
4. 拆分 AITranslatePanelViewController
5. 测试所有功能

### 阶段 5: 重组目录结构（1-2天）
1. 创建新的目录结构
2. 使用 git mv 移动文件
3. 更新 import 语句
4. 更新 Xcode 项目文件
5. 全量测试

### 阶段 6: 清理和优化（1天）
1. 移除 TODO/FIXME 注释
2. 移除未使用的代码
3. 统一代码风格
4. 更新文档

### 回滚策略
- 每个阶段创建独立的 git branch
- 每个阶段完成后合并到 main
- 如果发现问题，可以 revert 整个阶段的 commits
- 保留原始代码的 backup branch（refactor-backup）

### 验证标准
- 所有现有测试通过
- 手动测试所有主要功能
- 代码审查通过
- 性能无明显下降
- 编译无警告

## Open Questions

无待解决问题。重构方案已明确，风险可控。
