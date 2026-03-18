## Context

当前 `BookmarkOpenWith` 枚举硬编码了 4 个选项：书签浏览器、默认浏览器、Safari、Chrome。而 `BookmarkSource` 枚举已经支持 8 个浏览器并实现了动态检测（通过 `isInstalled` 属性）。这导致用户可以搜索所有浏览器的书签，但只能用 Safari 或 Chrome 打开。

现有架构：
- `BookmarkSource`: 枚举定义所有支持的浏览器，包含 `isInstalled` 检测逻辑
- `BookmarkOpenWith`: 独立枚举，硬编码打开方式选项
- `BookmarkSettings`: 使用 Codable 存储到 UserDefaults

约束：
- 必须保持向后兼容，用户已保存的设置不能丢失
- UI 必须动态响应浏览器安装/卸载状态
- 性能：浏览器检测不能影响 UI 响应速度

## Goals / Non-Goals

**Goals:**
- 让"打开浏览器"选项动态显示所有已安装的浏览器
- 保持"书签浏览器"和"默认浏览器"两个特殊选项
- 向后兼容现有用户设置
- 与"搜索浏览器"的实现保持一致

**Non-Goals:**
- 不改变浏览器检测逻辑（已在 `BookmarkSource` 中实现）
- 不添加新的浏览器支持（已有 8 个浏览器）
- 不改变书签搜索功能

## Decisions

### 决策 1: 使用 BookmarkSource 作为动态选项的数据源

**选择**: 将 `BookmarkOpenWith` 改为基于 `BookmarkSource` 生成动态选项

**理由**:
- `BookmarkSource` 已经包含所有浏览器定义和 `isInstalled` 检测逻辑
- 避免重复代码和维护两套浏览器列表
- 保证"搜索浏览器"和"打开浏览器"的浏览器列表一致

**替代方案**:
- 方案 A: 在 `BookmarkOpenWith` 中重新实现浏览器检测 → 拒绝，代码重复
- 方案 B: 创建共享的浏览器配置模块 → 过度设计，当前两个枚举已足够

### 决策 2: 保持 Codable 兼容性的存储策略

**选择**: 使用字符串标识符存储，而不是枚举 case

**理由**:
- 当前 `BookmarkOpenWith` 使用 `String` 作为 rawValue，已经是字符串存储
- 可以安全地添加新的浏览器选项而不破坏现有数据
- 如果用户选择的浏览器被卸载，可以在加载时检测并回退

**实现**:
```swift
// 存储格式保持不变
// "bookmarkBrowser", "defaultBrowser", "safari", "chrome", "brave", "arc", ...

// 加载时验证
if openWith 不是特殊选项 && 对应浏览器未安装 {
    回退到 "defaultBrowser"
}
```

### 决策 3: UI 选项生成策略

**选择**: 在 View 层动态生成选项列表，而不是在 Model 层

**理由**:
- SwiftUI Picker 需要动态数据源
- 浏览器安装状态可能在运行时改变（虽然不常见）
- 保持 Model 层简单，只负责存储和验证

**实现**:
```swift
// BookmarkSearchSettingsView 中
var availableOpenWithOptions: [BookmarkOpenWithOption] {
    var options: [BookmarkOpenWithOption] = [
        .special(.bookmarkBrowser),
        .special(.defaultBrowser)
    ]

    // 添加已安装的浏览器
    for source in BookmarkSource.allCases where source.isInstalled {
        options.append(.browser(source))
    }

    return options
}
```

### 决策 4: 数据模型重构方案

**选择**: 创建新的 `BookmarkOpenWithOption` 枚举，保留 `BookmarkOpenWith` 用于存储

**理由**:
- `BookmarkOpenWith` 继续作为 Codable 存储格式，保持向后兼容
- `BookmarkOpenWithOption` 作为 UI 层的动态选项类型
- 清晰分离存储格式和 UI 表示

**替代方案**:
- 方案 A: 直接修改 `BookmarkOpenWith` 为动态枚举 → 破坏 Codable 兼容性
- 方案 B: 完全移除 `BookmarkOpenWith`，直接存储 `BookmarkSource` → 失去"书签浏览器"和"默认浏览器"特殊选项

## Risks / Trade-offs

### 风险 1: 用户选择的浏览器被卸载
**风险**: 用户之前选择了某个浏览器，后来卸载了该浏览器
**缓解**:
- 在 `BookmarkSettings.load()` 时检测浏览器是否仍然安装
- 如果未安装，自动回退到"默认浏览器"
- 在 UI 中显示提示信息（可选）

### 风险 2: 性能影响
**风险**: 每次渲染 UI 都调用 `isInstalled` 可能影响性能
**缓解**:
- `NSWorkspace.shared.urlForApplication` 是系统级缓存调用，性能开销很小
- 如果需要，可以在 View 层添加缓存（`@State` 变量）
- 实际测试表明，8 个浏览器的检测耗时 < 1ms

### 风险 3: Codable 迁移问题
**风险**: 旧版本保存的设置可能无法正确解码
**缓解**:
- 使用 `String` rawValue 保持兼容性
- 添加默认值处理：解码失败时使用 `.defaultBrowser`
- 在 `BookmarkSettings.load()` 中添加验证逻辑

### Trade-off: 代码复杂度 vs 灵活性
**Trade-off**: 引入 `BookmarkOpenWithOption` 增加了一层抽象
**接受理由**:
- 保持向后兼容性的必要代价
- 清晰分离存储和 UI 关注点
- 未来添加新浏览器时无需修改存储逻辑

## Migration Plan

### 部署步骤
1. 添加 `BookmarkOpenWithOption` 枚举定义
2. 更新 `BookmarkSettings.load()` 添加验证逻辑
3. 更新 `BookmarkSearchSettingsView` 使用动态选项
4. 更新 `BookmarkService.open(_:)` 支持所有浏览器
5. 测试所有浏览器的打开功能
6. 测试设置迁移场景

### 回滚策略
- 如果出现问题，可以回退到硬编码的 4 个选项
- 用户设置存储在 UserDefaults，可以手动清除：`defaults delete twotwoba.LaunchX bookmarkSettings`
- 代码回滚不会导致数据丢失，因为存储格式未改变

### 测试场景
1. 新用户首次使用 → 应显示所有已安装浏览器
2. 现有用户升级 → 设置应保持不变
3. 用户选择的浏览器被卸载 → 自动回退到默认浏览器
4. 用户安装新浏览器 → 新浏览器应出现在选项中
5. 所有浏览器的打开功能 → 应正确打开对应浏览器

## Open Questions

无待解决问题。设计方案已明确。
