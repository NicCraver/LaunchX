## Context

当前应用包含两个低使用率的表情包功能模块（搜索和收藏），以及一个书签搜索功能。书签搜索的浏览器选项硬编码为 Safari 和 Chrome，无法适应用户安装的其他浏览器（如 Helium、Arc、Brave 等）。

现有实现：
- 表情包搜索：`MemeSearchService` 单例 + `MemeSearchSettingsView`
- 表情包收藏：`MemeFavoriteService` 单例 + `MemeFavoriteSettingsView` + 本地存储
- 书签搜索：`BookmarkService` 中的 `BookmarkSource` 枚举硬编码 `.safari` 和 `.chrome`

## Goals / Non-Goals

**Goals:**
- 完全移除表情包搜索和收藏功能的代码、UI 和设置项
- 实现动态浏览器检测，自动发现系统中已安装的浏览器
- 保持书签搜索的现有功能（读取书签、搜索、打开）不变

**Non-Goals:**
- 不自动迁移或删除用户的表情包收藏数据（用户需手动清理）
- 不支持检测所有浏览器，仅支持主流 Chromium 系浏览器和 Safari
- 不改变书签数据的读取逻辑（仍从标准路径读取）

## Decisions

### 决策 1：使用 NSWorkspace 进行浏览器检测

**选择：** 使用 `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` 检测浏览器是否安装

**理由：**
- macOS 原生 API，无需第三方依赖
- 可靠地检测应用是否存在于系统中
- 支持通过 Bundle ID 精确识别浏览器

**替代方案：**
- 文件系统扫描 `/Applications`：不可靠，用户可能安装在其他位置
- 硬编码路径检查：维护成本高，无法适应不同安装位置

### 决策 2：支持的浏览器列表

**选择：** 支持以下浏览器的检测和书签读取
- Safari (`com.apple.Safari`)
- Chrome (`com.google.Chrome`)
- Brave (`com.brave.Browser`)
- Arc (`company.thebrowser.Browser`)
- Edge (`com.microsoft.edgemac`)
- Vivaldi (`com.vivaldi.Vivaldi`)
- Opera (`com.operasoftware.Opera`)

**理由：**
- 覆盖主流浏览器
- Chromium 系浏览器书签格式统一（JSON），易于扩展
- Safari 使用 plist 格式，已有现成解析逻辑

**书签路径规则：**
- Safari: `~/Library/Safari/Bookmarks.plist`
- Chromium 系: `~/Library/Application Support/<BrowserName>/Default/Bookmarks`

### 决策 3：保留 BookmarkSource 枚举，动态过滤

**选择：** 扩展 `BookmarkSource` 枚举以包含所有支持的浏览器，UI 中仅显示已安装的浏览器

**理由：**
- 保持类型安全
- 避免破坏现有的 Codable 序列化逻辑
- UI 层动态过滤比数据层动态生成更简单

**实现：**
```swift
enum BookmarkSource: String, Codable, CaseIterable {
    case safari, chrome, brave, arc, edge, vivaldi, opera

    var bundleIdentifier: String { ... }
    var bookmarkPath: String { ... }
    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}
```

### 决策 4：表情包模块的清理策略

**选择：** 直接删除所有相关文件，不保留任何代码

**理由：**
- 功能使用率低，无保留价值
- Git 历史可恢复，无需保留注释代码
- 减少维护负担

**清理范围：**
- 删除 Service 文件（`MemeSearchService.swift`, `MemeFavoriteService.swift`）
- 删除 View 文件（`MemeSearchSettingsView.swift`, `MemeFavoriteSettingsView.swift`）
- 删除 Model 文件（`MemeItem.swift`）
- 从 `AdvancedExtensionsView.swift` 中移除相关设置项
- 清理 UserDefaults 中的相关键（如果有）

## Risks / Trade-offs

**[风险] 用户数据丢失** → 在发布说明中提醒用户备份表情包收藏数据，应用不会自动删除 `~/Library/Application Support/LaunchX/MemeFavorites/`

**[风险] 浏览器书签路径变化** → 仅支持标准安装路径，非标准路径需用户手动配置（暂不支持）

**[风险] 新浏览器不被识别** → 用户可通过 GitHub Issue 请求添加，维护成本可控

**[权衡] 不支持 Firefox** → Firefox 书签格式为 SQLite，解析复杂度高，暂不支持

## Migration Plan

1. **代码清理阶段：**
   - 删除表情包相关文件
   - 从 `AdvancedExtensionsView.swift` 移除表情包设置 UI
   - 扩展 `BookmarkSource` 枚举

2. **浏览器检测实现：**
   - 为 `BookmarkSource` 添加 `isInstalled` 计算属性
   - 修改 `BookmarkSearchSettingsView` 的 `BrowserToggleRow` 渲染逻辑，仅显示已安装浏览器

3. **测试验证：**
   - 验证表情包功能完全移除
   - 测试多浏览器环境下的检测准确性
   - 验证书签读取功能正常

4. **回滚策略：**
   - Git revert 恢复删除的文件
   - 恢复 `AdvancedExtensionsView.swift` 的表情包设置项
   - 恢复 `BookmarkSource` 枚举的原始定义

## Open Questions

无待解决问题。
